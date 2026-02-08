import SwiftUI
#if os(macOS)
import AppKit
#endif
import os

struct DownloadQueuePanelContent: View {
	@ObservedObject var model: DownloadQueueViewModel
	@Binding var tab: QueuePanelContent<AnyView, AnyView>.Tab
	let panelMinHeight: CGFloat
	@State private var selectedEditable: EditableDownload?

	var body: some View {
		let isEditing = model.stage == .editing
		QueuePanelContent(
			tab: $tab,
			queueTitle: "Processing Queue",
			resultsTitle: "Results",
			queueCountText: model.queueCountText,
			resultsCountText: model.resultsCountText,
			queueIsEmpty: isEditing ? !model.hasEditableDownloads : model.queueItems.isEmpty,
			resultsIsEmpty: model.results.isEmpty,
			queueActionTitle: isEditing ? "Continue" : (model.isRunning ? "Cancel All" : "Clear"),
			resultsActionTitle: "Clear",
			onQueueAction: {
				if isEditing {
					model.startUploadAfterEdits()
				} else if model.isRunning {
					model.cancel()
				} else {
					model.clearQueue()
				}
			},
			onResultsAction: {
				model.clearResults()
			},
			bottomActions: nil
		) {
			AnyView(
				VStack(alignment: .leading, spacing: 12) {
					DownloadQueueStatusHeader(
						statusText: model.statusText,
						stageText: model.stageText,
						progressText: model.progressText
					)
					if isEditing {
						DownloadEditReviewList(
							model: model,
							onEdit: { id in
								if let match = model.editableDownloads.first(where: { $0.id == id }) {
									selectedEditable = match
								}
							}
						)
					} else {
						LazyVStack(spacing: 8) {
							ForEach(model.queueItems) { item in
								DownloadQueueRow(
									app: item,
									uploadStatus: model.uploadStatus(for: item)
								)
								.transition(.opacity.combined(with: .move(edge: .top)))
							}
						}
					}
				}
			)
		} resultsContent: {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(model.results) { result in
						DownloadResultRow(result: result)
							.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
			)
		}
		.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
		.frame(width: 400, alignment: .center)
		.frame(maxWidth: .infinity, alignment: .trailing)
		.onAppear {
			model.startIfNeeded()
		}
		.onChange(of: model.stage) { _, newStage in
			if newStage == .editing {
				tab = .queue
			}
		}
		.sheet(item: $selectedEditable) { editable in
			MetadataEditSheet(
				download: editable,
				onSave: { updated in
					model.updateEditedDownload(updated)
					selectedEditable = nil
				},
				onCancel: {
					selectedEditable = nil
				}
			)
		}
	}
}

@MainActor
final class DownloadQueueViewModel: ObservableObject {
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "JuiceSwift", category: "DownloadQueue")
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
		return processed == 1 ? "1 result" : "\(processed) results"
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

	var progressText: String {
		guard totalCount > 0 else { return "0 / 0" }
		return "\(completedCount) / \(totalCount)"
	}

	var shouldPresentPanel: Bool {
		switch stage {
		case .downloading, .editing, .uploading:
			return true
		case .idle, .completed, .cancelled:
			return false
		}
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
			print("[DownloadQueue] Duplicate recipe identifiers found: \(unique.joined(separator: ", "))")
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
		cancelRequested = true
		stage = .cancelled
		statusText = "Cancelling..."
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
			editableDownloads[index].metadataError = nil
			editableDownloads[index].syncScripts(from: parsed)
		} else {
			editableDownloads[index].metadataError = "Invalid metadata JSON."
			Self.logger.error("Metadata JSON parse failed for \(self.editableDownloads[index].displayName, privacy: .public)")
			print("[DownloadQueue] Metadata JSON parse failed for \(self.editableDownloads[index].displayName)")
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
			print("[DownloadQueue] Recipe JSON parse failed for \(self.editableDownloads[index].displayName)")
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
		statusText = "Preparing upload..."
		isRunning = true
		Task { await uploadEditedDownloads() }
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

	private func run() async {
		statusText = "Starting..."
		stage = .downloading
		let pending = queueItems
		let _: [UemApplication] =
			(mode == .upload || mode == .uploadOnly)
			? await UEMService.instance.getAllApps().compactMap { $0 }
			: []

		for app in pending {
			if cancelRequested { break }
			currentAppName = app.name.first ?? app.token
			statusText = "Downloading \(currentAppName)"
			stage = .downloading

			do {
				let output = try await DownloadUploadService.downloadAndPrepare(
					app,
					mode: mode,
					shouldCancel: { [weak self] in
						self?.cancelRequested ?? false
					}
				)
				var editable = EditableDownload.from(output: output)
				if let recipeId = app.matchingRecipeId {
					editable.recipeIdentifier = recipeId
					if let recipe = recipesById[recipeId] {
						editable = editable.withRecipe(recipeId: recipeId, recipe: recipe)
					}
				}
				editableDownloads.append(editable)
				if mode == .upload || mode == .uploadOnly {
					app.downloadProgress.currentState = "Downloaded - ready to edit"
				}

				if cancelRequested { break }

				if mode == .download {
					successCount += 1
					appendResult(
						name: currentAppName,
						message: "App Downloaded Successfully",
						isSuccess: true
					)
				}
			} catch {
				let errorMessage = error.localizedDescription
				app.downloadProgress.isComplete = true
				app.downloadProgress.inProgress = false
				app.downloadProgress.isSuccess = false
				app.downloadProgress.currentState = "Failed"

				if mode == .upload || mode == .uploadOnly {
					if let fallback = try? DownloadUploadService.minimalSuccessfulDownload(app: app) {
						var editable = EditableDownload.fromFallback(
							download: fallback,
							error: errorMessage
						)
						Self.logger.error("Preparation error for \(editable.displayName, privacy: .public): \(errorMessage, privacy: .public)")
						print("[DownloadQueue] Preparation error for \(editable.displayName): \(errorMessage)")
						if let recipeId = app.matchingRecipeId {
							editable.recipeIdentifier = recipeId
							if let recipe = recipesById[recipeId] {
								editable = editable.withRecipe(recipeId: recipeId, recipe: recipe)
							}
						}
						editableDownloads.append(editable)
						app.downloadProgress.currentState = "Downloaded - needs attention"
					}
				} else {
					errorCount += 1
					appendResult(
						name: currentAppName,
						message: "App Download Failed: \(errorMessage)",
						isSuccess: false
					)
				}
			}

			completedCount += 1
			if mode == .download {
				queueItems.removeAll { $0.id == app.id }
			}
		}

		if cancelRequested {
			stage = .cancelled
			statusText = "Cancelled"
			isRunning = false
			return
		}

		if mode == .upload || mode == .uploadOnly {
			stage = .editing
			statusText = editableDownloads.isEmpty
				? "No items ready to edit."
				: "Review icons and metadata before upload"
			isRunning = false
			return
		}

		stage = .completed
		statusText = "Finished"
		isRunning = false
	}

	private func uploadEditedDownloads() async {
		let currentUemApps: [UemApplication] =
			(mode == .upload || mode == .uploadOnly)
			? await UEMService.instance.getAllApps().compactMap { $0 }
			: []

		for editable in editableDownloads {
			if cancelRequested { break }
			let appName = editable.displayName
			statusText = "Uploading \(appName)"

			let prepared = preparedDownload(from: editable)
			if let parsed = prepared.parsedMetadata {
				try? DownloadUploadService.writeInstallerPlist(
					for: prepared,
					parsedMetadata: parsed
				)
			}
			let exists = await UEMService.instance.checkForExistingApp(
				currentUemApps,
				successfulDownload: prepared
			)
			if exists {
				errorCount += 1
				appendResult(
					name: appName,
					message: "App Version Already Exists in UEM",
					isSuccess: false
				)
				continue
			}

			updateUploadStatus(prepared.macApplication, inProgress: true, status: "Uploading...")
			do {
				let uploadOK = try await DownloadUploadService.uploadSuccessfulDownload(
					prepared,
					shouldCancel: { [weak self] in
						self?.cancelRequested ?? false
					}
				)
				if uploadOK {
					successCount += 1
					updateUploadStatus(prepared.macApplication, inProgress: false, status: "Upload complete", isSuccess: true)
					appendResult(
						name: appName,
						message: "App Added Successfully",
						isSuccess: true
					)
				} else {
					errorCount += 1
					updateUploadStatus(prepared.macApplication, inProgress: false, status: "Upload failed", isSuccess: false)
					appendResult(
						name: appName,
						message: "App Upload Failed",
						isSuccess: false
					)
				}
			} catch {
				errorCount += 1
				appendResult(
					name: appName,
					message: "App Upload Failed",
					isSuccess: false
				)
			}
		}

		stage = cancelRequested ? .cancelled : .completed
		statusText = cancelRequested ? "Cancelled" : "Finished"
		isRunning = false
	}

	private func appendResult(name: String, message: String, isSuccess: Bool) {
		let result = DownloadResultItem(
			id: UUID().uuidString,
			name: name,
			message: message,
			isSuccess: isSuccess
		)
		results.append(result)
	}

	private func updateUploadStatus(
		_ app: CaskApplication?,
		inProgress: Bool,
		status: String,
		isSuccess: Bool? = nil
	) {
		guard let app else { return }
		var progress = uploadProgress[app.id] ?? UploadProgress()
		progress.inProgress = inProgress
		progress.isComplete = !inProgress
		if let isSuccess {
			progress.isSuccess = isSuccess
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

struct DownloadResultItem: Identifiable {
	let id: String
	let name: String
	let message: String
	let isSuccess: Bool
}

struct EditableDownload: Identifiable {
	let id: String
	let displayName: String
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

	static func from(output: DownloadUploadService.DownloadOutput) -> EditableDownload {
		let download = output.successfulDownload
		let appName = download.parsedMetadata?.name
			?? download.macApplication?.name.first
			?? download.fileName
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
		let appName = download.macApplication?.name.first ?? download.fileName
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

private struct DownloadQueueStatusHeader: View {
	let statusText: String
	let stageText: String
	let progressText: String

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(statusText)
				.font(.system(size: 14, weight: .semibold))
			HStack(spacing: 8) {
				Text(stageText)
					.font(.caption)
					.foregroundStyle(.secondary)
				Text(progressText)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, 4)
	}
}

private struct DownloadEditReviewList: View {
	@ObservedObject var model: DownloadQueueViewModel
	let onEdit: (String) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Review downloaded apps, then edit metadata and icons before uploading.")
				.font(.system(size: 12))
				.foregroundStyle(.secondary)
			LazyVStack(spacing: 12) {
				ForEach(model.editableDownloads) { download in
					DownloadReviewRow(download: download) {
						onEdit(download.id)
					}
				}
			}
		}
	}
}

private struct DownloadReviewRow: View {
	let download: EditableDownload
	let onEdit: () -> Void

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top, spacing: 10) {
				IconByFiletype(applicationFileName: download.baseDownload.macApplication?.url ?? download.baseDownload.fileName)
					.frame(width: 34, height: 34)
				VStack(alignment: .leading, spacing: 4) {
					Text(download.displayName)
						.font(.system(size: 14, weight: .semibold))
						.lineLimit(1)
					Text("Downloaded - ready to edit")
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.secondary)
					if let version = download.parsedMetadata?.version {
						Text("Version \(version)")
							.font(.system(size: 11, weight: .medium))
							.foregroundStyle(.secondary)
					}
				}
				Spacer()
				JuiceButtons.secondary("Edit") {
					onEdit()
				}
				.controlSize(.small)
			}
		}
		.padding(12)
		.background(
			Group {
				if #available(macOS 26.0, iOS 26.0, *) {
					GlassEffectContainer {
						shape
							.fill(Color.white.opacity(0.04))
							.glassEffect(.regular, in: shape)
					}
				} else {
					shape.fill(.ultraThinMaterial)
				}
			}
		)
		.clipShape(shape)
		.overlay(shape.strokeBorder(Color.white.opacity(0.08)))
	}
}

private struct MetadataEditRow: View {
	@Binding var download: EditableDownload
	let onMetadataChange: (String) -> Void
	let onSelectIcon: (Int) -> Void
	let onRecipeChange: (String) -> Void
	let onScriptChange: (DownloadQueueViewModel.ScriptField, String) -> Void
	@State private var showMetadata: Bool
	@State private var showRecipe: Bool
	@State private var showScripts: Bool

	init(
		download: Binding<EditableDownload>,
		onMetadataChange: @escaping (String) -> Void,
		onSelectIcon: @escaping (Int) -> Void,
		onRecipeChange: @escaping (String) -> Void,
		onScriptChange: @escaping (DownloadQueueViewModel.ScriptField, String) -> Void
	) {
		self._download = download
		self.onMetadataChange = onMetadataChange
		self.onSelectIcon = onSelectIcon
		self.onRecipeChange = onRecipeChange
		self.onScriptChange = onScriptChange
		self._showMetadata = State(initialValue: true)
		self._showRecipe = State(initialValue: download.wrappedValue.recipeIdentifier != nil)
		self._showScripts = State(initialValue: false)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				VStack(alignment: .leading, spacing: 2) {
					Text(download.displayName)
						.font(.system(size: 13, weight: .semibold))
					Text("Downloaded - ready to edit")
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.secondary)
				}
				Spacer()
				Button(showMetadata ? "Hide Metadata" : "Edit Metadata") {
					withAnimation(.easeInOut(duration: 0.15)) {
						showMetadata.toggle()
					}
				}
				.buttonStyle(.plain)
				.font(.system(size: 11, weight: .semibold))
				if download.recipeIdentifier != nil || download.recipeText != nil {
					Button(showRecipe ? "Hide Recipe" : "Edit Recipe") {
						withAnimation(.easeInOut(duration: 0.15)) {
							showRecipe.toggle()
						}
					}
					.buttonStyle(.plain)
					.font(.system(size: 11, weight: .semibold))
				}
				Button(showScripts ? "Hide Scripts" : "Edit Scripts") {
					withAnimation(.easeInOut(duration: 0.15)) {
						showScripts.toggle()
					}
				}
				.buttonStyle(.plain)
				.font(.system(size: 11, weight: .semibold))
			}

			if !download.iconPaths.isEmpty {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(download.iconPaths.indices, id: \.self) { index in
							IconPickerButton(
								iconURL: download.iconPaths[index],
								isSelected: index == download.selectedIconIndex
							) {
								download.selectedIconIndex = index
								onSelectIcon(index)
							}
						}
					}
				}
			} else {
				Text("No icons were extracted.")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}

			if download.recipeIdentifier != nil && download.recipeText == nil {
				Text("Recipe not found for this app.")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}

			if showMetadata {
				TextEditor(text: $download.metadataText)
					.font(.system(.caption, design: .monospaced))
					.frame(minHeight: 120)
					.onChange(of: download.metadataText) { _, newValue in
						onMetadataChange(newValue)
					}
					.overlay(
						RoundedRectangle(cornerRadius: 6, style: .continuous)
							.strokeBorder(Color.white.opacity(0.12))
					)
					if let prepError = download.preparationError {
						Text(prepError)
							.font(.system(size: 11, weight: .semibold))
							.foregroundStyle(.red)
					}
				if let error = download.metadataError {
					Text(error)
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.red)
				}
			}

			if showRecipe, download.recipeText != nil {
				TextEditor(text: Binding(
					get: { download.recipeText ?? "" },
					set: { newValue in
						download.recipeText = newValue
						onRecipeChange(newValue)
					}
				))
				.font(.system(.caption, design: .monospaced))
				.frame(minHeight: 120)
				.overlay(
					RoundedRectangle(cornerRadius: 6, style: .continuous)
						.strokeBorder(Color.white.opacity(0.12))
				)
				if let error = download.recipeError {
					Text(error)
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.red)
				}
			}

			if showRecipe, download.recipeText == nil, download.recipeIdentifier != nil {
				Text("No recipe metadata was found for this app.")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}

			if showScripts {
				scriptEditor(
					title: "Preinstall Script",
					text: $download.preinstallScript
				) { newValue in
					onScriptChange(.preinstall, newValue)
				}
				scriptEditor(
					title: "Postinstall Script",
					text: $download.postinstallScript
				) { newValue in
					onScriptChange(.postinstall, newValue)
				}
				scriptEditor(
					title: "Preuninstall Script",
					text: $download.preuninstallScript
				) { newValue in
					onScriptChange(.preuninstall, newValue)
				}
				scriptEditor(
					title: "Postuninstall Script",
					text: $download.postuninstallScript
				) { newValue in
					onScriptChange(.postuninstall, newValue)
				}
				scriptEditor(
					title: "Installcheck Script",
					text: $download.installcheckScript
				) { newValue in
					onScriptChange(.installcheck, newValue)
				}
				scriptEditor(
					title: "Uninstallcheck Script",
					text: Binding(
						get: { download.uninstallcheckScript ?? "" },
						set: { download.uninstallcheckScript = $0 }
					)
				) { newValue in
					onScriptChange(.uninstallcheck, newValue)
				}
			}
		}
		.padding(10)
		.background(
			RoundedRectangle(cornerRadius: 10, style: .continuous)
				.fill(Color.white.opacity(0.04))
		)
	}

	private func scriptEditor(
		title: String,
		text: Binding<String>,
		onChange: @escaping (String) -> Void
	) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title)
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.secondary)
			TextEditor(text: text)
				.onChange(of: text.wrappedValue) { _, newValue in
					onChange(newValue)
				}
			.font(.system(.caption, design: .monospaced))
			.frame(minHeight: 80)
			.overlay(
				RoundedRectangle(cornerRadius: 6, style: .continuous)
					.strokeBorder(Color.white.opacity(0.12))
			)
		}
	}
}

private struct IconPickerButton: View {
	let iconURL: URL
	let isSelected: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			#if os(macOS)
			if let image = NSImage(contentsOf: iconURL) {
				Image(nsImage: image)
					.resizable()
					.scaledToFit()
					.frame(width: 34, height: 34)
					.padding(6)
			} else {
				Color.clear
					.frame(width: 34, height: 34)
					.padding(6)
			}
			#else
			Color.clear
				.frame(width: 34, height: 34)
				.padding(6)
			#endif
		}
		.buttonStyle(.plain)
		.background(
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.fill(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.12))
		)
	}
}

private struct DownloadQueueRow: View {
	@ObservedObject var app: CaskApplication
	let uploadStatus: UploadProgress?

	var body: some View {
		let progress = app.downloadProgress
		HStack(spacing: 10) {
			IconByFiletype(applicationFileName: app.url)
				.frame(width: 28, height: 28)
			VStack(alignment: .leading, spacing: 3) {
				Text(app.name.first ?? app.token)
					.font(.system(size: 13, weight: .semibold))
				Text(progress.currentState ?? "Waiting...")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
					.lineLimit(1)
				if let uploadStatus {
					Text(uploadStatus.uploadProgressString)
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
			}
			Spacer()
			if progress.isComplete {
				Image(systemName: progress.isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(progress.isSuccess ? .green : .red)
			} else {
				if progress.isIndeterminate == true {
					ProgressView()
						.controlSize(.small)
				} else {
					ProgressView(value: Double(progress.downloadPercent ?? 0), total: 100)
						.controlSize(.small)
						.frame(width: 90)
						.animation(.linear(duration: 0.2), value: progress.downloadPercent ?? 0)
				}
			}
		}
		.padding(8)
		.background(
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.fill(Color.white.opacity(0.04))
		)
	}
}

private struct DownloadResultRow: View {
	let result: DownloadResultItem

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(result.isSuccess ? .green : .red)
			VStack(alignment: .leading, spacing: 3) {
				Text(result.name)
					.font(.system(size: 13, weight: .semibold))
				Text(result.message)
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}
			Spacer()
		}
		.padding(8)
		.background(
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.fill(Color.white.opacity(0.04))
		)
	}
}
