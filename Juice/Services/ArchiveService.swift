import Foundation

struct ArchiveService {
    static let supportedExtensions = ["zip", "tar", "gz", "tgz", "bz2", "tbz", "xz", "txz", "7z"]
    static let unsupportedExtensions = ["zst"]

    static func extract(fullFilePath: String, fullOutputFolderPath: String?) async throws -> Bool {
        let fileURL = URL(fileURLWithPath: fullFilePath)
        let fileExtension = fileURL.pathExtension.lowercased()

        if fileExtension == "zip" {
            return try await extractZip(fullZipFilePath: fullFilePath, fullOutputFolderPath: fullOutputFolderPath)
        } else if fileExtension == "7z" {
            if let tool = find7zTool() {
                return try await extract7z(full7zFilePath: fullFilePath, fullOutputFolderPath: fullOutputFolderPath, toolURL: tool)
            }
            return false
        } else {
            return try await extractTar(fullTarFilePath: fullFilePath, fullOutputFolderPath: fullOutputFolderPath)
        }
    }

    static func find7zTool() -> URL? {
        let paths = ["/usr/local/bin/7z", "/opt/homebrew/bin/7z", "/usr/bin/7z"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private static func extract7z(full7zFilePath: String, fullOutputFolderPath: String?, toolURL: URL) async throws -> Bool {
        let process = Process()
        process.executableURL = toolURL
        
        // x: eXtract with full paths, -y: assume Yes on all queries, -o: output directory
        var args = ["x", "-y", full7zFilePath]
        if let output = fullOutputFolderPath {
            args.append("-o\(output)")
        }
        process.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private static func extractZip(fullZipFilePath: String, fullOutputFolderPath: String?) async throws -> Bool {
        let process = Process()
        // ditto is better for macOS zips as it handles resource forks and __MACOSX better
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        var args = ["-x", "-k", fullZipFilePath]
        if let output = fullOutputFolderPath {
            args.append(output)
        } else {
            // If no output folder, ditto extracts to current directory. 
            // Usually we want it in the same folder as the zip.
            let output = URL(fileURLWithPath: fullZipFilePath).deletingLastPathComponent().path
            args.append(output)
        }
        process.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private static func extractTar(fullTarFilePath: String, fullOutputFolderPath: String?) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        // -x: extract, -f: file, -C: directory
        // tar -axf will auto-detect compression based on extension
        var args = ["-axf", fullTarFilePath]
        if let output = fullOutputFolderPath {
            args.append(contentsOf: ["-C", output])
        }
        process.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
