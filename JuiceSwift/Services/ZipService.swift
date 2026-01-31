import Foundation

struct ZipService {
    static func extract(fullZipFilePath: String, fullOutputFolderPath: String?) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        var args = ["-o", fullZipFilePath]
        if let output = fullOutputFolderPath {
            args.append(contentsOf: ["-d", output])
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
