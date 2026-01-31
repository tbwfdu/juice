import Foundation

actor LocalCatalogCache {
    struct Manifest: Codable {
        let version: String?
        let updatedAt: String?
        let caskAppsURL: String
        let recipesURL: String

        enum CodingKeys: String, CodingKey {
            case version
            case updatedAt
            case caskAppsURL = "cask_apps_url"
            case recipesURL = "recipes_url"
        }
    }

    struct CacheMetadata: Codable {
        var etag: String?
        var lastModified: String?
        var updatedAt: Date
        var version: String?
    }

    private let manifestURL: URL?
    private let cacheDir: URL
    private let decoder: JSONDecoder

    init(manifestURL: URL?, cacheDir: URL? = nil) {
        self.manifestURL = manifestURL
        if let cacheDir {
            self.cacheDir = cacheDir
        } else {
            self.cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("JuiceCatalog", isDirectory: true)
        }
        self.decoder = JSONDecoder()
    }

    func refreshIfNeeded() async throws {
        guard manifestURL != nil else {
            throw CatalogError.missingManifest
        }
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let manifest = try await fetchManifest()

        try await downloadIfNeeded(remoteURL: resolve(manifest.caskAppsURL), cacheName: "cask_apps.json", version: manifest.version)
        try await downloadIfNeeded(remoteURL: resolve(manifest.recipesURL), cacheName: "recipes.json", version: manifest.version)
    }

    func loadCaskApps() async throws -> [CaskApplication] {
        let data = try loadCachedOrBundled(named: "cask_apps.json")
        return try decoder.decode([CaskApplication].self, from: data)
    }

    func loadRecipes() async throws -> [Recipe] {
        let data = try loadCachedOrBundled(named: "recipes.json")
        return try decoder.decode([Recipe].self, from: data)
    }

    private func fetchManifest() async throws -> Manifest {
        guard let manifestURL else {
            throw CatalogError.missingManifest
        }
        let (data, response) = try await URLSession.shared.data(from: manifestURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CatalogError.invalidResponse
        }
        return try decoder.decode(Manifest.self, from: data)
    }

    private func resolve(_ path: String) -> URL {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }
        guard let manifestURL else {
            return URL(fileURLWithPath: path)
        }
        return manifestURL.deletingLastPathComponent().appendingPathComponent(path)
    }

    private func downloadIfNeeded(remoteURL: URL, cacheName: String, version: String?) async throws {
        let cacheURL = cacheDir.appendingPathComponent(cacheName)
        let metaURL = cacheDir.appendingPathComponent(cacheName + ".meta.json")
        var request = URLRequest(url: remoteURL)
        if let meta = loadMetadata(from: metaURL) {
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

        if http.statusCode == 304 {
            return
        }

        guard (200...299).contains(http.statusCode) else {
            throw CatalogError.invalidResponse
        }

        let tmpURL = cacheURL.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        try? FileManager.default.removeItem(at: cacheURL)
        try FileManager.default.moveItem(at: tmpURL, to: cacheURL)

        let meta = CacheMetadata(
            etag: http.value(forHTTPHeaderField: "ETag"),
            lastModified: http.value(forHTTPHeaderField: "Last-Modified"),
            updatedAt: Date(),
            version: version
        )
        if let encoded = try? JSONEncoder().encode(meta) {
            try? encoded.write(to: metaURL, options: .atomic)
        }
    }

    private func loadCachedOrBundled(named fileName: String) throws -> Data {
        let cacheURL = cacheDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: cacheURL.path),
           let data = try? Data(contentsOf: cacheURL) {
            return data
        }

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

        throw CatalogError.missingLocalData(fileName: fileName, details: debugDetails(for: fileName))
    }

    private func loadMetadata(from url: URL) -> CacheMetadata? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CacheMetadata.self, from: data)
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
    case missingManifest
}

extension CatalogError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case .missingManifest:
            return "The catalog manifest is missing."
        case .missingLocalData(let fileName, let details):
            return "Missing local data: \(fileName)\n\(details)"
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
