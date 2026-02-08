import SwiftUI

#if os(macOS)
	import AppKit
#endif

// Import workflow page.
// Layout ownership:
// - Left panel: file scanning, selection, and import cards.
// - Inspector panel: queue/results/details via InspectorCoordinator.
// - Bottom actions: upload/remove/clear flows.
struct ImportView: View {
	// MARK: - Inputs & Environment

	let model: PageViewData
	@EnvironmentObject private var inspector: InspectorCoordinator
	@EnvironmentObject private var catalog: LocalCatalog
	@Environment(\.colorScheme) private var colorScheme

	// MARK: - View State

	@State private var rightTab: QueuePanelContent<AnyView, AnyView>.Tab =
		.queue
	@State private var queueItems: [ImportedApplication] = []
	@State private var resultsItems: [ImportedApplication] = []
	@State private var importApps: [ImportedApplication] = []
	@State private var selectedApp: ImportedApplication?
	@State private var selectedAppIds: Set<UUID> = []
	@State private var isScanning = false
	@State private var selectedFolderURL: URL?
	@State private var suppressQueueAutoShow = false
	@State private var showingDetails = false
	@State private var confirmationVisible = false
	@State private var confirmationMode: ConfirmationActionMode = .upload
	private let basePanelMinHeight: CGFloat = 680
	private let bottomBarHeight: CGFloat = 88
	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
	}
	private var panelGlassOpacity: CGFloat {
		GlassThemeTokens.panelSurfaceOpacity(for: glassState)
	}
	@StateObject private var focusObserver = WindowFocusObserver()
	@State private var panelMinHeightCache: CGFloat = 0

	@State private var expandActionsTrigger: Int = 0

	private var glassBaseOpacity: CGFloat {
		GlassThemeTokens.panelBaseTintOpacity(for: glassState)
	}

	private var panelBaseTintColor: Color {
		GlassThemeTokens.controlBackgroundBase(for: glassState)
	}

	private var panelBorderColor: Color {
		GlassThemeTokens.borderColor(for: glassState, role: .standard)
	}

	private var panelNeutralOverlayOpacity: CGFloat {
		GlassThemeTokens.panelNeutralOverlayOpacity(for: glassState)
	}

	// MARK: - Body

	var body: some View {
		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - bottomBarHeight)
			let panelMinHeight = min(basePanelMinHeight, availableHeight)
			let panelMinWidth = 550
			ZStack(alignment: .bottomTrailing) {
				// Dismiss inspector when tapping outside cards/content.
				Color.clear
					.contentShape(Rectangle())
					.onTapGesture {
						if inspector.isPresented {
							selectedApp = nil
							inspector.hide()
						}
					}

				VStack(alignment: .leading) {
					HStack(alignment: .top) {
						// Primary content panel (scan/import/list selection).
						leftPanel(
							panelMinHeight: panelMinHeight,
							panelMinWidth: CGFloat(panelMinWidth)
						)
					}
					.frame(maxWidth: .infinity, alignment: .topLeading)
					.padding(.horizontal, 40)
					.padding(.vertical, 0)
					Spacer(minLength: 20)
				}
			}
			.onAppearUnlessPreview {
				panelMinHeightCache = panelMinHeight
			}
			.onChange(of: panelMinHeight) { _, newValue in
				panelMinHeightCache = newValue
				if inspector.isPresented, selectedApp == nil,
					!suppressQueueAutoShow, !showingDetails
				{
					inspector.show(queuePanelView(panelMinHeight: newValue))
				}
			}
			.onChange(of: queueItems.count) { oldValue, newValue in
				guard oldValue == 0, newValue > 0 else { return }
				guard !inspector.isPresented, selectedApp == nil,
					!suppressQueueAutoShow, !showingDetails
				else { return }
				inspector.show(
					queuePanelView(panelMinHeight: panelMinHeightCache)
				)
			}
			.onChange(of: inspector.isPresented) { _, isPresented in
				if !isPresented {
					selectedApp = nil
					showingDetails = false
					return
				}
				if selectedApp == nil, !suppressQueueAutoShow, !showingDetails {
					inspector.show(
						queuePanelView(panelMinHeight: panelMinHeightCache)
					)
				}
			}
		}
		.onChange(of: selectedApp?.id) { _, _ in
			updateInspector()
		}
		.onDisappear {
			inspector.hide()
		}
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.ifAvailableMacOS14ContentMarginsElsePadding()
		.onAppearUnlessPreview {
			importApps = model.importItems
			queueItems = []
			resultsItems = model.importResults
		}
		.sheet(isPresented: $confirmationVisible) {
			QueueActionSheet(
				mode: confirmationMode,
				itemCount: queueItems.count,
				onConfirm: {
					confirmationVisible = false
				},
				onCancel: {
					confirmationVisible = false
				}
			)
		}
	}

	@ViewBuilder
	private func leftPanel(panelMinHeight: CGFloat, panelMinWidth: CGFloat)
		-> some View
	{
		VStack(alignment: .leading, spacing: 16) {
			SectionHeader(
				"Import Applications",
				subtitle:
					"Upload local packages and metadata for Workspace ONE."
			)
			importActionRow().frame(alignment: .leading)
			if !importApps.isEmpty {
				importHeaderRow()
					.frame(minWidth: 550)
					.frame(maxWidth: 900, alignment: .center)
			}
			importListSection()
		}
		.padding(16)
		.frame(
			minWidth: panelMinWidth,
			minHeight: panelMinHeight,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.frame(maxWidth: .infinity, alignment: .topLeading)
		.layoutPriority(1)
		.background {
			let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
			Color.clear
				.glassCompatSurface(
					in: shape,
					style: .regular,
					context: glassState,
					fillColor: panelBaseTintColor,
					fillOpacity: min(1, glassBaseOpacity + panelNeutralOverlayOpacity),
					surfaceOpacity: panelGlassOpacity
				)
		}
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.strokeBorder(panelBorderColor)
		}
		.glassCompatShadow(context: glassState, elevation: .card)
		.background(WindowFocusReader { focusObserver.attach($0) })
		.zIndex(1)
	}

	@ViewBuilder
	private func importActionRow() -> some View {
			VStack(alignment: .leading) {
				Text("Select a Folder")
					.font(.system(size: 12, weight: .bold))
					.tracking(-0.5)
					.fontWeight(.medium)
					.frame(alignment: .leading)
				HStack {
					HStack(spacing: 5) {
						Text("Path:")
							.font(.system(size: 11, weight: .regular))
							.foregroundStyle(.tertiary)
						Text(selectedFolderURL?.path ?? "")
							.lineLimit(1)
							.truncationMode(.middle)
							.padding(.horizontal, 12)
							.padding(.vertical, 8)
							.foregroundStyle(.secondary)
						Spacer(minLength: 0)
					}
						.padding(.horizontal, 10)
						.background(
							RoundedRectangle(cornerRadius: 20, style: .continuous)
								.stroke(panelBorderColor.opacity(0.8), lineWidth: 1)
						)
						.frame(maxWidth: .infinity, alignment: .leading)
					Spacer()
					if #available(macOS 26.0, iOS 26.0, *) {
						Button(action: {
							selectFolder()
							expandActionsTrigger &+= 1
						}) {
							Image(systemName: "folder.fill")
								.symbolRenderingMode(.hierarchical)
								.symbolVariant(.none)
								.fontWeight(.regular)
								.padding(.horizontal, -5)
								.padding(.vertical, 2)
						}
						.padding(1)
						.buttonStyle(.glassProminent)
						.controlSize(.large)
						//.frame(minWidth: 10, minHeight: 10)
						} else {
							Button(action: {
								selectFolder()
								expandActionsTrigger &+= 1
						}) {
							Text("Select Folder")
								.font(.system(size: 12, weight: .regular))
								.padding(.horizontal, 5)
								.padding(.vertical, 4)
							}
							.padding(1)
							.nativeActionButtonStyle(.primary, controlSize: .large)
							.frame(minWidth: 10)
						}

				}
				buttonsView().frame(minHeight: 20)
			}
				.frame(maxWidth: 500)
				.frame(minWidth: 500, alignment: .topLeading)
				.padding(10)
				.background {
					let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
					Color.clear
						.glassCompatSurface(
							in: shape,
							style: .regular,
							context: glassState,
							fillColor: panelBaseTintColor,
							fillOpacity: min(
								1,
								GlassThemeTokens.panelBaseTintOpacity(for: glassState)
									+ (panelNeutralOverlayOpacity * 0.45)
							),
							surfaceOpacity: panelGlassOpacity
						)
				}
				.overlay(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.strokeBorder(panelBorderColor.opacity(0.9))
				)
				.glassCompatShadow(context: glassState, elevation: .small)
			
			
		}

	@ViewBuilder
	private func buttonsView() -> some View {
		ActionButtonsAvailabilityAdapter(
			primaryTitle: "Scan",
			secondaryTitle: "Clear",
			isEnabled: true,
			isFolderSelected: selectedFolderURL != nil,
			externalExpandTrigger: expandActionsTrigger,
			onPrimary: {
				startScan()
			},
			onSecondary: {
				clearScan()
			}
		)
	}

	@ViewBuilder
	private func selectedFolderRow() -> some View {
		HStack(alignment: .center, spacing: 8) {
			Text("Selected Folder")
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.secondary)
			Text(selectedFolderURL?.path ?? "None")
				.font(.system(size: 11, weight: .medium, design: .monospaced))
				.foregroundStyle(
					selectedFolderURL == nil ? .secondary : .primary
				)
				.lineLimit(1)
				.truncationMode(.middle)
			Spacer(minLength: 0)
		}
		.opacity((selectedFolderURL?.path.isEmpty ?? true) ? 0 : 1)
		.padding(.horizontal, 4)
	}

	@ViewBuilder
	private func importHeaderRow() -> some View {
		HStack(alignment: .center, spacing: 8) {
			HStack(spacing: 8) {
				JuiceTypography.sectionTitle("Discovered Apps")
				if !importApps.isEmpty {
					InfoBadge(count: importApps.count)
				}
			}
			Spacer(minLength: 1)
		}
	}

	@ViewBuilder
	private func importListSection() -> some View {
		if isScanning {
			VStack(alignment: .center) {
				VStack(alignment: .center, spacing: 10) {
					ThinkingIndicator(
						phrases: [
							"Scanning folders",
							"Collecting installers",
							"Reading metadata",
						],
						iconName: "sparkles"
					)
				}
				.frame(maxWidth: .infinity, alignment: .center)
			}
			.frame(maxWidth: .infinity, alignment: .center)
			.frame(
				minWidth: 500,
				maxWidth: .infinity,
				minHeight: 150,
				alignment: .center
			)
		} else if importApps.count > 0 {
			ZStack(alignment: .bottom) {
				ScrollView {
					FlowLayout(spacing: 6, rowSpacing: 6, rowAlignment: .center)
					{
						ForEach(
							Array(importApps.enumerated()),
							id: \.element.id
						) { _, app in
							ImportAppDetailCard(
								item: app,
								isSelected: selectedAppIds.contains(app.id),
								onToggleSelect: { toggleSelection(for: app) },
								onDetails: { showDetails(for: app) }
							)
							.transition(
								.asymmetric(
									insertion: .move(edge: .top).combined(
										with: .opacity
									),
									removal: .scale(scale: 0.9).combined(
										with: .opacity
									)
								)
							)
						}
					}
					.padding(.vertical, 6)
					.padding(.horizontal, 6)
					.background(Color.clear)
					.frame(minWidth: 300)
					.frame(idealWidth: 800)
					.frame(maxWidth: 900)
				}
				.scrollContentBackground(.hidden)
				.background(Color.clear)

							if !selectedAppIds.isEmpty {
								Button("Add Selected (\(selectedAppIds.count))") {
									addSelectedToQueue()
								}
								.nativeActionButtonStyle(.primary, controlSize: .large)
								.padding(.trailing, 20)
								.padding(.bottom, 16)
								.glassCompatShadow(context: glassState, elevation: .card)
						}
			}
			.background(Color.clear)
			.frame(maxHeight: 500)
			.frame(minWidth: 500)
		}
	}

	@ViewBuilder
	private func queuePanelView(panelMinHeight: CGFloat) -> some View {
		InspectorImportQueuePanelView(
			tab: $rightTab,
			queueItems: $queueItems,
			resultsItems: $resultsItems,
			panelMinHeight: panelMinHeight,
			onPrimaryAction: {
				confirmationMode = .upload
				confirmationVisible = true
			},
			onSecondaryAction: {
				confirmationMode = .download
				confirmationVisible = true
			}
		)
	}

	private func updateInspector() {
		guard let app = selectedApp else {
			if inspector.isPresented {
				inspector.show(
					queuePanelView(panelMinHeight: panelMinHeightCache)
				)
			}
			return
		}
		inspector.show(
			ImportAppDetailContent(
				item: app,
				onAddToQueue: {
					addToQueue(app)
					selectedApp = nil
					inspector.show(
						queuePanelView(panelMinHeight: panelMinHeightCache)
					)
				},
				onClose: {
					selectedApp = nil
					inspector.hide()
				}
			)
			.padding(-20)
		)
	}

	private func showDetails(for app: ImportedApplication) {
		suppressQueueAutoShow = true
		showingDetails = true
		selectedApp = app
		inspector.show(
			ImportAppDetailContent(
				item: app,
				onAddToQueue: {
					addToQueue(app)
					selectedApp = nil
					showingDetails = false
					inspector.show(
						queuePanelView(panelMinHeight: panelMinHeightCache)
					)
				},
				onClose: {
					selectedApp = nil
					showingDetails = false
					inspector.hide()
				}
			)
			.padding(-20)
		)
		DispatchQueue.main.async {
			suppressQueueAutoShow = false
		}
	}

	private func addToQueue(_ app: ImportedApplication) {
		guard !queueItems.contains(where: { $0.id == app.id }) else {
			return
		}
		queueItems.append(app)
		inspector.notifyQueueAdded()
		importApps.removeAll { $0.id == app.id }
		selectedAppIds.remove(app.id)
	}

	private func toggleSelection(for app: ImportedApplication) {
		if selectedAppIds.contains(app.id) {
			selectedAppIds.remove(app.id)
		} else {
			selectedAppIds.insert(app.id)
		}
	}

	private func addSelectedToQueue() {
		let selectedApps = importApps.filter { selectedAppIds.contains($0.id) }
		guard !selectedApps.isEmpty else { return }
		for app in selectedApps {
			addToQueue(app)
		}
	}

	private func selectFolder() {
		#if os(macOS)
			let panel = NSOpenPanel()
			panel.canChooseDirectories = true
			panel.canChooseFiles = false
			panel.allowsMultipleSelection = false
			panel.prompt = "Choose Folder"
			if panel.runModal() == .OK {
				selectedFolderURL = panel.url
			}
		#endif
	}

	private func startScan() {
		guard let folderURL = selectedFolderURL, !isScanning else { return }
		Task { await ImportScanService.clearSizeCache() }
		isScanning = true
		selectedAppIds.removeAll()
		selectedApp = nil
		Task {
			let results = await ImportScanService.scanFolder(rootURL: folderURL)
			let matched = await ImportScanService.applyRecipeMatches(
				to: results,
				recipes: catalog.recipes
			)
			await MainActor.run {
				importApps = matched
				isScanning = false
			}
		}
	}

	private func clearScan() {
		importApps.removeAll()
		resultsItems.removeAll()
		queueItems.removeAll()
		selectedAppIds.removeAll()
		selectedFolderURL = nil
		isScanning = false
		Task { await ImportScanService.clearSizeCache() }
	}
}

@available(macOS 26.0, iOS 16.0, *)
private struct ActionButtonsGlass: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void
	let externalExpandTrigger: Int

	@State private var isExpanded = false
	@State private var isAllExpanded = false
	@State private var glassSpacing: CGFloat = 40
	@State private var buttonSpacing: CGFloat = 25
	@State private var expandTask: Task<Void, Never>?
	@Namespace private var namespace

	var body: some View {
		ZStack {
			GlassEffectContainer(spacing: glassSpacing) {
				HStack(spacing: buttonSpacing) {
					if isExpanded {
						Button(action: onPrimary) {
							Text(primaryTitle)
								.font(.system(size: 12, weight: .regular))
								.padding(.horizontal, 10)
								.padding(.vertical, 4)
								.frame(width: 80)
						}
						.buttonStyle(.glassProminent)
						.controlSize(.large)
						.disabled(!isEnabled)
						.glassEffectID("glassPrimary", in: namespace)

					}
					if isAllExpanded && isExpanded {
						Button(action: {
							onSecondary()
							collapseExpanded()
						}) {
							Text(secondaryTitle)
								.font(.system(size: 12, weight: .regular))
								.padding(.horizontal, 10)
								.padding(.vertical, 4)
								.frame(width: 80)
						}
						.padding(1)
						.buttonStyle(.glass)
						.controlSize(.large)
						.disabled(!isEnabled)
						.glassEffectID("glassSecondary", in: namespace)
					}
				}
				.frame(minWidth: 150, alignment: .leading)
			}
		}
		.frame(maxWidth: 150, alignment: .leading)
		.onChange(of: externalExpandTrigger) { _, _ in
			expandActions()
		}
	}

	private func toggleExpanded() {
		if isExpanded {
			collapseExpanded()
		} else {
			expandActions()
		}
	}

	func expandActions() {
		expandTask?.cancel()
		withAnimation(.bouncy) {
			isExpanded.toggle()
		}
		expandTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.1))
			withAnimation(.bouncy) {
				isAllExpanded.toggle()
			}
			try? await Task.sleep(for: .seconds(0.3))
			glassSpacing = 10
			buttonSpacing = 10
		}
	}

	private func collapseExpanded() {
		expandTask?.cancel()
		glassSpacing = 40
		buttonSpacing = 25
		withAnimation(.bouncy) {
			isExpanded.toggle()
		}
		Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.2))
			withAnimation(.bouncy) {
				isAllExpanded.toggle()
			}
		}
	}
}

private struct ActionButtonsAvailabilityAdapter: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let isFolderSelected: Bool
	let externalExpandTrigger: Int
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	var body: some View {
		#if os(macOS)
			if #available(macOS 26.0, *) {
				ActionButtonsGlass(
					primaryTitle: primaryTitle,
					secondaryTitle: secondaryTitle,
					isEnabled: isEnabled,
					onPrimary: onPrimary,
					onSecondary: onSecondary,
					externalExpandTrigger: externalExpandTrigger
				)
			} else {
				ActionButtonsFallback(
					primaryTitle: primaryTitle,
					secondaryTitle: secondaryTitle,
					isEnabled: isEnabled,
					onPrimary: onPrimary,
					onSecondary: onSecondary
				)
			}
		#else
			ExpandingButtons_PrebigSurFallback(
				primaryTitle: primaryTitle,
				secondaryTitle: secondaryTitle,
				isEnabled: isEnabled,
				onPrimary: onPrimary,
				onSecondary: onSecondary
			)
		#endif
	}
}

private struct ActionButtonsFallback: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false

	var body: some View {
		HStack(spacing: 16) {
			if isExpanded {
				Button(primaryTitle) {
					guard isEnabled else { return }
					onPrimary()
				}
				.disabled(!isEnabled)
				Button(secondaryTitle) {
					guard isEnabled else { return }
					onSecondary()
				}
				.disabled(!isEnabled)
			}
			ZStack(alignment: .topTrailing) {
				Button {
					withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
					{
						isExpanded.toggle()
					}
					} label: {
						Image(systemName: isExpanded ? "xmark" : "plus")
							.frame(width: 44, height: 44)
					}
					.nativeActionButtonStyle(.primary, controlSize: .large)
					.buttonBorderShape(.capsule)
				}
		}
		.padding(12)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(.ultraThinMaterial)
		)
	}
}

#Preview {
	ImportView(model: .sample)
		.environmentObject(InspectorCoordinator())
		.environmentObject(LocalCatalog())
		.frame(width: 800, height: 500)
		.background(JuiceGradient())
}
