import Foundation
import os

func appLog(
	_ level: AppLogLevel = .info,
	_ category: String,
	_ message: @autoclosure () -> String,
	event: String? = nil,
	metadata: [String: String] = [:]
) {
	let rawMessage = message()
	let sanitizedMessage = AppLogRedactor.sanitize(rawMessage)
	let sanitizedMetadata = metadata.reduce(into: [String: String]()) { result, pair in
		result[pair.key] = AppLogRedactor.sanitize(pair.value)
	}

	Task { @MainActor in
		AppLogStore.shared.append(
			level: level,
			category: category,
			message: sanitizedMessage,
			event: event,
			metadata: sanitizedMetadata
		)
	}

	let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "Juice",
		category: category
	)
	let metadataSuffix: String
	if sanitizedMetadata.isEmpty {
		metadataSuffix = ""
	} else {
		let fragments = sanitizedMetadata
			.sorted(by: { $0.key < $1.key })
			.map { "\($0.key)=\($0.value)" }
		metadataSuffix = " | " + fragments.joined(separator: " ")
	}
	let eventPrefix = event.flatMap { $0.isEmpty ? nil : $0 }.map { "[\($0)] " } ?? ""
	let rendered = "\(eventPrefix)\(sanitizedMessage)\(metadataSuffix)"
	switch level {
	case .debug:
		logger.debug("\(rendered, privacy: .public)")
	case .info:
		logger.info("\(rendered, privacy: .public)")
	case .warning:
		logger.warning("\(rendered, privacy: .public)")
	case .error:
		logger.error("\(rendered, privacy: .public)")
	}

	#if DEBUG
	print("[\(category)][\(level.rawValue.uppercased())] \(rendered)")
	#endif
}

enum LogCategory {
	static let app = "Juice"
	static let auth = "AuthService"
	static let uem = "UEMService"
	static let upload = "DownloadUploadService"
	static let queue = "DownloadQueue"
	static let settings = "SettingsView"
	static let environmentList = "EnvironmentListDisplay"
	static let helpers = "Helpers"
}
