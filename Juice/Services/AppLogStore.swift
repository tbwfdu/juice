import Foundation
import Combine

@MainActor
final class AppLogStore: ObservableObject {
	static let shared = AppLogStore()

	@Published private(set) var entries: [AppLogEntry] = []
	@Published var verbosity: AppLogVerbosity {
		didSet {
			UserDefaults.standard.set(verbosity.rawValue, forKey: Keys.verbosity)
		}
	}

	private let maxEntries = 2000
	private let maxFileSizeBytes = 5 * 1024 * 1024
	private let maxLogFiles = 3
	private let persistedLogFilename = "juice-app.log"
	private let fileManager = FileManager.default

	private enum Keys {
		static let verbosity = "juice.logging.verbosity"
	}

	private init() {
		let persistedVerbosity =
			UserDefaults.standard.string(forKey: Keys.verbosity)
				.flatMap(AppLogVerbosity.init(rawValue:))
			?? .normal
		self.verbosity = persistedVerbosity
		loadPersistedEntries()
	}

	func append(
		level: AppLogLevel,
		category: String,
		message: String,
		event: String? = nil,
		metadata: [String: String] = [:],
		timestamp: Date = Date()
	) {
		guard shouldCapture(level: level) else { return }
		let sanitizedCategory = AppLogRedactor.sanitize(category)
		let sanitizedMessage = AppLogRedactor.sanitize(message)
		let sanitizedMetadata = metadata.reduce(into: [String: String]()) { acc, item in
			acc[item.key] = AppLogRedactor.sanitize(item.value)
		}
		let entry = AppLogEntry(
			timestamp: timestamp,
			level: level,
			category: sanitizedCategory,
			message: sanitizedMessage,
			event: event,
			metadata: sanitizedMetadata
		)
		appendEntry(entry)
		persist(entry)
	}

	func clear() {
		entries.removeAll(keepingCapacity: true)
		removePersistedLogs()
	}

	func exportLogsSnapshot() throws -> URL {
		let dateStamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
		let fileURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("JuiceLogs-\(dateStamp).log", isDirectory: false)
		let lines = entries.map(\.renderedLine)
		let text = lines.joined(separator: "\n")
		try text.write(to: fileURL, atomically: true, encoding: .utf8)
		return fileURL
	}

	private func shouldCapture(level: AppLogLevel) -> Bool {
		level.severity >= verbosity.minimumLevel.severity
	}

	private func appendEntry(_ entry: AppLogEntry) {
		entries.append(entry)
		if entries.count > maxEntries {
			entries.removeFirst(entries.count - maxEntries)
		}
	}

	private func persist(_ entry: AppLogEntry) {
		guard let directoryURL = logsDirectoryURL() else { return }
		do {
			try fileManager.createDirectory(
				at: directoryURL,
				withIntermediateDirectories: true
			)
			let fileURL = directoryURL.appendingPathComponent(persistedLogFilename, isDirectory: false)
			try rotateFilesIfNeeded(for: fileURL)
			let persisted = PersistedLogEntry(entry: entry)
			let data = try JSONEncoder().encode(persisted)
			if fileManager.fileExists(atPath: fileURL.path) {
				let handle = try FileHandle(forWritingTo: fileURL)
				try handle.seekToEnd()
				try handle.write(contentsOf: data)
				try handle.write(contentsOf: Data([0x0A]))
				try handle.close()
			} else {
				var payload = Data()
				payload.append(data)
				payload.append(0x0A)
				try payload.write(to: fileURL, options: .atomic)
			}
		} catch {
			// Swallow persistence errors; do not interrupt runtime logging.
		}
	}

	private func loadPersistedEntries() {
		guard let directoryURL = logsDirectoryURL(),
			let files = try? fileManager.contentsOfDirectory(
				at: directoryURL,
				includingPropertiesForKeys: [.contentModificationDateKey],
				options: [.skipsHiddenFiles]
			)
		else { return }
		let sorted = files
			.filter { $0.lastPathComponent.hasPrefix("juice-app") }
			.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
		var loaded: [AppLogEntry] = []
		for fileURL in sorted {
			guard let data = try? Data(contentsOf: fileURL),
				let content = String(data: data, encoding: .utf8)
			else { continue }
			for line in content.split(separator: "\n") {
				guard let lineData = line.data(using: .utf8),
					let record = try? JSONDecoder().decode(PersistedLogEntry.self, from: lineData)
				else { continue }
				loaded.append(record.makeEntry())
			}
		}
		for entry in loaded.suffix(maxEntries) {
			appendEntry(entry)
		}
	}

	private func removePersistedLogs() {
		guard let directoryURL = logsDirectoryURL(),
			let files = try? fileManager.contentsOfDirectory(
				at: directoryURL,
				includingPropertiesForKeys: nil
			)
		else { return }
		for file in files where file.lastPathComponent.hasPrefix("juice-app") {
			try? fileManager.removeItem(at: file)
		}
	}

	private func rotateFilesIfNeeded(for currentFileURL: URL) throws {
		guard fileManager.fileExists(atPath: currentFileURL.path) else { return }
		let attrs = try fileManager.attributesOfItem(atPath: currentFileURL.path)
		let currentFileSize = attrs[.size] as? NSNumber
		guard (currentFileSize?.intValue ?? 0) >= maxFileSizeBytes else { return }

		// Shift older rotations up: juice-app.log.1 -> .2 -> .3
		for index in stride(from: maxLogFiles - 1, through: 1, by: -1) {
			let source = currentFileURL.deletingPathExtension()
				.appendingPathExtension("log.\(index)")
			let destination = currentFileURL.deletingPathExtension()
				.appendingPathExtension("log.\(index + 1)")
			if fileManager.fileExists(atPath: destination.path) {
				try? fileManager.removeItem(at: destination)
			}
			if fileManager.fileExists(atPath: source.path) {
				try? fileManager.moveItem(at: source, to: destination)
			}
		}

		let firstRotation = currentFileURL.deletingPathExtension()
			.appendingPathExtension("log.1")
		if fileManager.fileExists(atPath: firstRotation.path) {
			try? fileManager.removeItem(at: firstRotation)
		}
		try? fileManager.moveItem(at: currentFileURL, to: firstRotation)
	}

	private func logsDirectoryURL() -> URL? {
		fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
			.appendingPathComponent("Juice", isDirectory: true)
			.appendingPathComponent("Logs", isDirectory: true)
	}
}

struct AppLogEntry: Identifiable, Hashable {
	let id = UUID()
	let timestamp: Date
	let level: AppLogLevel
	let category: String
	let message: String
	let event: String?
	let metadata: [String: String]

	var renderedLine: String {
		let formatter = ISO8601DateFormatter()
		let eventText = event.flatMap { $0.isEmpty ? nil : $0 } ?? "-"
		let metadataText: String
		if metadata.isEmpty {
			metadataText = "-"
		} else {
			metadataText = metadata
				.sorted { $0.key < $1.key }
				.map { "\($0.key)=\($0.value)" }
				.joined(separator: " ")
		}
		return "\(formatter.string(from: timestamp)) [\(level.rawValue.uppercased())] [\(category)] [event=\(eventText)] \(message) | \(metadataText)"
	}
}

enum AppLogLevel: String, CaseIterable, Hashable {
	case debug
	case info
	case warning
	case error

	var severity: Int {
		switch self {
		case .debug: return 0
		case .info: return 1
		case .warning: return 2
		case .error: return 3
		}
	}
}

enum AppLogVerbosity: String, CaseIterable, Identifiable {
	case normal
	case verbose
	case diagnostic

	var id: String { rawValue }

	var title: String {
		switch self {
		case .normal: return "Normal"
		case .verbose: return "Verbose"
		case .diagnostic: return "Diagnostic"
		}
	}

	var minimumLevel: AppLogLevel {
		switch self {
		case .normal: return .info
		case .verbose, .diagnostic: return .debug
		}
	}
}

private struct PersistedLogEntry: Codable {
	let timestamp: Date
	let level: String
	let category: String
	let message: String
	let event: String?
	let metadata: [String: String]

	init(entry: AppLogEntry) {
		self.timestamp = entry.timestamp
		self.level = entry.level.rawValue
		self.category = entry.category
		self.message = entry.message
		self.event = entry.event
		self.metadata = entry.metadata
	}

	func makeEntry() -> AppLogEntry {
		AppLogEntry(
			timestamp: timestamp,
			level: AppLogLevel(rawValue: level) ?? .info,
			category: category,
			message: message,
			event: event,
			metadata: metadata
		)
	}
}
