import Foundation

actor LocalCatalogCache {
    struct VersionedItemsFile<T: Decodable>: Decodable {
        let version: String
        let items: [T]
    }

    struct CacheMetadata: Codable {
        var etag: String?
        var lastModified: String?
        var updatedAt: Date
        var version: String?
    }

    private struct DownloadedCatalogFile {
        let cacheName: String
        let data: Data
        let metadata: CacheMetadata
    }

    private struct PendingFileMove {
        let finalURL: URL
        let stagedURL: URL
        let backupURL: URL
        let hadExistingFile: Bool
    }

    private let cacheDir: URL
    private let decoder: JSONDecoder

    init(cacheDir: URL? = nil) {
        if let cacheDir {
            self.cacheDir = cacheDir
        } else {
            self.cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("JuiceCatalog", isDirectory: true)
        }
        self.decoder = JSONDecoder()
    }

    init(manifestURL: URL?, cacheDir: URL? = nil) {
        self.init(cacheDir: cacheDir)
    }

    func refreshFromEndpoints(
        appsURL: URL,
        recipesURL: URL,
        remoteVersion: String?,
        forceRefresh: Bool = false
    ) async throws {
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let downloadedApps: DownloadedCatalogFile?
        do {
            downloadedApps = try await downloadCatalogFile(
                remoteURL: appsURL,
                cacheName: "apps.json",
                version: remoteVersion,
                forceRefresh: forceRefresh
            )
        } catch {
            throw CatalogError.endpointDownloadFailed(
                fileName: "apps.json",
                endpoint: appsURL.absoluteString,
                reason: error.localizedDescription
            )
        }

        let downloadedRecipes: DownloadedCatalogFile?
        do {
            downloadedRecipes = try await downloadCatalogFile(
                remoteURL: recipesURL,
                cacheName: "recipes.json",
                version: remoteVersion,
                forceRefresh: forceRefresh
            )
        } catch {
            throw CatalogError.endpointDownloadFailed(
                fileName: "recipes.json",
                endpoint: recipesURL.absoluteString,
                reason: error.localizedDescription
            )
        }

        try persistDownloadedFiles([downloadedApps, downloadedRecipes].compactMap { $0 })
    }

    func loadCaskApps() async throws -> [CaskApplication] {
        if let cachedData = cachedData(named: "apps.json") {
            let cachedItems = try decodeVersionedItems(
                from: cachedData,
                fileName: "apps.json",
                as: CaskApplication.self
            )
            if !cachedItems.isEmpty {
                return cachedItems
            }
            if let bundledData = bundledData(named: "apps.json") {
                let bundledItems = try decodeVersionedItems(
                    from: bundledData,
                    fileName: "apps.json",
                    as: CaskApplication.self
                )
                if !bundledItems.isEmpty {
                    return bundledItems
                }
            }
            return cachedItems
        }

        let data = try loadCachedOrBundled(named: "apps.json")
        return try decodeVersionedItems(from: data, fileName: "apps.json", as: CaskApplication.self)
    }

    func loadRecipes() async throws -> [Recipe] {
        if let cachedData = cachedData(named: "recipes.json") {
            let cachedItems = try decodeVersionedItems(
                from: cachedData,
                fileName: "recipes.json",
                as: Recipe.self
            )
            if !cachedItems.isEmpty {
                return cachedItems
            }
            if let bundledData = bundledData(named: "recipes.json") {
                let bundledItems = try decodeVersionedItems(
                    from: bundledData,
                    fileName: "recipes.json",
                    as: Recipe.self
                )
                if !bundledItems.isEmpty {
                    return bundledItems
                }
            }
            return cachedItems
        }

        let data = try loadCachedOrBundled(named: "recipes.json")
        return try decodeVersionedItems(from: data, fileName: "recipes.json", as: Recipe.self)
    }

    private func downloadCatalogFile(
        remoteURL: URL,
        cacheName: String,
        version: String?,
        forceRefresh: Bool
    ) async throws -> DownloadedCatalogFile? {
        let metaURL = cacheDir.appendingPathComponent(cacheName + ".meta.json")
        var request = URLRequest(
            url: remoteURL,
            cachePolicy: forceRefresh ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        )
        if forceRefresh {
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        } else if let meta = loadMetadata(from: metaURL) {
            if let etag = meta.etag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            if let lastModified = meta.lastModified {
                request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CatalogError.invalidResponse
        }

        if http.statusCode == 304, !forceRefresh {
            return nil
        }

        guard (200...299).contains(http.statusCode) else {
            throw CatalogError.invalidResponse
        }

        try validateDownloadedData(data, cacheName: cacheName)

        return DownloadedCatalogFile(
            cacheName: cacheName,
            data: data,
            metadata: CacheMetadata(
                etag: http.value(forHTTPHeaderField: "ETag"),
                lastModified: http.value(forHTTPHeaderField: "Last-Modified"),
                updatedAt: Date(),
                version: version
            )
        )
    }

    private func persistDownloadedFiles(_ files: [DownloadedCatalogFile]) throws {
        guard !files.isEmpty else { return }

        let transactionID = UUID().uuidString
        var moves: [PendingFileMove] = []

        for file in files {
            let cacheURL = cacheDir.appendingPathComponent(file.cacheName)
            let metaURL = cacheDir.appendingPathComponent(file.cacheName + ".meta.json")

            let stagedCacheURL = cacheDir.appendingPathComponent(
                "\(file.cacheName).\(transactionID).staged"
            )
            let stagedMetaURL = cacheDir.appendingPathComponent(
                "\(file.cacheName).meta.\(transactionID).staged"
            )

            try file.data.write(to: stagedCacheURL, options: .atomic)
            let encodedMetadata = try JSONEncoder().encode(file.metadata)
            try encodedMetadata.write(to: stagedMetaURL, options: .atomic)

            moves.append(
                PendingFileMove(
                    finalURL: cacheURL,
                    stagedURL: stagedCacheURL,
                    backupURL: cacheDir.appendingPathComponent(
                        "\(file.cacheName).\(transactionID).backup"
                    ),
                    hadExistingFile: FileManager.default.fileExists(atPath: cacheURL.path)
                )
            )
            moves.append(
                PendingFileMove(
                    finalURL: metaURL,
                    stagedURL: stagedMetaURL,
                    backupURL: cacheDir.appendingPathComponent(
                        "\(file.cacheName).meta.\(transactionID).backup"
                    ),
                    hadExistingFile: FileManager.default.fileExists(atPath: metaURL.path)
                )
            )
        }

        var committed: [PendingFileMove] = []
        do {
            for move in moves {
                try apply(move)
                committed.append(move)
            }
            for move in moves {
                try? FileManager.default.removeItem(at: move.backupURL)
            }
        } catch {
            rollback(committed)
            for move in moves {
                try? FileManager.default.removeItem(at: move.stagedURL)
                try? FileManager.default.removeItem(at: move.backupURL)
            }
            throw error
        }
    }

    private func apply(_ move: PendingFileMove) throws {
        if move.hadExistingFile {
            try? FileManager.default.removeItem(at: move.backupURL)
            try FileManager.default.moveItem(at: move.finalURL, to: move.backupURL)
        }

        do {
            try? FileManager.default.removeItem(at: move.finalURL)
            try FileManager.default.moveItem(at: move.stagedURL, to: move.finalURL)
        } catch {
            if move.hadExistingFile,
               FileManager.default.fileExists(atPath: move.backupURL.path) {
                try? FileManager.default.moveItem(at: move.backupURL, to: move.finalURL)
            }
            throw error
        }
    }

    private func rollback(_ committed: [PendingFileMove]) {
        for move in committed.reversed() {
            try? FileManager.default.removeItem(at: move.finalURL)
            if move.hadExistingFile,
               FileManager.default.fileExists(atPath: move.backupURL.path) {
                try? FileManager.default.moveItem(at: move.backupURL, to: move.finalURL)
            }
        }
    }

    func loadCachedOrBundledVersion(for fileName: String) -> String? {
        guard let data = try? loadCachedOrBundled(named: fileName) else {
            return nil
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard root["items"] is [Any], let version = root["version"] as? String else {
            return nil
        }
        return isValidCatalogVersion(version) ? version : nil
    }

    private func loadCachedOrBundled(named fileName: String) throws -> Data {
        if let data = cachedData(named: fileName) {
            return data
        }

        if let data = bundledData(named: fileName) {
            return data
        }

        throw CatalogError.missingLocalData(fileName: fileName, details: debugDetails(for: fileName))
    }

    private func cachedData(named fileName: String) -> Data? {
        let cacheURL = cacheDir.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }
        return try? Data(contentsOf: cacheURL)
    }

    private func bundledData(named fileName: String) -> Data? {
        if let bundled = Bundle.main.url(forResource: fileName, withExtension: nil),
           let data = try? Data(contentsOf: bundled) {
            return data
        }

        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        if let bundled = Bundle.main.url(forResource: name, withExtension: ext),
           let data = try? Data(contentsOf: bundled) {
            return data
        }

        if let bundled = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources"),
           let data = try? Data(contentsOf: bundled) {
            return data
        }

        let bundleJSONs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        if let match = bundleJSONs.first(where: { $0.lastPathComponent == fileName }),
           let data = try? Data(contentsOf: match) {
            return data
        }

        let subdirJSONs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Resources") ?? []
        if let match = subdirJSONs.first(where: { $0.lastPathComponent == fileName }),
           let data = try? Data(contentsOf: match) {
            return data
        }

        if let resourceURL = Bundle.main.resourceURL {
            let directURL = resourceURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: directURL.path),
               let data = try? Data(contentsOf: directURL) {
                return data
            }

            let rootFiles = (try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)) ?? []
            if let match = rootFiles.first(where: { $0.lastPathComponent.caseInsensitiveCompare(fileName) == .orderedSame }),
               let data = try? Data(contentsOf: match) {
                return data
            }

            let resourcesDir = resourceURL.appendingPathComponent("Resources", isDirectory: true)
            let resourcesFiles = (try? FileManager.default.contentsOfDirectory(at: resourcesDir, includingPropertiesForKeys: nil)) ?? []
            if let match = resourcesFiles.first(where: { $0.lastPathComponent.caseInsensitiveCompare(fileName) == .orderedSame }),
               let data = try? Data(contentsOf: match) {
                return data
            }
        }

        let contentsResources = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: contentsResources.path),
           let data = try? Data(contentsOf: contentsResources) {
            return data
        }

        return nil
    }

    private func loadMetadata(from url: URL) -> CacheMetadata? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CacheMetadata.self, from: data)
    }

    private func decodeVersionedItems<T: Decodable>(
        from data: Data,
        fileName: String,
        as type: T.Type
    ) throws -> [T] {
        let wrapper: VersionedItemsFile<T>
        do {
            wrapper = try decoder.decode(VersionedItemsFile<T>.self, from: data)
        } catch {
            throw CatalogError.invalidSchema(
                fileName: fileName,
                expectedShape: #"{"version":"YYYYMMDD","items":[...]}"#
            )
        }

        guard isValidCatalogVersion(wrapper.version) else {
            throw CatalogError.invalidVersion(
                fileName: fileName,
                value: wrapper.version
            )
        }

        return wrapper.items
    }

    private func validateDownloadedData(_ data: Data, cacheName: String) throws {
        let itemCount: Int
        switch cacheName {
        case "apps.json":
            itemCount = try decodeVersionedItems(from: data, fileName: cacheName, as: CaskApplication.self).count
        case "recipes.json":
            itemCount = try decodeVersionedItems(from: data, fileName: cacheName, as: Recipe.self).count
        default:
            itemCount = 1
        }

        if itemCount == 0 {
            throw CatalogError.emptyItemsDownloaded(fileName: cacheName)
        }
    }

    private func isValidCatalogVersion(_ version: String) -> Bool {
        guard version.count == 8, version.allSatisfy(\.isNumber) else {
            return false
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        guard let parsed = formatter.date(from: version) else {
            return false
        }
        return formatter.string(from: parsed) == version
    }

    private func debugDetails(for fileName: String) -> String {
        var lines: [String] = []
        let resourceURL = Bundle.main.resourceURL
        lines.append("resourceURL=\(resourceURL?.path ?? "nil")")
        lines.append("bundleURL=\(Bundle.main.bundleURL.path)")
        if let resourceURL {
            let direct = resourceURL.appendingPathComponent(fileName)
            let resourcesDir = resourceURL.appendingPathComponent("Resources", isDirectory: true).appendingPathComponent(fileName)
            lines.append("candidate=\(direct.path) exists=\(FileManager.default.fileExists(atPath: direct.path))")
            lines.append("candidate=\(resourcesDir.path) exists=\(FileManager.default.fileExists(atPath: resourcesDir.path))")
        }
        let contentsResources = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent(fileName)
        lines.append("candidate=\(contentsResources.path) exists=\(FileManager.default.fileExists(atPath: contentsResources.path))")
        let topLevel = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .map { $0.lastPathComponent }
            .sorted()
        let subdir = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Resources") ?? [])
            .map { $0.lastPathComponent }
            .sorted()
        lines.append("jsonTopLevel=\(topLevel)")
        lines.append("jsonResources=\(subdir)")
        return lines.joined(separator: "\n")
    }
}

enum CatalogError: Error {
    case invalidResponse
    case missingLocalData(fileName: String, details: String)
    case invalidSchema(fileName: String, expectedShape: String)
    case invalidVersion(fileName: String, value: String)
    case endpointDownloadFailed(fileName: String, endpoint: String, reason: String)
    case emptyItemsDownloaded(fileName: String)
}

extension CatalogError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case .endpointDownloadFailed(let fileName, let endpoint, let reason):
            return "Failed to download \(fileName) from \(endpoint): \(reason)"
        case .missingLocalData(let fileName, let details):
            return "Missing local data: \(fileName)\n\(details)"
        case .invalidSchema(let fileName, let expectedShape):
            return "Invalid catalog schema in \(fileName). Expected \(expectedShape)."
        case .invalidVersion(let fileName, let value):
            return "Invalid catalog version in \(fileName): \(value). Expected YYYYMMDD."
        case .emptyItemsDownloaded(let fileName):
            return "Downloaded \(fileName) contains an empty items array. Existing catalog data was kept."
        }
    }

    var debugDetails: String? {
        switch self {
        case .missingLocalData(_, let details):
            return details
        default:
            return nil
        }
    }
}
