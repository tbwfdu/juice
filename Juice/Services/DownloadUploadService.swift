import Foundation
import os
#if os(macOS)
import AppKit
#endif

struct DownloadUploadService {
	struct UploadProgressUpdate: Sendable {
		enum Phase: Sendable {
			case metadata
			case icons
			case installer
		}

		let phase: Phase
		let percent: Int?
		let bytesSent: Int64?
		let totalBytes: Int64?
	}

	static let logPrefix = "DownloadUploadService"
	static let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "Juice",
		category: "DownloadUpload"
	)
	private static let inactivityTimeout: TimeInterval = 5 * 60

	private final class BlobUploadDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
		private let inactivityTimeout: TimeInterval
		private let onProgress: @Sendable (Int64, Int64) -> Void
		private var inactivityTimer: DispatchSourceTimer?
		private var lastProgressDate = Date()
		private var didComplete = false
		private var lastPercent: Int = -1

		var receivedData = Data()
		var response: URLResponse?
		var continuation: CheckedContinuation<(Data, URLResponse), Error>?

		init(
			inactivityTimeout: TimeInterval,
			onProgress: @escaping @Sendable (Int64, Int64) -> Void
		) {
			self.inactivityTimeout = inactivityTimeout
			self.onProgress = onProgress
		}

		func startWatchdog(for task: URLSessionTask) {
			let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
			timer.schedule(deadline: .now() + inactivityTimeout, repeating: inactivityTimeout / 2)
			timer.setEventHandler { [weak self, weak task] in
				guard let self, let task else { return }
				let elapsed = Date().timeIntervalSince(self.lastProgressDate)
				if elapsed >= self.inactivityTimeout, !self.didComplete {
					DownloadUploadService.logger.warning(
						"[Upload] Inactivity timeout reached (no upload progress for \(self.inactivityTimeout, privacy: .public)s). Cancelling request."
					)
					task.cancel()
				}
			}
			inactivityTimer = timer
			timer.resume()
		}

		private func stopWatchdog() {
			inactivityTimer?.cancel()
			inactivityTimer = nil
		}

		func urlSession(
			_ session: URLSession,
			task: URLSessionTask,
			didSendBodyData bytesSent: Int64,
			totalBytesSent: Int64,
			totalBytesExpectedToSend: Int64
		) {
			lastProgressDate = Date()
			guard totalBytesExpectedToSend > 0 else { return }
			let percent = Int(
				(Double(totalBytesSent) / Double(totalBytesExpectedToSend)) * 100.0
			)
			guard percent != lastPercent else { return }
			lastPercent = percent
			onProgress(totalBytesSent, totalBytesExpectedToSend)
		}

		func urlSession(
			_ session: URLSession,
			dataTask: URLSessionDataTask,
			didReceive data: Data
		) {
			receivedData.append(data)
		}

		func urlSession(
			_ session: URLSession,
			dataTask: URLSessionDataTask,
			didReceive response: URLResponse,
			completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
		) {
			self.response = response
			completionHandler(.allow)
		}

		func urlSession(
			_ session: URLSession,
			task: URLSessionTask,
			didCompleteWithError error: Error?
		) {
			stopWatchdog()
			didComplete = true
			if let error {
				if let response {
					continuation?.resume(returning: (receivedData, response))
				} else {
					continuation?.resume(throwing: error)
				}
				continuation = nil
				return
			}
			guard let response else {
				continuation?.resume(throwing: URLError(.badServerResponse))
				continuation = nil
				return
			}
			continuation?.resume(returning: (receivedData, response))
			continuation = nil
		}
	}

	struct DownloadOutput {
		let successfulDownload: SuccessfulDownload
		let installerFileURL: URL
	}

	static func downloadAndPrepare(
		_ app: CaskApplication,
		mode: ConfirmationActionMode,
		shouldCancel: @MainActor @Sendable @escaping () -> Bool
	) async throws -> DownloadOutput {
		try await updateDownloadProgress(app) { progress in
			progress.inProgress = true
			progress.isIndeterminate = true
			progress.currentState = "Starting..."
		}

		if await MainActor.run(body: shouldCancel) { throw CancellationError() }

		let (destinationURL, _, fileExtension) = try resolveDownloadDestination(for: app)
		let fileExists = FileManager.default.fileExists(atPath: destinationURL.path)

		if !fileExists {
			try await downloadFile(
				from: URL(string: app.url),
				to: destinationURL,
				app: app,
				shouldCancel: shouldCancel
			)
		} else {
			try await markExistingDownload(app: app, fileURL: destinationURL)
		}

		if await MainActor.run(body: shouldCancel) { throw CancellationError() }

		let (installerURL, finalExtension) = try await resolveInstallerIfArchive(
			app: app,
			fileURL: destinationURL,
			fileExtension: fileExtension
		)

		return try await prepareInstallerForMetadata(
			app: app,
			installerURL: installerURL,
			appFolderURL: destinationURL.deletingLastPathComponent(),
			finalExtension: finalExtension,
			mode: mode,
			shouldCancel: shouldCancel,
			allowUnsupportedFallback: true
		)
	}

	static func prepareImportedForUpload(
		_ imported: ImportedApplication,
		shouldCancel: @MainActor @Sendable @escaping () -> Bool,
		mode: ConfirmationActionMode = .upload
	) async throws -> DownloadOutput {
		let app = importQueueApplication(from: imported)
		try await updateDownloadProgress(app) { progress in
			progress.inProgress = true
			progress.isIndeterminate = true
			progress.currentState = "Generating metadata (munkiimport)..."
		}

		if await MainActor.run(body: shouldCancel) { throw CancellationError() }

		let installerURL = URL(fileURLWithPath: imported.fullFilePath)
		guard FileManager.default.fileExists(atPath: installerURL.path) else {
			throw NSError(
				domain: logPrefix,
				code: 101,
				userInfo: [NSLocalizedDescriptionKey: "Imported installer was not found on disk."]
			)
		}

		let rawExtension = installerURL.pathExtension.isEmpty
			? imported.fileExtension
			: installerURL.pathExtension
		let sourceExtension = normalizedExtension(rawExtension)
		guard !sourceExtension.isEmpty else {
			throw NSError(
				domain: logPrefix,
				code: 102,
				userInfo: [NSLocalizedDescriptionKey: "Unsupported installer type for metadata generation (missing file extension)."]
			)
		}

		let (resolvedInstallerURL, finalExtension) = try await resolveInstallerIfArchive(
			app: app,
			fileURL: installerURL,
			fileExtension: sourceExtension
		)

		return try await prepareInstallerForMetadata(
			app: app,
			installerURL: resolvedInstallerURL,
			appFolderURL: installerURL.deletingLastPathComponent(),
			finalExtension: finalExtension,
			mode: mode,
			shouldCancel: shouldCancel,
			allowUnsupportedFallback: false
		)
	}

	static func uploadSuccessfulDownload(
		_ download: SuccessfulDownload,
		shouldCancel: @MainActor @Sendable @escaping () -> Bool,
		onStatus: @MainActor @Sendable @escaping (String) -> Void = { _ in },
		onProgress: @MainActor @Sendable @escaping (UploadProgressUpdate) -> Void = { _ in }
	) async throws -> Bool {
		let appLabel = download.macApplication?.displayName ?? download.fileName
		appLog(
			.info,
			LogCategory.upload,
			"Starting upload for prepared download",
			event: "upload.stage.start",
			metadata: ["app_name": appLabel]
		)
		if await MainActor.run(body: shouldCancel) { throw CancellationError() }
		let metadata = download.munkiMetadata
		guard
			let plistPath = metadata?.installerPlist,
			let installerPath = metadata?.installerFile,
			let iconPath = metadata?.iconFile,
			let version = download.parsedMetadata?.version
		else {
			appLog(
				.error,
				LogCategory.upload,
				"Missing upload prerequisites",
				event: "upload.prerequisites_missing",
				metadata: ["app_name": appLabel]
			)
			logger.error("[Upload] Missing upload prerequisites. plistPath=\(metadata?.installerPlist ?? "nil", privacy: .public) installerPath=\(metadata?.installerFile ?? "nil", privacy: .public) iconPath=\(metadata?.iconFile ?? "nil", privacy: .public) version=\(download.parsedMetadata?.version ?? "nil", privacy: .public)")
			return false
		}

			await onStatus("Uploading metadata...")
			appLog(.info, LogCategory.upload, "Uploading metadata", event: "upload.metadata.start", metadata: ["app_name": appLabel])
			await onProgress(
				UploadProgressUpdate(
					phase: .metadata,
					percent: nil,
					bytesSent: nil,
					totalBytes: nil
				)
			)
			let pkgInfoBlobId = try await createFileBlob(
				fileURL: URL(fileURLWithPath: plistPath)
			)
			if await MainActor.run(body: shouldCancel) { throw CancellationError() }
			await onStatus("Uploading icons...")
			appLog(.info, LogCategory.upload, "Uploading icons", event: "upload.icons.start", metadata: ["app_name": appLabel])
			await onProgress(
				UploadProgressUpdate(
					phase: .icons,
					percent: nil,
					bytesSent: nil,
					totalBytes: nil
				)
			)
			let iconBlobId = try await createFileBlob(
				fileURL: URL(fileURLWithPath: iconPath)
			)
			if await MainActor.run(body: shouldCancel) { throw CancellationError() }
			await onStatus("Uploading installer...")
			appLog(.info, LogCategory.upload, "Uploading installer", event: "upload.installer.start", metadata: ["app_name": appLabel])
			await onProgress(
				UploadProgressUpdate(
					phase: .installer,
					percent: 0,
					bytesSent: 0,
					totalBytes: nil
				)
			)
			let appBlobId = try await createFileBlob(
				fileURL: URL(fileURLWithPath: installerPath),
				onProgress: { bytesSent, totalBytes in
					let rawPercent = Int(
						(Double(bytesSent) / Double(max(totalBytes, 1))) * 100.0
					)
					let percent = min(max(rawPercent, 0), 100)
					Task { @MainActor in
						onProgress(
							UploadProgressUpdate(
								phase: .installer,
								percent: percent,
								bytesSent: bytesSent,
								totalBytes: totalBytes
							)
						)
					}
				}
			)

		guard
			!pkgInfoBlobId.isEmpty,
			!iconBlobId.isEmpty,
			!appBlobId.isEmpty
		else {
			appLog(
				.error,
				LogCategory.upload,
				"Blob upload failed",
				event: "upload.blob.failed",
				metadata: ["app_name": appLabel]
			)
			logger.error("[Upload] Blob upload failed. pkgInfoBlobId=\(pkgInfoBlobId.isEmpty ? "empty" : "ok", privacy: .public) iconBlobId=\(iconBlobId.isEmpty ? "empty" : "ok", privacy: .public) appBlobId=\(appBlobId.isEmpty ? "empty" : "ok", privacy: .public)")
			return false
		}

		appLog(
			.info,
			LogCategory.upload,
			"Submitting final create application request",
			event: "upload.create_application.start",
			metadata: ["app_name": appLabel]
		)
		return try await createMacOsApplication(
			pkgInfoBlobId: pkgInfoBlobId,
			applicationBlobId: appBlobId,
			applicationIconBlobId: iconBlobId,
			version: version
		)
	}

	static func resolveDownloadDestination(
		for app: CaskApplication
	) throws -> (URL, String, String) {
		let fileName = fileNameFromURL(app.url)
		let fileExtension = (fileName as NSString).pathExtension
		guard !fileExtension.isEmpty else {
			throw NSError(domain: logPrefix, code: 1, userInfo: [
				NSLocalizedDescriptionKey: "Unable to determine file extension"
			])
		}

		let folderName = app.fullToken.isEmpty ? app.token : app.fullToken
		let version = app.version.replacingOccurrences(of: ",", with: "")
		let home = FileManager.default.homeDirectoryForCurrentUser
		let appFolder = home
			.appendingPathComponent("Juice", isDirectory: true)
			.appendingPathComponent(folderName, isDirectory: true)
			.appendingPathComponent(version, isDirectory: true)
		try FileManager.default.createDirectory(
			at: appFolder,
			withIntermediateDirectories: true
		)
		return (appFolder.appendingPathComponent(fileName), fileName, fileExtension)
	}

	static func fileNameFromURL(_ urlString: String) -> String {
		guard let url = URL(string: urlString) else { return "download" }
		if let last = url.path.split(separator: "/").last, !last.isEmpty {
			return String(last)
		}
		return "download"
	}

	private static func downloadFile(
		from url: URL?,
		to destination: URL,
		app: CaskApplication,
		shouldCancel: @MainActor @Sendable @escaping () -> Bool
	) async throws {
		guard let url else {
			throw NSError(domain: logPrefix, code: 2, userInfo: [
				NSLocalizedDescriptionKey: "Invalid download URL"
			])
		}

		try await updateDownloadProgress(app) { progress in
			progress.currentState = "Downloading..."
			progress.isIndeterminate = true
		}

		let request = URLRequest(url: url)
		let (tempURL, response) = try await downloadFileWithProgress(
			request: request,
			app: app,
			shouldCancel: shouldCancel
		)
		if await MainActor.run(body: shouldCancel) { throw CancellationError() }

		let expectedLength = response.expectedContentLength
		if expectedLength > 0 {
			try await updateDownloadProgress(app) { progress in
				progress.fileSize = expectedLength
				progress.fileSizeStr = formatBytes(expectedLength)
			}
		}

		if FileManager.default.fileExists(atPath: destination.path) {
			try FileManager.default.removeItem(at: destination)
		}
		try FileManager.default.moveItem(at: tempURL, to: destination)
		try await updateDownloadProgress(app) { progress in
			progress.downloadPercent = 100
			progress.downloadPercentString = "100% Downloaded"
			progress.isIndeterminate = false
			progress.currentState = "Download complete"
		}
	}

	private final class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
		private let lock = NSLock()
		private let app: CaskApplication
		private let shouldCancel: @MainActor @Sendable () -> Bool
		private var didComplete = false
		private var lastPercent: Int = -1
		var onCompletion: ((Result<(URL, URLResponse), Error>) -> Void)?

		init(
			app: CaskApplication,
			shouldCancel: @MainActor @Sendable @escaping () -> Bool
		) {
			self.app = app
			self.shouldCancel = shouldCancel
		}

		func urlSession(
			_ session: URLSession,
			downloadTask: URLSessionDownloadTask,
			didWriteData bytesWritten: Int64,
			totalBytesWritten: Int64,
			totalBytesExpectedToWrite: Int64
		) {
			let expected = totalBytesExpectedToWrite
			let hasExpected = expected > 0
			let percent = hasExpected
				? Int((Double(totalBytesWritten) / Double(expected)) * 100.0)
				: 0
			var shouldReturnEarly = false
			lock.lock()
			if hasExpected && percent == lastPercent {
				shouldReturnEarly = true
			} else {
				lastPercent = percent
			}
			lock.unlock()
			if shouldReturnEarly { return }

			let downloadedStr = DownloadUploadService.formatBytes(totalBytesWritten)
			let expectedStr = hasExpected ? DownloadUploadService.formatBytes(expected) : nil

			Task { @MainActor in
				do {
					try DownloadUploadService.updateDownloadProgress(app) { progress in
						progress.isIndeterminate = !hasExpected
						if hasExpected {
							progress.fileSize = expected
							progress.fileSizeStr = DownloadUploadService.formatBytes(expected)
							progress.downloadPercent = min(max(percent, 0), 100)
							progress.downloadPercentString = "\(progress.downloadPercent ?? 0)% Downloaded"
							progress.currentState = "Downloading \(downloadedStr) of \(expectedStr ?? "")"
								.trimmingCharacters(in: .whitespaces)
						} else {
							progress.downloadPercentString = "\(downloadedStr) Downloaded"
							progress.currentState = "Downloading \(downloadedStr)"
						}
					}
				} catch {
					DownloadUploadService.logger.error(
						"Failed to update download progress: \(String(describing: error))"
					)
				}
			}

			Task { @MainActor in
				if shouldCancel() {
					downloadTask.cancel()
				}
			}
		}

		func urlSession(
			_ session: URLSession,
			downloadTask: URLSessionDownloadTask,
			didFinishDownloadingTo location: URL
		) {
			lock.lock()
			if didComplete {
				lock.unlock()
				return
			}
			didComplete = true
			let response = downloadTask.response ?? URLResponse()
			let completion = onCompletion
			lock.unlock()
			completion?(.success((location, response)))
		}

		func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
			lock.lock()
			let alreadyCompleted = didComplete
			if let error {
				if !alreadyCompleted {
					didComplete = true
					let completion = onCompletion
					lock.unlock()
					completion?(.failure(error))
					return
				}
			}
			lock.unlock()
		}
	}

	private static func downloadFileWithProgress(
		request: URLRequest,
		app: CaskApplication,
		shouldCancel: @MainActor @Sendable @escaping () -> Bool
	) async throws -> (URL, URLResponse) {
		let delegate = DownloadTaskDelegate(app: app, shouldCancel: shouldCancel)
		let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
		defer { session.invalidateAndCancel() }

		return try await withCheckedThrowingContinuation { continuation in
			delegate.onCompletion = { result in
				switch result {
				case .success(let (location, response)):
					do {
						let safeURL = FileManager.default.temporaryDirectory
							.appendingPathComponent(UUID().uuidString)
						if FileManager.default.fileExists(atPath: safeURL.path) {
							try FileManager.default.removeItem(at: safeURL)
						}
						try FileManager.default.moveItem(at: location, to: safeURL)
						continuation.resume(returning: (safeURL, response))
					} catch {
						continuation.resume(throwing: error)
					}
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
			let task = session.downloadTask(with: request)
			task.resume()
		}
	}

	private static func markExistingDownload(
		app: CaskApplication,
		fileURL: URL
	) async throws {
		logger.info("[\(logPrefix)] Installer already exists at \(fileURL.path, privacy: .public)")
		let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
		try await updateDownloadProgress(app) { progress in
			progress.fileSize = size
			progress.fileSizeStr = formatBytes(size)
			progress.downloadExists = true
			progress.isIndeterminate = true
			progress.currentState = "Installer previously downloaded"
			progress.downloadPercent = 100
			progress.downloadPercentString = "Downloaded"
		}
	}

	private static func resolveInstallerIfArchive(
		app: CaskApplication,
		fileURL: URL,
		fileExtension: String
	) async throws -> (URL, String) {
		let archiveExtensions = ArchiveService.supportedExtensions
		let unsupportedExtensions = ArchiveService.unsupportedExtensions
		let ext = fileExtension.lowercased()

		if ext == "7z" {
			if ArchiveService.find7zTool() == nil {
				logger.warning("[\(logPrefix)] p7zip tool (7z) not found for .7z extraction. Advising Homebrew install.")
				appLog(.warning, LogCategory.upload, "p7zip (7z) is required to extract .7z files. Install it using: brew install p7zip")
				try await updateDownloadProgress(app) { progress in
					progress.currentState = "Archive type is not supported"
					progress.isIndeterminate = false
					progress.downloadPercent = 100
				}
				return (fileURL, fileExtension)
			}
		}

		if unsupportedExtensions.contains(ext) {
			logger.warning("[\(logPrefix)] Unsupported archive type: \(ext). Manual extraction required.")
			appLog(.warning, LogCategory.upload, "Unsupported archive type: \(ext) for \(app.name[0]). Manual extraction required.")
			try await updateDownloadProgress(app) { progress in
				progress.currentState = "Archive type is not supported"
				progress.isIndeterminate = false
				progress.downloadPercent = 100
			}
			return (fileURL, fileExtension)
		}

		guard archiveExtensions.contains(ext) else {
			return (fileURL, fileExtension)
		}

		let outputFolder = fileURL.deletingLastPathComponent()
		let extractOK = try await ArchiveService.extract(
			fullFilePath: fileURL.path,
			fullOutputFolderPath: outputFolder.path
		)
		if !extractOK {
			logger.warning("[\(logPrefix)] Extraction failed for \(fileURL.path). Continuing with original file.")
			appLog(.warning, LogCategory.upload, "Extraction failed for \(app.name[0]). Continuing with original file.")
			return (fileURL, fileExtension)
		}

		let enumerator = FileManager.default.enumerator(
			at: outputFolder,
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		)
		let allowedExtensions = ["app", "dmg", "pkg"]
		while let url = enumerator?.nextObject() as? URL {
			if allowedExtensions.contains(url.pathExtension.lowercased()) {
				return (url, url.pathExtension.lowercased())
			}
		}

		logger.warning("[\(logPrefix)] No compatible installer files found in archive for \(app.name[0]).")
		appLog(.warning, LogCategory.upload, "No compatible installer files (.app, .dmg, .pkg) found in archive for \(app.name[0]).")
		return (fileURL, fileExtension)
	}

	private static func prepareInstallerForMetadata(
		app: CaskApplication,
		installerURL: URL,
		appFolderURL: URL,
		finalExtension: String,
		mode: ConfirmationActionMode,
		shouldCancel: @MainActor @Sendable @escaping () -> Bool,
		allowUnsupportedFallback: Bool
	) async throws -> DownloadOutput {
		let normalizedFinalExtension = normalizedExtension(finalExtension)

		if ArchiveService.unsupportedExtensions.contains(normalizedFinalExtension) {
			logger.info("[\(logPrefix)] Skipping metadata generation for unsupported archive type: \(normalizedFinalExtension)")
			appLog(
				.warning,
				LogCategory.upload,
				"Unsupported installer type for metadata generation: .\(normalizedFinalExtension)"
			)
			try await updateDownloadProgress(app) { progress in
				progress.isIndeterminate = false
				progress.isComplete = true
				progress.isSuccess = false
				progress.inProgress = false
				progress.currentState = "Archive type is not supported"
			}
			if allowUnsupportedFallback {
				var minimal = try minimalSuccessfulDownload(app: app)
				minimal.fullFilePath = installerURL.path
				if !installerURL.pathExtension.isEmpty {
					minimal.fileExtension = installerURL.pathExtension
				}
				return DownloadOutput(
					successfulDownload: minimal,
					installerFileURL: installerURL
				)
			}
			throw NSError(
				domain: logPrefix,
				code: 103,
				userInfo: [NSLocalizedDescriptionKey: "Unsupported installer type for metadata generation: .\(normalizedFinalExtension)"]
			)
		}

		let supportedInstallerExtensions = Set(["app", "dmg", "pkg"])
		if !supportedInstallerExtensions.contains(normalizedFinalExtension) {
			logger.info("[\(logPrefix)] Unsupported installer type for metadata generation: \(normalizedFinalExtension)")
			appLog(
				.warning,
				LogCategory.upload,
				"Unsupported installer type for metadata generation: .\(normalizedFinalExtension)"
			)
			try await updateDownloadProgress(app) { progress in
				progress.isIndeterminate = false
				progress.isComplete = true
				progress.isSuccess = false
				progress.inProgress = false
				progress.currentState = "Metadata cannot be processed"
			}
			if allowUnsupportedFallback {
				var minimal = try minimalSuccessfulDownload(app: app)
				minimal.fullFilePath = installerURL.path
				if !installerURL.pathExtension.isEmpty {
					minimal.fileExtension = installerURL.pathExtension
				}
				return DownloadOutput(
					successfulDownload: minimal,
					installerFileURL: installerURL
				)
			}
			throw NSError(
				domain: logPrefix,
				code: 104,
				userInfo: [NSLocalizedDescriptionKey: "Unsupported installer type for metadata generation: .\(normalizedFinalExtension)"]
			)
		}

		if await MainActor.run(body: shouldCancel) { throw CancellationError() }

		try await updateDownloadProgress(app) { progress in
			progress.currentState = "Generating metadata (munkiimport)..."
			progress.isIndeterminate = true
		}

		do {
			let metadata = try await generateMunkiMetadata(
				installerPath: installerURL.path,
				appDownloadPath: appFolderURL.path,
				mode: mode
			)

			try writeMetadataJson(app: app, folderURL: appFolderURL)

			let successfulDownload = try buildSuccessfulDownload(
				app: app,
				installerURL: installerURL,
				appFolderURL: appFolderURL,
				metadata: metadata
			)

			try await updateDownloadProgress(app) { progress in
				progress.isIndeterminate = false
				progress.isComplete = true
				progress.isSuccess = true
				progress.inProgress = false
				progress.fullFilePath = installerURL.path
				progress.currentState = "Download complete"
			}

			return DownloadOutput(
				successfulDownload: successfulDownload,
				installerFileURL: installerURL
			)
		} catch {
			try await updateDownloadProgress(app) { progress in
				progress.isIndeterminate = false
				progress.isComplete = true
				progress.isSuccess = false
				progress.inProgress = false
				progress.currentState = "Failed: \(error.localizedDescription)"
			}
			throw error
		}
	}

	private static func normalizedExtension(_ value: String) -> String {
		value
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased()
			.trimmingCharacters(in: CharacterSet(charactersIn: "."))
	}

	private static func importQueueApplication(from imported: ImportedApplication) -> CaskApplication {
		let existing = imported.macApplication
		let resolvedName = existing?.name.first?.trimmingCharacters(in: .whitespacesAndNewlines)
		let fallbackName = imported.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
		let resolvedVersion = imported.parsedMetadata?.version
			?? existing?.version
			?? ""
		let app = CaskApplication(
			token: imported.id.uuidString,
			fullToken: imported.id.uuidString,
			name: [resolvedName?.isEmpty == false ? resolvedName! : fallbackName],
			desc: existing?.desc ?? imported.queueSubtitle,
			url: imported.fullFilePath,
			version: resolvedVersion,
			matchingRecipeId: imported.matchingRecipeId,
			matchingRecipeCandidates: imported.matchingRecipeCandidates,
			matchedOn: imported.matchedOn,
			matchedScore: imported.matchedScore
		)
		app.parsedMetadata = imported.parsedMetadata ?? existing?.parsedMetadata
		let firstIconPath = imported.selectedIconPath ?? imported.availableIconPaths.first
		app.downloadProgress.iconFilePath = firstIconPath
		return app
	}

	private static func generateMunkiMetadata(
		installerPath: String,
		appDownloadPath: String,
		mode: ConfirmationActionMode
	) async throws -> MunkiMetadata {
		_ = mode
		
		let installerURL = URL(fileURLWithPath: installerPath)
		if installerURL.pathExtension.isEmpty {
			logger.error("[\(logPrefix)] Incompatible file: \(installerPath, privacy: .public) has no file extension. Skipping munkiimport.")
			appLog(.error, LogCategory.upload, "Installer file has no extension: \(installerURL.lastPathComponent). Skipping metadata generation.")
			throw NSError(domain: logPrefix, code: 4, userInfo: [
				NSLocalizedDescriptionKey: "Installer file has no extension: \(installerURL.lastPathComponent)"
			])
		}

		let home = FileManager.default.homeDirectoryForCurrentUser
		let cacheDir = home
			.appendingPathComponent("Juice", isDirectory: true)
			.appendingPathComponent("cache", isDirectory: true)
		let pkgsinfo = cacheDir.appendingPathComponent("pkgsinfo", isDirectory: true)
		let pkgs = cacheDir.appendingPathComponent("pkgs", isDirectory: true)
		let icons = cacheDir.appendingPathComponent("icons", isDirectory: true)

		try FileManager.default.createDirectory(at: pkgsinfo, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: pkgs, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
		try clearDirectory(pkgsinfo)
		try clearDirectory(pkgs)
		try clearDirectory(icons)

		let munkiimportPath = "/usr/local/munki/munkiimport"
		guard FileManager.default.fileExists(atPath: munkiimportPath) else {
			throw NSError(domain: logPrefix, code: 3, userInfo: [
				NSLocalizedDescriptionKey: "munkiimport not found at \(munkiimportPath)"
			])
		}
		let process = Process()
		process.executableURL = URL(fileURLWithPath: munkiimportPath)
		process.arguments = ["\(installerPath)", "--nointeractive", "--extract_icon"]
		process.standardOutput = Pipe()
		process.standardError = Pipe()
		try process.run()
		process.waitUntilExit()

		let outputDir = URL(fileURLWithPath: appDownloadPath)
			.appendingPathComponent("output", isDirectory: true)
		try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

		let plistFiles = try latestFiles(in: pkgsinfo)
			.filter { $0.pathExtension.lowercased() == "plist" }
		let pkgFiles = try latestFiles(in: pkgs)
			.filter { ["pkg", "dmg", "mpkg"].contains($0.pathExtension.lowercased()) }
		let iconFiles = try latestFiles(in: icons)
			.filter { ["png", "icns"].contains($0.pathExtension.lowercased()) }

		var metadata = MunkiMetadata()
		if let plist = plistFiles.first {
			let dest = outputDir.appendingPathComponent(plist.lastPathComponent)
			if FileManager.default.fileExists(atPath: dest.path) {
				try FileManager.default.removeItem(at: dest)
			}
			try FileManager.default.copyItem(at: plist, to: dest)
			metadata.installerPlist = dest.path
		} else {
			logger.error("[\(logPrefix)] munkiimport produced no plist in \(pkgsinfo.path, privacy: .public)")
		}
		if let pkg = pkgFiles.first {
			let dest = outputDir.appendingPathComponent(pkg.lastPathComponent)
			if FileManager.default.fileExists(atPath: dest.path) {
				try FileManager.default.removeItem(at: dest)
			}
			try FileManager.default.copyItem(at: pkg, to: dest)
			metadata.installerFile = dest.path
		} else {
			logger.error("[\(logPrefix)] munkiimport produced no installer in \(pkgs.path, privacy: .public)")
		}
		if let icon = iconFiles.first {
			let dest = outputDir.appendingPathComponent(icon.lastPathComponent)
			if FileManager.default.fileExists(atPath: dest.path) {
				try FileManager.default.removeItem(at: dest)
			}
			try FileManager.default.copyItem(at: icon, to: dest)
			metadata.iconFile = dest.path
		} else {
			logger.error("[\(logPrefix)] munkiimport produced no icon in \(icons.path, privacy: .public)")
		}

		return metadata
	}

	private static func clearDirectory(_ url: URL) throws {
		let items = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
		for item in items {
			try? FileManager.default.removeItem(at: item)
		}
	}

	private static func latestFiles(in url: URL) throws -> [URL] {
		let files = (try? FileManager.default.contentsOfDirectory(
			at: url,
			includingPropertiesForKeys: [.contentModificationDateKey],
			options: [.skipsHiddenFiles]
		)) ?? []
		return files.sorted { lhs, rhs in
			let ldate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
			let rdate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
			return ldate > rdate
		}
	}

	private static func buildSuccessfulDownload(
		app: CaskApplication,
		installerURL: URL,
		appFolderURL: URL,
		metadata: MunkiMetadata
	) throws -> SuccessfulDownload {
		let fileName = installerURL.lastPathComponent
		let fileExtension = installerURL.pathExtension
		let outputFolder = appFolderURL.appendingPathComponent("output", isDirectory: true)
		#if os(macOS)
		var icons: [NSImage] = []
		let iconFiles = (try? FileManager.default.contentsOfDirectory(at: outputFolder, includingPropertiesForKeys: nil)) ?? []
		for icon in iconFiles where icon.pathExtension.lowercased() == "png" {
			if let image = NSImage(contentsOf: icon) {
				icons.append(image)
			}
		}
		var success = SuccessfulDownload(
			fileName: fileName,
			fileExtension: fileExtension,
			fullFilePath: installerURL.path,
			fullFolderPath: appFolderURL.path,
			availableIcons: icons
		)
		#else
		var success = SuccessfulDownload(
			fileName: fileName,
			fileExtension: fileExtension,
			fullFilePath: installerURL.path,
			fullFolderPath: appFolderURL.path
		)
		#endif
		success.munkiMetadata = metadata
		success.macApplication = app
		success.parsedMetadata = parseInstallerPlist(metadata.installerPlist)
		return success
	}

	static func minimalSuccessfulDownload(app: CaskApplication) throws -> SuccessfulDownload {
		let destinationURL: URL
		let fileName: String
		let fileExtension: String
		let appFolderURL: URL
		do {
			let resolved = try resolveDownloadDestination(for: app)
			destinationURL = resolved.0
			fileName = resolved.1
			fileExtension = resolved.2
			appFolderURL = destinationURL.deletingLastPathComponent()
		} catch {
			fileName = fileNameFromURL(app.url)
			let ext = (fileName as NSString).pathExtension
			fileExtension = ext.isEmpty ? "file" : ext
			let folderName = app.fullToken.isEmpty ? app.token : app.fullToken
			let version = app.version.replacingOccurrences(of: ",", with: "")
			let home = FileManager.default.homeDirectoryForCurrentUser
			appFolderURL = home
				.appendingPathComponent("Juice", isDirectory: true)
				.appendingPathComponent(folderName, isDirectory: true)
				.appendingPathComponent(version, isDirectory: true)
			try FileManager.default.createDirectory(
				at: appFolderURL,
				withIntermediateDirectories: true
			)
			destinationURL = appFolderURL.appendingPathComponent(fileName)
		}
		#if os(macOS)
		var icons: [NSImage] = []
		let outputFolder = appFolderURL.appendingPathComponent("output", isDirectory: true)
		let iconFiles = (try? FileManager.default.contentsOfDirectory(at: outputFolder, includingPropertiesForKeys: nil)) ?? []
		for icon in iconFiles where icon.pathExtension.lowercased() == "png" {
			if let image = NSImage(contentsOf: icon) {
				icons.append(image)
			}
		}
		var success = SuccessfulDownload(
			fileName: fileName,
			fileExtension: fileExtension,
			fullFilePath: destinationURL.path,
			fullFolderPath: appFolderURL.path,
			availableIcons: icons
		)
		#else
		var success = SuccessfulDownload(
			fileName: fileName,
			fileExtension: fileExtension,
			fullFilePath: destinationURL.path,
			fullFolderPath: appFolderURL.path
		)
		#endif
		success.munkiMetadata = nil
		success.macApplication = app
		success.parsedMetadata = nil
		return success
	}

	static func parseInstallerPlist(_ path: String?) -> ParsedMetadata? {
		guard let path else { return nil }
		guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
		let decoder = PropertyListDecoder()
		return try? decoder.decode(ParsedMetadata.self, from: data)
	}

	static func writeInstallerPlist(
		for download: SuccessfulDownload,
		parsedMetadata: ParsedMetadata
	) throws {
		guard let plistPath = download.munkiMetadata?.installerPlist else { return }
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .xml
		let data = try encoder.encode(parsedMetadata)
		try data.write(to: URL(fileURLWithPath: plistPath), options: [.atomic])
	}

	private static func writeMetadataJson(app: CaskApplication, folderURL: URL) throws {
		let fileURL = folderURL.appendingPathComponent("metadata.json")
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let data = try encoder.encode(app)
		try data.write(to: fileURL, options: [.atomic])
	}

	private static func createFileBlob(
		fileURL: URL,
		onProgress: @escaping @Sendable (Int64, Int64) -> Void = { _, _ in }
	) async throws -> String {
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard
			let authHeaders = await AuthService.instance.authorizationHeaders(
				for: activeEnvironment
			)
		else {
			return ""
		}
		guard let baseURL = URL(string: activeEnvironment.uemUrl) else { return "" }
		let fileName = fileURL.lastPathComponent
		let orgGroupId = activeEnvironment.orgGroupId
		let url = URL(
			string: "/api/mam/blobs/uploadblob?fileName=\(fileName)&organizationGroupId=\(orgGroupId)",
			relativeTo: baseURL
		)
		guard let uploadURL = url else { return "" }

		var request = URLRequest(url: uploadURL)
		request.httpMethod = "POST"
		request.timeoutInterval = 6 * 60 * 60
		for (header, value) in authHeaders {
			request.setValue(value, forHTTPHeaderField: header)
		}
		request.setValue("application/json, application/json;version=2", forHTTPHeaderField: "Accept")
		request.setValue(contentType(for: fileURL.pathExtension), forHTTPHeaderField: "Content-Type")
		request.setValue(nil, forHTTPHeaderField: "Expect")
		let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
		request.setValue(
			"attachment; filename=\"\(fileName)\"; filename*=UTF-8''\(encodedFileName)",
			forHTTPHeaderField: "Content-Disposition"
		)

		let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
		logger.info("[Upload] Starting blob upload. file=\(fileURL.lastPathComponent, privacy: .public) bytes=\(fileSize, privacy: .public) url=\(uploadURL.absoluteString, privacy: .public)")

		let (data, response): (Data, URLResponse)
		do {
			(data, response) = try await uploadFileWithInactivityTimeout(
				request: request,
				fileURL: fileURL,
				onProgress: onProgress
			)
		} catch {
			let nsError = error as NSError
			logger.error("[Upload] Blob upload error. file=\(fileURL.lastPathComponent, privacy: .public) code=\(nsError.code, privacy: .public) domain=\(nsError.domain, privacy: .public) desc=\(nsError.localizedDescription, privacy: .public)")
			throw error
		}
		guard let http = response as? HTTPURLResponse else {
			logger.error("[Upload] Missing HTTP response for blob upload. file=\(fileURL.lastPathComponent, privacy: .public)")
			return ""
		}
		guard http.statusCode < 400 else {
			let bodySnippet = String(data: data, encoding: .utf8)?
				.prefix(500) ?? ""
			logger.error("[Upload] Blob upload failed. file=\(fileURL.lastPathComponent, privacy: .public) status=\(http.statusCode, privacy: .public) body=\(bodySnippet, privacy: .public)")
			dumpUploadResponseIfNeeded(data: data, fileURL: fileURL, statusCode: http.statusCode)
			return ""
		}
		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			let bodySnippet = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
			logger.error("[Upload] Blob upload response was not JSON. file=\(fileURL.lastPathComponent, privacy: .public) status=\(http.statusCode, privacy: .public) body=\(bodySnippet, privacy: .public)")
			dumpUploadResponseIfNeeded(data: data, fileURL: fileURL, statusCode: http.statusCode)
			return ""
		}
		if let value = json["Value"] as? String { return value }
		if let value = json["Value"] as? NSNumber { return value.stringValue }
		if let value = json["value"] as? String { return value }
		if let value = json["value"] as? NSNumber { return value.stringValue }
		if let value = json["Id"] as? NSNumber { return value.stringValue }
		if let value = json["id"] as? NSNumber { return value.stringValue }
		logger.error("[Upload] Blob upload response missing Value. file=\(fileURL.lastPathComponent, privacy: .public) status=\(http.statusCode, privacy: .public) keys=\(Array(json.keys), privacy: .public)")
		dumpUploadResponseIfNeeded(data: data, fileURL: fileURL, statusCode: http.statusCode)
		return ""
	}

	private static func createMacOsApplication(
		pkgInfoBlobId: String,
		applicationBlobId: String,
		applicationIconBlobId: String,
		version: String
	) async throws -> Bool {
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard
			let authHeaders = await AuthService.instance.authorizationHeaders(
				for: activeEnvironment
			)
		else {
			return false
		}
		guard let baseURL = URL(string: activeEnvironment.uemUrl) else { return false }
		let orgGroupId = activeEnvironment.orgGroupId
		guard let url = URL(string: "/api/mam/groups/\(orgGroupId)/macos/apps", relativeTo: baseURL) else {
			return false
		}

		let body: [String: Any] = [
			"pkgInfoBlobId": Int(pkgInfoBlobId) ?? 0,
			"applicationBlobId": Int(applicationBlobId) ?? 0,
			"applicationIconId": Int(applicationIconBlobId) ?? 0,
			"version": version
		]
		let bodyData = try JSONSerialization.data(withJSONObject: body)
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		for (header, value) in authHeaders {
			request.setValue(value, forHTTPHeaderField: header)
		}
		request.setValue("application/json; version=1", forHTTPHeaderField: "Accept")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = bodyData

		let (data, response): (Data, URLResponse)
		do {
			(data, response) = try await dataWithoutInactivityTimeout(request: request)
		} catch {
			let nsError = error as NSError
			logger.error("[Upload] createMacOsApplication error. code=\(nsError.code, privacy: .public) domain=\(nsError.domain, privacy: .public) desc=\(nsError.localizedDescription, privacy: .public)")
			throw error
		}
		guard let http = response as? HTTPURLResponse else {
			logger.error("[Upload] Missing HTTP response for createMacOsApplication.")
			return false
		}
		let ok = http.statusCode >= 200 && http.statusCode < 300
		if !ok {
			let bodySnippet = String(data: data, encoding: .utf8)?
				.prefix(500) ?? ""
			logger.error("[Upload] createMacOsApplication failed. status=\(http.statusCode, privacy: .public) body=\(bodySnippet, privacy: .public)")
		}
		return ok
	}

	private static func uploadFileWithInactivityTimeout(
		request: URLRequest,
		fileURL: URL,
		onProgress: @escaping @Sendable (Int64, Int64) -> Void
	) async throws -> (Data, URLResponse) {
		let config = URLSessionConfiguration.default
		config.timeoutIntervalForRequest = 6 * 60 * 60
		config.timeoutIntervalForResource = 24 * 60 * 60
		config.waitsForConnectivity = true
		let delegate = BlobUploadDelegate(
			inactivityTimeout: inactivityTimeout,
			onProgress: onProgress
		)
		let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
		return try await withCheckedThrowingContinuation { continuation in
			delegate.continuation = continuation
			let task = session.uploadTask(with: request, fromFile: fileURL)
			delegate.startWatchdog(for: task)
			task.resume()
		}
	}

	private static func dataWithoutInactivityTimeout(request: URLRequest) async throws -> (Data, URLResponse) {
		let config = URLSessionConfiguration.default
		config.timeoutIntervalForRequest = 6 * 60 * 60
		config.timeoutIntervalForResource = 24 * 60 * 60
		let session = URLSession(configuration: config)
		return try await session.data(for: request)
	}

	private static func contentType(for ext: String) -> String {
		switch ext.lowercased() {
		case "dmg": return "application/x-apple-diskimage"
		case "png": return "image/png"
		case "jpg", "jpeg": return "image/jpeg"
		case "plist": return "application/x-plist"
		default: return "application/octet-stream"
		}
	}

	private static func formatBytes(_ bytes: Int64) -> String {
		guard bytes > 0 else { return "0 B" }
		let units: [String] = ["B", "KB", "MB", "GB"]
		let base = 1024.0
		let exponent = min(Int(log(Double(bytes)) / log(base)), units.count - 1)
		let value = Double(bytes) / pow(base, Double(exponent))
		return String(format: "%.1f %@", value, units[exponent])
	}

	private static func dumpUploadResponseIfNeeded(
		data: Data,
		fileURL: URL,
		statusCode: Int
	) {
		let env = ProcessInfo.processInfo.environment
		guard env["JUICE_DUMP_UPLOAD_RESPONSE"] == "1" else { return }

		let timestamp = String(format: "%.0f", Date().timeIntervalSince1970)
		let sanitizedName = fileURL.lastPathComponent
			.replacingOccurrences(of: " ", with: "_")
			.replacingOccurrences(of: "/", with: "_")
		let outputURL = URL(fileURLWithPath: "/tmp")
			.appendingPathComponent("juice_upload_response_\(sanitizedName)_\(statusCode)_\(timestamp).log")

		do {
			try data.write(to: outputURL, options: [.atomic])
			logger.error("[Upload] Dumped response body to \(outputURL.path, privacy: .public)")
		} catch {
			let nsError = error as NSError
			logger.error("[Upload] Failed to dump response body. file=\(outputURL.path, privacy: .public) code=\(nsError.code, privacy: .public) domain=\(nsError.domain, privacy: .public)")
		}
	}

	@MainActor
	private static func updateDownloadProgress(
		_ app: CaskApplication,
		update: (inout DownloadProgress) -> Void
	) throws {
		var progress = app.downloadProgress
		update(&progress)
		app.downloadProgress = progress
	}
}
