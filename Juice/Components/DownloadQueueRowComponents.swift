import SwiftUI
#if os(macOS)
import AppKit
#endif

// Consolidated row/detail views for download queue stages and results.
// Used by: DownloadQueuePanelContent.

struct DownloadQueueStatusHeader: View {
	let statusText: String
	let stageProgressText: String

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(statusText)
					.font(.system(size: 14, weight: .semibold))
				Spacer()
				if !stageProgressText.isEmpty {
					Text(stageProgressText)
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(.secondary)
				}
			}
		}
		.padding(.horizontal, 4)
	}
}

// MARK: - Review Rows

struct DownloadEditReviewList: View {
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

struct DownloadReviewRow: View {
	@Environment(\.colorScheme) private var colorScheme
	let download: EditableDownload
	let onEdit: () -> Void

	private var glassState: GlassStateContext {
		GlassStateContext(colorScheme: colorScheme, isFocused: true)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top, spacing: 10) {
				ReviewItemIcon(download: download)
					.frame(width: 34, height: 34)
				VStack(alignment: .leading, spacing: 4) {
					Text(download.displayName)
						.font(.system(size: 14, weight: .semibold))
						.lineLimit(1)
					if let version = download.parsedMetadata?.version {
						Text("Version \(version)")
							.font(.system(size: 11, weight: .medium))
							.foregroundStyle(.secondary)
					}
					Text("Downloaded")
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.secondary)
					if download.recipeIdentifier != nil {
						Pill("Recipe", color: .orange)
					}
				}
					Spacer()
					if #available(macOS 26.0, iOS 26.0, *) {
						Button("Edit") {
							onEdit()
						}
						.buttonStyle(.glass)
						.controlSize(.small)
						.buttonBorderShape(.capsule)
					} else {
						Button("Edit") {
							onEdit()
						}
						.nativeActionButtonStyle(.secondary, controlSize: .small)
						.buttonBorderShape(.capsule)
					}
				}
			}
		.padding(8)
		.glassCompatSurface(
			in: shape,
			style: .regular,
			context: glassState,
			fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
			fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
			surfaceOpacity: 1
		)
		.clipShape(shape)
		.glassCompatBorder(in: shape, context: glassState, role: .standard, lineWidth: 0.8)
	}
}

struct ReviewItemIcon: View {
	let download: EditableDownload

	var body: some View {
		#if os(macOS)
		if let firstIcon = download.iconPaths.first,
		   let image = NSImage(contentsOf: firstIcon) {
			Image(nsImage: image)
				.resizable()
				.scaledToFit()
		} else {
			IconByFiletype(
				applicationFileName: download.baseDownload.macApplication?.url
					?? download.baseDownload.fileName
			)
		}
		#else
		IconByFiletype(
			applicationFileName: download.baseDownload.macApplication?.url
				?? download.baseDownload.fileName
		)
		#endif
	}
}

struct MetadataEditRow: View {
	@Environment(\.colorScheme) private var colorScheme
	@Binding var download: EditableDownload
	let onMetadataChange: (String) -> Void
	let onSelectIcon: (Int) -> Void
	let onRecipeChange: (String) -> Void
	let onScriptChange: (DownloadQueueViewModel.ScriptField, String) -> Void
	@State private var showMetadata: Bool
	@State private var showRecipe: Bool
	@State private var showScripts: Bool

	private var glassState: GlassStateContext {
		GlassStateContext(colorScheme: colorScheme, isFocused: true)
	}

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
								.strokeBorder(
									GlassThemeTokens.borderColor(
										for: glassState,
										role: .standard
									)
								)
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
							.strokeBorder(
								GlassThemeTokens.borderColor(
									for: glassState,
									role: .standard
								)
							)
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
				.fill(GlassThemeTokens.overlayColor(for: glassState, role: .subtle))
		)
	}

	private func scriptEditor(
		title: String,
		text: Binding<String>,
		onChange: @escaping (String) -> Void
	) -> some View {
		// Shared editor chrome keeps all script blocks visually consistent.
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
					.strokeBorder(
						GlassThemeTokens.borderColor(
							for: glassState,
							role: .standard
						)
					)
			)
		}
	}
}

struct IconPickerButton: View {
	@Environment(\.colorScheme) private var colorScheme
	let iconURL: URL
	let isSelected: Bool
	let action: () -> Void

	private var glassState: GlassStateContext {
		GlassStateContext(colorScheme: colorScheme, isFocused: true)
	}

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
					.fill(
						isSelected
							? GlassThemeTokens.selectedChipFill(for: glassState)
							: GlassThemeTokens.unselectedChipFill(for: glassState)
					)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.strokeBorder(
						isSelected
							? GlassThemeTokens.selectedChipBorder(for: glassState)
							: GlassThemeTokens.unselectedChipBorder(for: glassState)
					)
			)
	}
}

// MARK: - Queue/Result Rows

struct DownloadQueueRow: View {
	@Environment(\.colorScheme) private var colorScheme
	@ObservedObject var app: CaskApplication
	let uploadStatus: UploadProgress?

	private var glassState: GlassStateContext {
		GlassStateContext(colorScheme: colorScheme, isFocused: true)
	}

	var body: some View {
		let progress = app.downloadProgress
		let isWaiting = (progress.currentState ?? "").localizedCaseInsensitiveContains("waiting")
		let statusText = uploadStatus?.uploadProgressString ?? progress.currentState ?? "Waiting..."
		HStack(spacing: 10) {
			QueueItemIcon(
				iconFilePath: progress.iconFilePath,
				fallbackFileName: app.url
			)
			.frame(width: 28, height: 28)
			VStack(alignment: .leading, spacing: 3) {
				Text(app.name.first ?? app.token)
					.font(.system(size: 13, weight: .semibold))
				Text(statusText)
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
				Spacer()
				if let uploadStatus {
					if uploadStatus.appExists {
						Image(systemName: "exclamationmark.triangle.fill")
							.font(.system(size: 13, weight: .semibold))
							.foregroundStyle(.yellow)
					} else if uploadStatus.inProgress {
						let isInstallerUpload = uploadStatus.uploadProgressString
							.localizedCaseInsensitiveContains("uploading installer")
						if isInstallerUpload {
							let percent = min(max(uploadStatus.uploadPercent, 0), 100)
							VStack(alignment: .trailing, spacing: 2) {
								Text("\(percent)%")
									.font(.system(size: 10, weight: .semibold))
									.foregroundStyle(.secondary)
								ProgressView(value: Double(percent), total: 100)
									.controlSize(.small)
									.frame(width: 90)
									.animation(.linear(duration: 0.2), value: percent)
							}
						} else {
							ProgressView()
								.controlSize(.small)
						}
					} else if uploadStatus.isComplete {
						Image(systemName: uploadStatus.isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
							.font(.system(size: 13, weight: .semibold))
							.foregroundStyle(uploadStatus.isSuccess ? .green : .red)
					}
			} else if progress.isComplete {
				Image(systemName: progress.isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(progress.isSuccess ? .green : .red)
			} else if !isWaiting {
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
			.glassCompatSurface(
				in: RoundedRectangle(cornerRadius: 8, style: .continuous),
				style: .regular,
				context: glassState,
				fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
				fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
				surfaceOpacity: 1
			)
			.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
			.glassCompatBorder(
				in: RoundedRectangle(cornerRadius: 8, style: .continuous),
				context: glassState,
				role: .standard,
				lineWidth: 0.8
			)
		}
}

struct QueueItemIcon: View {
	let iconFilePath: String?
	let fallbackFileName: String

	var body: some View {
		#if os(macOS)
		if let iconFilePath,
		   let image = NSImage(contentsOf: URL(fileURLWithPath: iconFilePath)) {
			Image(nsImage: image)
				.resizable()
				.scaledToFit()
		} else {
			IconByFiletype(applicationFileName: fallbackFileName)
		}
		#else
		IconByFiletype(applicationFileName: fallbackFileName)
		#endif
	}
}

struct DownloadResultRow: View {
	@Environment(\.colorScheme) private var colorScheme
	let result: DownloadResultItem

	private var glassState: GlassStateContext {
		GlassStateContext(colorScheme: colorScheme, isFocused: true)
	}

	var body: some View {
		HStack(spacing: 10) {
			QueueItemIcon(
				iconFilePath: result.iconFilePath,
				fallbackFileName: "unknown.filetype"
			)
			.frame(width: 28, height: 28)
			VStack(alignment: .leading, spacing: 3) {
				Text(result.name)
					.font(.system(size: 13, weight: .semibold))
				Text(result.message)
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}
			Spacer()
			Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(result.isSuccess ? .green : .red)
		}
			.padding(8)
			.glassCompatSurface(
				in: RoundedRectangle(cornerRadius: 8, style: .continuous),
				style: .regular,
				context: glassState,
				fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
				fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
				surfaceOpacity: 1
			)
			.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
			.glassCompatBorder(
				in: RoundedRectangle(cornerRadius: 8, style: .continuous),
				context: glassState,
				role: .standard,
				lineWidth: 0.8
			)
		}
}

struct DownloadQueuePanelContent_PreviewHost: View {
	let state: DownloadQueueViewModel.PreviewState
	@StateObject private var model: DownloadQueueViewModel
	@State private var tab: QueuePanelContent<AnyView, AnyView>.Tab

	init(state: DownloadQueueViewModel.PreviewState) {
		self.state = state
		_model = StateObject(wrappedValue: DownloadQueueViewModel.previewModel(state))
		_tab = State(initialValue: state.defaultTab)
	}

	var body: some View {
		ZStack {
			JuiceGradient()
				.ignoresSafeArea()
			DownloadQueuePanelContent(
				model: model,
				tab: $tab,
				panelMinHeight: 600
			)
			.environmentObject(InspectorCoordinator())
			.frame(width: 350, height: 720)
		}
	}
}

#Preview("DownloadQueuePanelContent - Idle") {
	DownloadQueuePanelContent_PreviewHost(state: .idle)
}

#Preview("DownloadQueuePanelContent - Downloading") {
	DownloadQueuePanelContent_PreviewHost(state: .downloading)
}

#Preview("DownloadQueuePanelContent - Editing") {
	DownloadQueuePanelContent_PreviewHost(state: .editing)
}

#Preview("DownloadQueuePanelContent - Uploading") {
	DownloadQueuePanelContent_PreviewHost(state: .uploading)
}

#Preview("DownloadQueuePanelContent - Completed") {
	DownloadQueuePanelContent_PreviewHost(state: .completed)
}

#Preview("DownloadQueuePanelContent - Cancelled") {
	DownloadQueuePanelContent_PreviewHost(state: .cancelled)
}

#Preview("DownloadQueueRow") {
	let app = CaskApplication(
		token: "slack",
		fullToken: "slack",
		name: ["Slack"],
		desc: "Team communication",
		url: "https://example.com/Slack.dmg",
		version: "4.46.104"
	)
	app.downloadProgress.currentState = "Downloaded - ready to edit"
	return ZStack {
		JuiceGradient()
			.ignoresSafeArea()
		DownloadQueueRow(app: app, uploadStatus: nil)
			.frame(width: 420)
	}
}

#Preview("DownloadReviewRow") {
	let download = EditableDownload(
		id: UUID().uuidString,
		displayName: "Slack",
		baseDownload: SuccessfulDownload(
			fileName: "Slack.dmg",
			fileExtension: "dmg",
			fullFilePath: "/Users/pete/Juice/slack/4.46.104/Slack.dmg",
			fullFolderPath: "/Users/pete/Juice/slack/4.46.104"
		),
		iconPaths: [],
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
	return ZStack {
		JuiceGradient()
			.ignoresSafeArea()
		DownloadReviewRow(download: download) {}
			.frame(width: 440)
	}
}

#Preview("DownloadResultRow") {
	let result = DownloadResultItem(
		id: UUID().uuidString,
		name: "Slack",
		message: "App Added Successfully",
		isSuccess: true,
		iconFilePath: DownloadQueueViewModel.previewModel(.completed)
			.results
			.first?
			.iconFilePath
	)
	return ZStack {
		JuiceGradient()
			.ignoresSafeArea()
		DownloadResultRow(result: result)
			.frame(width: 420)
	}
}
