import SwiftUI
import os
#if os(macOS)
import AppKit
#endif

// Download queue state machine and orchestration for download/edit/upload flows.
// Used by: DownloadQueuePanelContent and DownloadQueueRowComponents.

@MainActor
final class DownloadQueueViewModel: ObservableObject {
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Juice", category: "DownloadQueue")
	enum Stage: String {
		case idle
		case downloading
		case editing
		case uploading
		case completed
		case cancelled
	}

	@Published private(set) var stage: Stage = .idle
	@Published private(set) var queueItems: [CaskApplication] = []
	@Published private(set) var results: [DownloadResultItem] = []
	@Published private(set) var statusText: String = "Waiting to start..."
	@Published private(set) var currentAppName: String = ""
	@Published private(set) var successCount: Int = 0
	@Published private(set) var errorCount: Int = 0
	@Published private(set) var completedCount: Int = 0
	@Published private(set) var totalCount: Int = 0
	@Published private(set) var isRunning: Bool = false
	@Published var editableDownloads: [EditableDownload] = []

	@Published private var uploadProgress: [String: UploadProgress] = [:]
	private var mode: ConfirmationActionMode = .upload
	private var cancelRequested = false
	private var started = false
	private var recipesById: [String: Recipe] = [:]
	private var skippedUploadIds: Set<String> = []

	var queueCountText: String {
		let remaining = stage == .editing
			? (editableDownloads.isEmpty ? queueItems.count : editableDownloads.count)
			: queueItems.count
		if stage == .editing {
			return remaining == 1 ? "1 item ready to edit" : "\(remaining) items ready to edit"
		}
		return remaining == 1 ? "1 item remaining" : "\(remaining) items remaining"
	}

	var resultsCountText: String {
		let processed = results.count
		return processed == 1 ? "1 app processed" : "\(processed) apps processed"
	}

	var stageText: String {
		switch stage {
		case .idle: return "Ready"
		case .downloading: return "Downloading"
		case .editing: return "Review"
		case .uploading: return "Uploading"
		case .completed: return "Completed"
		case .cancelled: return "Cancelled"
		}
	}

	var stageProgressText: String {
		switch stage {
		case .downloading: return "Stage 1 of 3"
		case .editing: return "Stage 2 of 3"
		case .uploading: return "Stage 3 of 3"
		default: return ""
		}
	}

	var progressText: String {
		guard totalCount > 0 else { return "0 / 0" }
		return "\(completedCount) / \(totalCount)"
	}

	var shouldPresentPanel: Bool {
		switch stage {
		case .downloading, .editing, .uploading:
			return true
		case .completed, .cancelled:
			return !results.isEmpty
		case .idle:
			return false
		}
	}

	func reset() {
		results.removeAll()
		stage = .idle
		isRunning = false
		started = false
		totalCount = 0
		completedCount = 0
		successCount = 0
		errorCount = 0
	}

	func configure(queue: [CaskApplication], mode: ConfirmationActionMode, recipes: [Recipe]) {
		self.queueItems = queue
		self.mode = mode
		var map: [String: Recipe] = [:]
		var duplicateIds: [String] = []
		for recipe in recipes {
			guard let id = recipe.identifier else { continue }
			if map[id] != nil {
				duplicateIds.append(id)
			}
			// Prefer the last occurrence if duplicates exist.
			map[id] = recipe
		}
		self.recipesById = map
		if !duplicateIds.isEmpty {
			let unique = Array(Set(duplicateIds)).sorted()
			appLog(
				.debug,
				LogCategory.queue,
				"Duplicate recipe identifiers found",
				event: "queue.recipe_duplicates",
				metadata: ["ids": unique.joined(separator: ",")]
			)
		}
		self.results = []
		self.editableDownloads = []
		self.successCount = 0
		self.errorCount = 0
		self.completedCount = 0
		self.totalCount = queue.count
		self.cancelRequested = false
		self.stage = .idle
		self.statusText = "Ready to begin"
		self.started = false
		resetProgress()
	}

	func startIfNeeded() {
		guard !started else { return }
		started = true
		start()
	}

	func start() {
		guard !isRunning else { return }
		isRunning = true
		cancelRequested = false
		Task { await run() }
	}

	func cancel() {
		cancelAndClearQueues()
	}

	func cancelAndClearQueues() {
		cancelRequested = true
		queueItems.removeAll()
		editableDownloads.removeAll()
		uploadProgress.removeAll()
		successCount = 0
		errorCount = 0
		completedCount = 0
		totalCount = 0
		isRunning = false
		stage = .idle
		statusText = "Ready to begin"
	}

	func clearQueue() {
		queueItems.removeAll()
	}

	func clearResults() {
		results.removeAll()
	}

	var hasEditableDownloads: Bool {
		!editableDownloads.isEmpty
	}

	private var hasMetadataErrors: Bool {
		editableDownloads.contains { $0.metadataError != nil }
	}

	private var hasRecipeErrors: Bool {
		editableDownloads.contains { $0.recipeError != nil }
	}

	private var hasPreparationErrors: Bool {
		editableDownloads.contains { $0.preparationError != nil }
	}

	func updateEditableMetadata(
		_ downloadId: String,
		metadataText: String
	) {
		guard let index = editableDownloads.firstIndex(where: { $0.id == downloadId }) else { return }
		editableDownloads[index].metadataText = metadataText
		if let parsed = parseMetadata(from: metadataText) {
			editableDownloads[index].parsedMetadata = parsed
			editableDownloads[index].displayName = EditableDownload.resolvedDisplayName(
				metadata: parsed,
				fallbackName: editableDownloads[index].baseDownload.macApplication?.name.first,
				fileName: editableDownloads[index].baseDownload.fileName
			)
			editableDownloads[index].metadataError = nil
			editableDownloads[index].syncScripts(from: parsed)
		} else {
			editableDownloads[index].metadataError = "Invalid metadata JSON."
			Self.logger.error("Metadata JSON parse failed for \(self.editableDownloads[index].displayName, privacy: .public)")
			appLog(
				.error,
				LogCategory.queue,
				"Metadata JSON parse failed",
				event: "queue.metadata_parse_failed",
				metadata: ["app_name": self.editableDownloads[index].displayName]
			)
		}
	}

	func updateEditableRecipe(_ downloadId: String, recipeText: String) {
		guard let index = editableDownloads.firstIndex(where: { $0.id == downloadId }) else { return }
		editableDownloads[index].recipeText = recipeText
		if let parsed = parseRecipe(from: recipeText) {
			editableDownloads[index].parsedRecipe = parsed
			editableDownloads[index].recipeError = nil
		} else {
			editableDownloads[index].recipeError = "Invalid recipe JSON."
			Self.logger.error("Recipe JSON parse failed for \(self.editableDownloads[index].displayName, privacy: .public)")
			appLog(
				.error,
				LogCategory.queue,
				"Recipe JSON parse failed",
				event: "queue.recipe_parse_failed",
				metadata: ["app_name": self.editableDownloads[index].displayName]
			)
		}
	}

	enum ScriptField {
		case preinstall
		case postinstall
		case preuninstall
		case postuninstall
		case installcheck
		case uninstallcheck
	}

	func updateScript(_ downloadId: String, field: ScriptField, value: String) {
		guard let index = editableDownloads.firstIndex(where: { $0.id == downloadId }) else { return }
		switch field {
		case .preinstall: editableDownloads[index].preinstallScript = value
		case .postinstall: editableDownloads[index].postinstallScript = value
		case .preuninstall: editableDownloads[index].preuninstallScript = value
		case .postuninstall: editableDownloads[index].postuninstallScript = value
		case .installcheck: editableDownloads[index].installcheckScript = value
		case .uninstallcheck: editableDownloads[index].uninstallcheckScript = value
		}

		var metadata = editableDownloads[index].parsedMetadata ?? ParsedMetadata()
		applyScripts(from: editableDownloads[index], to: &metadata)
		editableDownloads[index].parsedMetadata = metadata
		editableDownloads[index].metadataText = EditableDownload.encodeMetadata(metadata)
		editableDownloads[index].metadataError = nil
	}

	func selectIcon(downloadId: String, iconIndex: Int) {
		guard let index = editableDownloads.firstIndex(where: { $0.id == downloadId }) else { return }
		editableDownloads[index].selectedIconIndex = iconIndex
	}

	func startUploadAfterEdits() {
		guard stage == .editing else { return }
		if hasMetadataErrors || hasRecipeErrors || hasPreparationErrors {
			statusText = "Fix errors before continuing"
			return
		}
		stage = .uploading
		statusText = "Checking existing apps"
		isRunning = true
		prepareUploadQueueStatus()
		Task { await preflightAndUpload() }
	}

	func uploadStatus(for app: CaskApplication) -> UploadProgress? {
		uploadProgress[app.id]
	}

	private func resetProgress() {
		for app in queueItems {
			app.downloadProgress = DownloadProgress()
		}
		uploadProgress.removeAll()
	}

	private func applyQueueIcon(from editable: EditableDownload, to app: CaskApplication) {
		guard let firstIcon = editable.iconPaths.first else { return }
		app.downloadProgress.iconFilePath = firstIcon.path
	}

	private func prepareUploadQueueStatus() {
		uploadProgress.removeAll()
		for (index, app) in queueItems.enumerated() {
			if index == 0 {
				uploadProgress[app.id] = UploadProgress(
					uploadProgressString: "Preparing to upload",
					uploadPercent: 0,
					isComplete: false,
					inProgress: true,
					isSuccess: false,
					appExists: false,
					fullFilePath: ""
				)
			} else {
				uploadProgress[app.id] = UploadProgress(
					uploadProgressString: "Waiting to upload",
					uploadPercent: 0,
					isComplete: false,
					inProgress: false,
					isSuccess: false,
					appExists: false,
					fullFilePath: ""
				)
			}
			app.downloadProgress.currentState = "Waiting to upload"
			app.downloadProgress.inProgress = false
			app.downloadProgress.isComplete = false
			app.downloadProgress.isSuccess = false
		}
	}

	private func preflightAndUpload() async {
		statusText = "Checking existing apps"
		let currentUemApps: [UemApplication] =
			(mode == .upload || mode == .uploadOnly)
			? await UEMService.instance.getAllApps(includeVersionChecks: false).compactMap { $0 }
			: []

		skippedUploadIds.removeAll()

		for editable in editableDownloads {
			if cancelRequested { break }
			let prepared = preparedDownload(from: editable)
			let app = prepared.macApplication ?? editable.baseDownload.macApplication
			let exists = await UEMService.instance.checkForExistingApp(
				currentUemApps,
				successfulDownload: prepared
			)
			if let app {
				if exists {
					skippedUploadIds.insert(app.id)
					updateUploadStatus(
						app,
						inProgress: false,
						status: "Already exists in Workspace ONE - Skipped",
						isSuccess: false,
						appExists: true
					)
				} else {
					updateUploadStatus(app, inProgress: false, status: "Waiting to upload")
				}
			}
		}

		await uploadEditedDownloads()
	}

	private func run() async {
		statusText = "Downloading"
		stage = .downloading
		let pending = queueItems
		let _: [UemApplication] =
			(mode == .upload || mode == .uploadOnly)
			? await UEMService.instance.getAllApps(includeVersionChecks: false).compactMap { $0 }
			: []

		for app in pending {
			if cancelRequested { break }
			currentAppName = app.name.first ?? app.token
			statusText = "Downloading"
			stage = .downloading

			do {
				let output = try await DownloadUploadService.downloadAndPrepare(
					app,
					mode: mode,
					shouldCancel: { [weak self] in
						self?.cancelRequested ?? false
					}
				)
				
				let currentState = app.downloadProgress.currentState ?? ""
				if currentState.contains("Archive type is not supported") || currentState.contains("Metadata cannot be processed") || currentState.contains("File cannot be uncompressed") || currentState.contains("Skipped") {
					// Unsupported file type - downloaded but cannot be processed for UEM upload
					errorCount += 1
					appendResult(
						name: currentAppName,
						message: currentState,
						isSuccess: false,
						iconFilePath: app.downloadProgress.iconFilePath
					)
				} else {
					var editable = EditableDownload.from(output: output)
					if let recipeId = app.matchingRecipeId {
						editable.recipeIdentifier = recipeId
						if let recipe = recipesById[recipeId] {
							editable = editable.withRecipe(recipeId: recipeId, recipe: recipe)
						}
					}
					
					if mode == .upload || mode == .uploadOnly {
						editableDownloads.append(editable)
						applyQueueIcon(from: editable, to: app)
						app.downloadProgress.currentState = "Downloaded - ready to edit"
					}

					if cancelRequested { break }

					if mode == .download {
						successCount += 1
						appendResult(
							name: currentAppName,
							message: "App Downloaded Successfully",
							isSuccess: true,
							iconFilePath: app.downloadProgress.iconFilePath
						)
						appLog(
							.info,
							LogCategory.queue,
							"Download successful for \(currentAppName)",
							event: "queue.download_success",
							metadata: [
								"app_name": currentAppName
							]
						)
					}
				}
			} catch {
				let errorMessage = error.localizedDescription
				app.downloadProgress.isComplete = true
				app.downloadProgress.inProgress = false
				app.downloadProgress.isSuccess = false
				app.downloadProgress.currentState = "Failed"

				errorCount += 1
				appendResult(
					name: currentAppName,
					message: "App Download Failed: \(errorMessage)",
					isSuccess: false,
					iconFilePath: app.downloadProgress.iconFilePath
				)
				
				appLog(
					.error,
					LogCategory.queue,
					"Download failed for \(currentAppName): \(errorMessage)",
					event: "queue.download_error",
					metadata: [
						"app_name": currentAppName,
						"reason": errorMessage
					]
				)
			}

			completedCount += 1
		}

		queueItems.removeAll { app in
			let currentState = app.downloadProgress.currentState ?? ""
			return mode == .download || currentState.contains("Archive type is not supported") || currentState.contains("Metadata cannot be processed") || currentState.contains("File cannot be uncompressed") || currentState.contains("Skipped") || currentState.contains("Failed")
		}

		if cancelRequested {
			objectWillChange.send()
			cancelAndClearQueues()
			return
		}

		if mode == .upload || mode == .uploadOnly {
			if editableDownloads.isEmpty {
				// Nothing to edit (all failed or skipped)
				objectWillChange.send()
				stage = .completed
				statusText = "Finished"
				isRunning = false
			} else {
				objectWillChange.send()
				stage = .editing
				statusText = "Edit Metadata"
				isRunning = false
			}
			return
		}

		objectWillChange.send()
		stage = .completed
		statusText = "Finished"
		isRunning = false
	}

	private func uploadEditedDownloads() async {
		statusText = "Uploading Files"
		for editable in editableDownloads {
			if cancelRequested { break }
			let prepared = preparedDownload(from: editable)
			if let app = prepared.macApplication ?? editable.baseDownload.macApplication,
			   skippedUploadIds.contains(app.id) {
				continue
			}
			let appName = editable.displayName
			statusText = "Uploading Files"
			updateUploadStatus(
				prepared.macApplication ?? editable.baseDownload.macApplication,
				inProgress: true,
				status: "Preparing to upload",
				uploadPercent: 0
			)
			if let parsed = prepared.parsedMetadata {
				try? DownloadUploadService.writeInstallerPlist(
					for: prepared,
					parsedMetadata: parsed
				)
			}

			updateUploadStatus(
				prepared.macApplication,
				inProgress: true,
				status: "Uploading metadata...",
				uploadPercent: 0
			)
			do {
				let uploadOK = try await DownloadUploadService.uploadSuccessfulDownload(
					prepared,
					shouldCancel: { [weak self] in
						self?.cancelRequested ?? false
					},
					onStatus: { [weak self] status in
						self?.updateUploadStatus(
							prepared.macApplication,
							inProgress: true,
							status: status
						)
					},
					onProgress: { [weak self] update in
						guard let self else { return }
						switch update.phase {
						case .metadata:
							self.updateUploadStatus(
								prepared.macApplication,
								inProgress: true,
								status: "Uploading metadata...",
								uploadPercent: 0
							)
						case .icons:
							self.updateUploadStatus(
								prepared.macApplication,
								inProgress: true,
								status: "Uploading icons...",
								uploadPercent: 0
							)
						case .installer:
							self.updateUploadStatus(
								prepared.macApplication,
								inProgress: true,
								status: "Uploading installer...",
								uploadPercent: update.percent
							)
						}
					}
				)
				if uploadOK {
					successCount += 1
					updateUploadStatus(
						prepared.macApplication,
						inProgress: false,
						status: "Upload complete",
						uploadPercent: 100,
						isSuccess: true
					)
					appendResult(
						name: appName,
						message: "App Added Successfully",
						isSuccess: true,
						iconFilePath: prepared.macApplication?.downloadProgress.iconFilePath
					)
				} else {
					Self.logger.error("Upload failed for \(appName, privacy: .public): uploadSuccessfulDownload returned false.")
					appLog(
						.error,
						LogCategory.queue,
						"Upload failed",
						event: "queue.upload_failed",
						metadata: ["app_name": appName]
					)
					errorCount += 1
					updateUploadStatus(
						prepared.macApplication,
						inProgress: false,
						status: "Upload failed",
						isSuccess: false
					)
					appendResult(
						name: appName,
						message: "App Upload Failed",
						isSuccess: false,
						iconFilePath: prepared.macApplication?.downloadProgress.iconFilePath
					)
				}
			} catch {
				Self.logger.error("Upload error for \(appName, privacy: .public): \(error.localizedDescription, privacy: .public)")
				appLog(
					.error,
					LogCategory.queue,
					"Upload error",
					event: "queue.upload_error",
					metadata: [
						"app_name": appName,
						"reason": error.localizedDescription
					]
				)
				errorCount += 1
				updateUploadStatus(
					prepared.macApplication,
					inProgress: false,
					status: "Upload failed",
					isSuccess: false
				)
				appendResult(
					name: appName,
					message: "App Upload Failed",
					isSuccess: false,
					iconFilePath: prepared.macApplication?.downloadProgress.iconFilePath
				)
			}
		}

		queueItems.removeAll()
		editableDownloads.removeAll()

		objectWillChange.send()
		stage = cancelRequested ? .cancelled : .completed
		if cancelRequested {
			cancelAndClearQueues()
		} else {
			statusText = "Finished"
			isRunning = false
		}
	}

	private func appendResult(
		name: String,
		message: String,
		isSuccess: Bool,
		iconFilePath: String? = nil
	) {
		objectWillChange.send()
		let result = DownloadResultItem(
			id: UUID().uuidString,
			name: name,
			message: message,
			isSuccess: isSuccess,
			iconFilePath: iconFilePath
		)
		results.append(result)
	}

	private func updateUploadStatus(
		_ app: CaskApplication?,
		inProgress: Bool,
		status: String,
		uploadPercent: Int? = nil,
		isSuccess: Bool? = nil,
		appExists: Bool? = nil
	) {
		guard let app else { return }
		var progress = uploadProgress[app.id] ?? UploadProgress()
		progress.inProgress = inProgress
		progress.isComplete = !inProgress
		if let isSuccess {
			progress.isSuccess = isSuccess
		}
		if let appExists {
			progress.appExists = appExists
		}
		if let uploadPercent {
			progress.uploadPercent = min(max(uploadPercent, 0), 100)
		}
		progress.uploadProgressString = status
		uploadProgress[app.id] = progress
	}

	private func parseMetadata(from text: String) -> ParsedMetadata? {
		guard let data = text.data(using: .utf8) else { return nil }
		return try? JSONDecoder().decode(ParsedMetadata.self, from: data)
	}

	private func parseRecipe(from text: String) -> Recipe? {
		guard let data = text.data(using: .utf8) else { return nil }
		return try? JSONDecoder().decode(Recipe.self, from: data)
	}

	private func preparedDownload(from editable: EditableDownload) -> SuccessfulDownload {
		var updated = editable.toSuccessfulDownload()
		var metadata = updated.parsedMetadata ?? ParsedMetadata()
		if let recipe = editable.parsedRecipe {
			applyRecipe(recipe, to: &metadata)
		}
		applyScripts(from: editable, to: &metadata)
		updated.parsedMetadata = metadata
		return updated
	}

	private func applyRecipe(_ recipe: Recipe, to metadata: inout ParsedMetadata) {
		let pkgInfo = recipe.pkgInfo ?? recipe.input?.pkgInfo
		guard let pkgInfo else { return }

		func shouldSet(_ existing: String?) -> Bool {
			existing == nil || existing?.isEmpty == true
		}

		if let value = pkgInfo.category, shouldSet(metadata.category) { metadata.category = value }
		if let value = pkgInfo.iconName, shouldSet(metadata.icon_name) { metadata.icon_name = value }
		if let value = pkgInfo.requires, metadata.requires == nil { metadata.requires = value }
		if let value = pkgInfo.minimumOsVersion, shouldSet(metadata.minimum_os_version) { metadata.minimum_os_version = value }
		if let value = pkgInfo.developer, shouldSet(metadata.developer) { metadata.developer = value }
		if let value = pkgInfo.unattendedInstall, shouldSet(metadata.unattended_install) { metadata.unattended_install = value }
		if let value = pkgInfo.displayName, shouldSet(metadata.display_name) { metadata.display_name = value }
		if let value = pkgInfo.description, shouldSet(metadata.description) { metadata.description = value }
		if let value = pkgInfo.name, shouldSet(metadata.name) { metadata.name = value }
		if let value = pkgInfo.postinstallScript, shouldSet(metadata.postinstall_script) { metadata.postinstall_script = value }
		if let value = pkgInfo.uninstallMethod, shouldSet(metadata.uninstall_method) { metadata.uninstall_method = value }
		if let value = pkgInfo.blockingApplications, metadata.blocking_applications == nil { metadata.blocking_applications = value }
		if let value = pkgInfo.uninstallScript, shouldSet(metadata.uninstall_script) { metadata.uninstall_script = value }
		if let value = pkgInfo.unattendedUninstall, shouldSet(metadata.unattended_uninstall) { metadata.unattended_uninstall = value }
		if let value = pkgInfo.maximumOsVersion, shouldSet(metadata.maximum_os_version) { metadata.maximum_os_version = value }
		if let value = pkgInfo.postuninstallScript, shouldSet(metadata.postuninstall_script) { metadata.postuninstall_script = value }
		if let value = pkgInfo.restartAction, shouldSet(metadata.restart_action) { metadata.restart_action = value }
		if let value = pkgInfo.preinstallScript, shouldSet(metadata.preinstall_script) { metadata.preinstall_script = value }
		if let value = pkgInfo.preuninstallScript, shouldSet(metadata.preuninstall_script) { metadata.preuninstall_script = value }
		if let value = pkgInfo.installcheckScript, shouldSet(metadata.installcheck_script) { metadata.installcheck_script = value }
	}

	private func applyScripts(from editable: EditableDownload, to metadata: inout ParsedMetadata) {
		if !editable.preinstallScript.isEmpty { metadata.preinstall_script = editable.preinstallScript }
		if !editable.postinstallScript.isEmpty { metadata.postinstall_script = editable.postinstallScript }
		if !editable.preuninstallScript.isEmpty { metadata.preuninstall_script = editable.preuninstallScript }
		if !editable.postuninstallScript.isEmpty { metadata.postuninstall_script = editable.postuninstallScript }
		if !editable.installcheckScript.isEmpty { metadata.installcheck_script = editable.installcheckScript }
		if let uninstall = editable.uninstallcheckScript, !uninstall.isEmpty {
			metadata.uninstallcheck_script = uninstall
		}
	}

	func updateEditedDownload(_ updated: EditableDownload) {
		guard let index = editableDownloads.firstIndex(where: { $0.id == updated.id }) else { return }
		editableDownloads[index] = updated
	}
}

extension DownloadQueueViewModel {
	enum PreviewState {
		case idle
		case downloading
		case editing
		case uploading
		case completed
		case cancelled
	}

	static func previewModel(_ state: PreviewState) -> DownloadQueueViewModel {
		let model = DownloadQueueViewModel()
		let app = previewApp(
			token: "slack",
			name: "Slack",
			state: "Waiting...",
			percent: 0
		)
		let app2 = previewApp(
			token: "zoom",
			name: "Zoom",
			state: "Waiting...",
			percent: 0
		)
		switch state {
		case .idle:
			model.stage = .idle
			model.statusText = "Ready to begin"
			model.queueItems = []
			model.results = []
			model.totalCount = 0
			model.completedCount = 0
			model.isRunning = false
		case .downloading:
			app.downloadProgress.currentState = "Downloading..."
			app.downloadProgress.inProgress = true
			app.downloadProgress.isIndeterminate = false
			app.downloadProgress.downloadPercent = 42
			app.downloadProgress.downloadPercentString = "42%"
			app2.downloadProgress.currentState = "Waiting..."
			app2.downloadProgress.inProgress = false
			model.stage = .downloading
			model.statusText = "Downloading"
			model.queueItems = [app, app2]
			model.totalCount = 2
			model.completedCount = 0
			model.isRunning = true
		case .editing:
			model.stage = .editing
			model.statusText = "Edit Metadata"
			model.queueItems = [app]
			model.totalCount = 1
			model.completedCount = 1
			model.editableDownloads = [previewEditableDownload()]
			model.isRunning = false
		case .uploading:
			model.stage = .uploading
			model.statusText = "Uploading Files"
			model.queueItems = [app]
			model.totalCount = 1
			model.completedCount = 1
			model.isRunning = true
			model.uploadProgress[app.id] = UploadProgress(
				uploadProgressString: "Uploading metadata...",
				uploadPercent: 0,
				isComplete: false,
				inProgress: true,
				isSuccess: false,
				appExists: false,
				fullFilePath: ""
			)
		case .completed:
			model.stage = .completed
			model.statusText = "Completed"
			model.queueItems = []
			model.totalCount = 2
			model.completedCount = 2
			model.results = [
				DownloadResultItem(
					id: "slack",
					name: "Slack",
					message: "Uploaded successfully",
					isSuccess: true,
					iconFilePath: app.downloadProgress.iconFilePath
				),
				DownloadResultItem(
					id: "zoom",
					name: "Zoom",
					message: "Failed to generate metadata",
					isSuccess: false,
					iconFilePath: app2.downloadProgress.iconFilePath
				)
			]
			model.isRunning = false
		case .cancelled:
			app.downloadProgress.currentState = "Cancelled"
			app.downloadProgress.isComplete = true
			app.downloadProgress.isSuccess = false
			model.stage = .cancelled
			model.statusText = "Cancelled"
			model.queueItems = [app]
			model.totalCount = 2
			model.completedCount = 1
			model.isRunning = false
		}
		return model
	}

	private static func previewApp(
		token: String,
		name: String,
		state: String,
		percent: Int
	) -> CaskApplication {
		let iconURL = previewIconURL(for: token)
		let app = CaskApplication(
			token: token,
			fullToken: token,
			name: [name],
			desc: "Preview app",
			url: "https://example.com/\(name).dmg",
			version: "4.46.104"
		)
		app.downloadProgress.currentState = state
		app.downloadProgress.downloadPercent = percent
		app.downloadProgress.downloadPercentString = "\(percent)%"
		app.downloadProgress.iconFilePath = iconURL?.path
		return app
	}

	private static func previewEditableDownload() -> EditableDownload {
		let iconURL = previewIconURL(for: "slack")
		return EditableDownload(
			id: UUID().uuidString,
			displayName: "Slack",
			baseDownload: SuccessfulDownload(
				fileName: "Slack.dmg",
				fileExtension: "dmg",
				fullFilePath: "/Users/pete/Juice/slack/4.46.104/Slack.dmg",
				fullFolderPath: "/tmp/juice_preview_icons/slack"
			),
			iconPaths: iconURL.map { [$0] } ?? [],
			selectedIconIndex: 0,
			parsedMetadata: ParsedMetadata(),
			metadataText: "{}",
			metadataError: nil,
			preparationError: nil,
			recipeIdentifier: nil,
			recipeText: nil,
			recipeError: nil,
			parsedRecipe: nil,
			preinstallScript: "",
			postinstallScript: "",
			preuninstallScript: "",
			postuninstallScript: "",
			installcheckScript: "",
			uninstallcheckScript: nil
		)
	}

	private static func previewIconURL(for token: String) -> URL? {
		#if os(macOS)
		let baseFolder = URL(fileURLWithPath: "/tmp/juice_preview_icons")
			.appendingPathComponent(token, isDirectory: true)
		let outputFolder = baseFolder.appendingPathComponent("output", isDirectory: true)
		let iconURL = outputFolder.appendingPathComponent("icon.png")
		if ProcessInfo.isRunningForPreviews {
			try? FileManager.default.createDirectory(
				at: outputFolder,
				withIntermediateDirectories: true
			)
			if !FileManager.default.fileExists(atPath: iconURL.path),
			   let symbol = NSImage(
				systemSymbolName: "app.fill",
				accessibilityDescription: nil
			   ),
			   let tiffData = symbol.tiffRepresentation,
			   let rep = NSBitmapImageRep(data: tiffData),
			   let pngData = rep.representation(using: .png, properties: [:]) {
				try? pngData.write(to: iconURL)
			}
		}
		return iconURL
		#else
		return nil
		#endif
	}
}

extension DownloadQueueViewModel.PreviewState {
	var defaultTab: QueuePanelContent<AnyView, AnyView>.Tab {
		switch self {
		case .completed:
			return .results
		default:
			return .queue
		}
	}
}

struct DownloadResultItem: Identifiable {
	let id: String
	let name: String
	let message: String
	let isSuccess: Bool
	let iconFilePath: String?
}

struct EditableDownload: Identifiable {
	let id: String
	var displayName: String
	let baseDownload: SuccessfulDownload
	let iconPaths: [URL]
	var selectedIconIndex: Int
	var parsedMetadata: ParsedMetadata?
	var metadataText: String
	var metadataError: String?
	var preparationError: String?
	var recipeIdentifier: String?
	var recipeText: String?
	var recipeError: String?
	var parsedRecipe: Recipe?
	var preinstallScript: String
	var postinstallScript: String
	var preuninstallScript: String
	var postuninstallScript: String
	var installcheckScript: String
	var uninstallcheckScript: String?

	static func resolvedDisplayName(
		metadata: ParsedMetadata?,
		fallbackName: String?,
		fileName: String
	) -> String {
		if let value = metadata?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
			return value
		}
		if let value = metadata?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
			return value
		}
		if let value = fallbackName?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
			return value
		}
		return fileName
	}

	static func from(output: DownloadUploadService.DownloadOutput) -> EditableDownload {
		let download = output.successfulDownload
		let appName = resolvedDisplayName(
			metadata: download.parsedMetadata,
			fallbackName: download.macApplication?.name.first,
			fileName: download.fileName
		)
		let outputFolder = URL(fileURLWithPath: download.fullFolderPath)
			.appendingPathComponent("output", isDirectory: true)
		let iconFiles = (try? FileManager.default.contentsOfDirectory(
			at: outputFolder,
			includingPropertiesForKeys: nil
		)) ?? []
		let pngFiles = iconFiles.filter { $0.pathExtension.lowercased() == "png" }
		let metadata = download.parsedMetadata
		let metadataText = encodeMetadata(metadata)
		return EditableDownload(
			id: download.guid.uuidString,
			displayName: appName,
			baseDownload: download,
			iconPaths: pngFiles,
			selectedIconIndex: 0,
			parsedMetadata: metadata,
			metadataText: metadataText,
			metadataError: nil,
			preparationError: nil,
			recipeIdentifier: nil,
			recipeText: nil,
			recipeError: nil,
			parsedRecipe: nil,
			preinstallScript: metadata?.preinstall_script ?? "",
			postinstallScript: metadata?.postinstall_script ?? "",
			preuninstallScript: metadata?.preuninstall_script ?? "",
			postuninstallScript: metadata?.postuninstall_script ?? "",
			installcheckScript: metadata?.installcheck_script ?? "",
			uninstallcheckScript: metadata?.uninstallcheck_script
		)
	}

	static func fromFallback(
		download: SuccessfulDownload,
		error: String
	) -> EditableDownload {
		let appName = resolvedDisplayName(
			metadata: download.parsedMetadata,
			fallbackName: download.macApplication?.name.first,
			fileName: download.fileName
		)
		let outputFolder = URL(fileURLWithPath: download.fullFolderPath)
			.appendingPathComponent("output", isDirectory: true)
		let iconFiles = (try? FileManager.default.contentsOfDirectory(
			at: outputFolder,
			includingPropertiesForKeys: nil
		)) ?? []
		let pngFiles = iconFiles.filter { $0.pathExtension.lowercased() == "png" }
		return EditableDownload(
			id: download.guid.uuidString,
			displayName: appName,
			baseDownload: download,
			iconPaths: pngFiles,
			selectedIconIndex: 0,
			parsedMetadata: nil,
			metadataText: "{}",
			metadataError: "Metadata not generated",
			preparationError: error,
			recipeIdentifier: nil,
			recipeText: nil,
			recipeError: nil,
			parsedRecipe: nil,
			preinstallScript: "",
			postinstallScript: "",
			preuninstallScript: "",
			postuninstallScript: "",
			installcheckScript: "",
			uninstallcheckScript: nil
		)
	}

	static func encodeMetadata(_ metadata: ParsedMetadata?) -> String {
		guard let metadata else { return "{}" }
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		guard let data = try? encoder.encode(metadata) else { return "{}" }
		return String(data: data, encoding: .utf8) ?? "{}"
	}

	static func encodeRecipe(_ recipe: Recipe?) -> String {
		guard let recipe else { return "{}" }
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		guard let data = try? encoder.encode(recipe) else { return "{}" }
		return String(data: data, encoding: .utf8) ?? "{}"
	}

	mutating func syncScripts(from metadata: ParsedMetadata) {
		preinstallScript = metadata.preinstall_script ?? ""
		postinstallScript = metadata.postinstall_script ?? ""
		preuninstallScript = metadata.preuninstall_script ?? ""
		postuninstallScript = metadata.postuninstall_script ?? ""
		installcheckScript = metadata.installcheck_script ?? ""
		uninstallcheckScript = metadata.uninstallcheck_script
	}

	func withRecipe(recipeId: String, recipe: Recipe) -> EditableDownload {
		var updated = self
		updated.recipeIdentifier = recipeId
		updated.parsedRecipe = recipe
		updated.recipeText = EditableDownload.encodeRecipe(recipe)
		updated.recipeError = nil
		return updated
	}

	func toSuccessfulDownload() -> SuccessfulDownload {
		var updated = baseDownload
		if iconPaths.indices.contains(selectedIconIndex) {
			let iconPath = iconPaths[selectedIconIndex].path
			updated.selectedIconPath = iconPath
			updated.munkiMetadata?.iconFile = iconPath
		}
		updated.parsedMetadata = parsedMetadata
		return updated
	}
}
