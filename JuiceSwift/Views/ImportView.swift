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

	private struct FolderHierarchyItem: Identifiable {
		let id = UUID()
		let icon: String
		let text: String
	}

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
					.padding(.horizontal, 20)
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
					.frame(minWidth: 300)
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
			shape.fill(
				panelBaseTintColor
					.opacity(
						min(1, glassBaseOpacity + panelNeutralOverlayOpacity)
					)
			)
		}
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.strokeBorder(panelBorderColor)
		}
		.shadow(
			color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12),
			radius: 3,
			x: 0,
			y: 1.5
		)
		.background(WindowFocusReader { focusObserver.attach($0) })
		.zIndex(1)
	}

	@ViewBuilder
	private func importActionRow() -> some View {
		VStack(alignment: .leading) {
			Text("Scan Directory")
				.font(.system(size: 12, weight: .bold))
				.tracking(-0.5)
				.fontWeight(.medium)
				.frame(alignment: .leading)
			HStack {
				folderHierarchyView()
					//.padding(.trailing, 10)
					.background(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.stroke(panelBorderColor.opacity(0.8), lineWidth: 1)
					)
					//.frame(maxWidth: .infinity, alignment: .leading)

				Spacer()

				Button(action: {
					selectFolder()
					expandActionsTrigger &+= 1
				}) {
					Image(systemName: "plus")
						.symbolRenderingMode(.hierarchical)
						.symbolVariant(.none)
						.fontWeight(.regular)
						.padding(.horizontal, -5)
						.padding(.vertical, 2)
				}
				.padding(1)
				.juiceGradientGlassProminentButtonStyle(controlSize: .large)
				.frame(minWidth: 10)
			}
		}
		.frame(minWidth: 300, alignment: .topLeading)
		.frame(maxWidth: 900)
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
		buttonsView().frame(minHeight: 20)
	}

	@ViewBuilder
	private func folderHierarchyView() -> some View {
		let hierarchy = folderHierarchyItems()
		if hierarchy.isEmpty {
			Text("No folder selected")
				.font(.system(size: 11, weight: .regular))
				.foregroundStyle(.tertiary)
				.padding(.vertical, 8)
				.padding(.trailing, 12)
				.frame(maxWidth: .infinity, alignment: .leading)
		} else {
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 6) {
					ForEach(Array(hierarchy.enumerated()), id: \.element.id) {
						index,
						item in
						HStack(spacing: 2) {
							Image(systemName: item.icon)
							Text(item.text)
						}
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.secondary)
						if index < hierarchy.count - 1 {
							//							Text(">")
							//								.foregroundStyle(.tertiary)
							Image(systemName: "greaterthan").foregroundStyle(
								.tertiary
							)
						}
					}
				}
				.padding(.vertical, 8)
				.padding(.trailing, 12)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}

	private func folderHierarchyItems() -> [FolderHierarchyItem] {
		guard let selectedFolderURL else { return [] }

		let path = selectedFolderURL.standardizedFileURL.path
		let components = path.split(separator: "/").map(String.init)
		let resourceValues = try? selectedFolderURL.resourceValues(forKeys: [
			.volumeNameKey
		])
		let detectedVolumeName = resourceValues?.volumeName?.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let fallbackVolumeName = "Macintosh HD"
		let volumeName =
			(detectedVolumeName?.isEmpty == false)
			? detectedVolumeName! : fallbackVolumeName

		var items: [FolderHierarchyItem] = [
			FolderHierarchyItem(icon: "internaldrive.fill", text: volumeName)
		]

		let pathStartIndex: Int
		if components.count > 1, components[0] == "Volumes" {
			pathStartIndex = 2
		} else {
			pathStartIndex = 0
		}

		for component in components.dropFirst(pathStartIndex)
		where !component.isEmpty {
			items.append(FolderHierarchyItem(icon: "folder", text: component))
		}

		return items
	}

	@ViewBuilder
	private func buttonsView() -> some View {
		ActionButtonsAvailabilityAdapter(
			primaryTitle: "Scan",
			secondaryTitle: "Clear",
			isEnabled: true,
			isPrimaryInProgress: isScanning,
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
			#if os(macOS)
				if #available(macOS 26.0, *) {
					Button {
						selectAllDiscoveredApps()
					} label: {
						Image(systemName: "checkmark.rectangle.stack")
							.font(.system(size: 11, weight: .regular))
							.padding(.horizontal, -3)
							.padding(.vertical, 2)
					}
					.padding(1)
					.buttonStyle(.glass)
					.controlSize(.large)
					.buttonBorderShape(.automatic)
					.disabled(importApps.isEmpty)
				} else {
					Button {
						selectAllDiscoveredApps()
					} label: {
						Image(systemName: "checkmark.rectangle.stack")
							.font(.system(size: 11, weight: .regular))
							.padding(.horizontal, -3)
							.padding(.vertical, 2)
					}
					.nativeActionButtonStyle(.secondary, controlSize: .large)
					.buttonBorderShape(.automatic)
					.disabled(importApps.isEmpty)
				}
			#else
				Button {
					selectAllDiscoveredApps()
				} label: {
					Image(systemName: "checkmark.rectangle.stack")
						.font(.system(size: 11, weight: .regular))
						.padding(.horizontal, -3)
						.padding(.vertical, 2)
				}
				.nativeActionButtonStyle(.secondary, controlSize: .large)
				.buttonBorderShape(.automatic)
				.disabled(importApps.isEmpty)
			#endif
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
									onDetails: { showDetails(for: app) },
									onAddToQueue: { addToQueue(app) }
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
					.panelContentScrollChrome(
						topInset: 0,
						bottomContentInset: !selectedAppIds.isEmpty ? 60 : 20
					)
					.scrollContentBackground(.hidden)
					.background(Color.clear)

						if !selectedAppIds.isEmpty {
							Button("Add Selected (\(selectedAppIds.count))") {
								addSelectedToQueue()
							}
							.nativeActionButtonStyle(.secondary, controlSize: .large)
								.padding(.trailing, 20)
								.padding(.bottom, 16)
								.glassCompatShadow(context: glassState, elevation: .card)
								.transition(
									.asymmetric(
										insertion: .modifier(
											active: SelectionButtonTransitionState(
												opacity: 0,
												scale: 0.78,
												blur: 10
											),
											identity: SelectionButtonTransitionState(
												opacity: 1,
												scale: 1,
												blur: 0
											)
										),
										removal: .modifier(
											active: SelectionButtonTransitionState(
												opacity: 0,
												scale: 0.88,
												blur: 10
											),
											identity: SelectionButtonTransitionState(
												opacity: 1,
												scale: 1,
												blur: 0
											)
										)
									)
								)
							}
					}
					.animation(.bouncy(duration: 0.28, extraBounce: 0.18), value: selectedAppIds.isEmpty)
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
			},
			onQueueItemsRemoved: { removedItems in
				restoreQueueItemsToImportList(removedItems)
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
				},
				onClose: {
					selectedApp = nil
					inspector.hide()
				}
			)
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
				},
				onClose: {
					selectedApp = nil
					showingDetails = false
					inspector.hide()
				}
			)
		)
		DispatchQueue.main.async {
			suppressQueueAutoShow = false
		}
	}

	private func addToQueue(_ app: ImportedApplication, notifyBadge: Bool = true) {
		guard !queueItems.contains(where: { $0.id == app.id }) else {
			return
		}
		let wasQueueEmpty = queueItems.isEmpty
		queueItems.append(app)
		if notifyBadge {
			inspector.notifyQueueAdded(
				by: 1,
				triggerInspectorAttention: wasQueueEmpty && !inspector.isPresented
			)
		}
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
		let wasQueueEmpty = queueItems.isEmpty
		for app in selectedApps {
			addToQueue(app, notifyBadge: false)
		}
		inspector.notifyQueueAdded(
			by: selectedApps.count,
			triggerInspectorAttention: wasQueueEmpty && !inspector.isPresented
		)
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

	private func restoreQueueItemsToImportList(
		_ removedItems: [ImportedApplication]
	) {
		guard !removedItems.isEmpty else { return }
		let existingIds = Set(importApps.map(\.id))
		let restored = removedItems.filter { !existingIds.contains($0.id) }
		guard !restored.isEmpty else { return }
		withAnimation(.easeInOut(duration: 0.2)) {
			importApps.insert(contentsOf: restored, at: 0)
		}
		expandActionsTrigger &+= 1
	}

	private func selectAllDiscoveredApps() {
		let allIds = Set(importApps.map(\.id))
		guard !allIds.isEmpty else { return }
		let allAlreadySelected = allIds.isSubset(of: selectedAppIds)
		if allAlreadySelected {
			selectedAppIds.subtract(allIds)
		} else {
			selectedAppIds.formUnion(allIds)
		}
	}
}

@available(macOS 26.0, iOS 16.0, *)
private struct ActionButtonsGlass: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let isPrimaryInProgress: Bool
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
							Button(action: {
								guard !isPrimaryInProgress else { return }
								onPrimary()
							}) {
								HStack(spacing: 5) {
									FolderScanBadgeIcon(size: 11, isAnimating: isPrimaryInProgress)
									Text("Scan")
										.font(.system(size: 12, weight: .regular))
										.opacity(isPrimaryInProgress ? 0 : 1)
										.frame(width: isPrimaryInProgress ? 0 : nil, alignment: .leading)
								}
								.frame(width: isPrimaryInProgress ? 26 : 68, alignment: .center)
								.animation(.easeInOut(duration: 0.22), value: isPrimaryInProgress)
								.padding(.horizontal, 8)
								.padding(.vertical, 3)
							}
								.juiceGradientGlassProminentButtonStyle(controlSize: .small)
								.buttonBorderShape(.capsule)
							.disabled(!isEnabled)
							.allowsHitTesting(!isPrimaryInProgress)
							.accessibilityLabel(primaryTitle)
							.glassEffectID("glassPrimary", in: namespace)

					}
					if isAllExpanded && isExpanded {
						Button(action: {
							onSecondary()
							collapseExpanded()
						}) {
							Image(systemName: "xmark")
								.font(.system(size: 11, weight: .regular))
								.padding(.horizontal, -5)
								.padding(.vertical, 2)
						}
						.padding(1)
						.buttonStyle(.glass)
						.controlSize(.large)
						.buttonBorderShape(.automatic)
						.disabled(!isEnabled)
						.accessibilityLabel(secondaryTitle)
						.glassEffectID("glassSecondary", in: namespace)
					}
				}
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		.onChange(of: externalExpandTrigger) { _, _ in
			expandActions()
		}
	}

	func expandActions() {
		expandTask?.cancel()
		if !isExpanded {
			withAnimation(.bouncy) {
				isExpanded = true
			}
		}
		expandTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.1))
			if !isAllExpanded {
				withAnimation(.bouncy) {
					isAllExpanded = true
				}
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
			isExpanded = false
		}
		Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.2))
			withAnimation(.bouncy) {
				isAllExpanded = false
			}
		}
	}
}

private struct ActionButtonsAvailabilityAdapter: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let isPrimaryInProgress: Bool
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
						isPrimaryInProgress: isPrimaryInProgress,
						onPrimary: onPrimary,
						onSecondary: onSecondary,
						externalExpandTrigger: externalExpandTrigger
					)
				} else {
					ActionButtonsFallback(
						primaryTitle: primaryTitle,
						secondaryTitle: secondaryTitle,
						isEnabled: isEnabled,
						isPrimaryInProgress: isPrimaryInProgress,
						externalExpandTrigger: externalExpandTrigger,
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
	let isPrimaryInProgress: Bool
	let externalExpandTrigger: Int
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false

	var body: some View {
		HStack(spacing: 16) {
					if isExpanded {
						Button {
							guard isEnabled, !isPrimaryInProgress else { return }
							onPrimary()
						} label: {
							HStack(spacing: 5) {
								FolderScanBadgeIcon(size: 11, isAnimating: isPrimaryInProgress)
								Text("Scan")
									.font(.system(size: 12, weight: .regular))
									.opacity(isPrimaryInProgress ? 0 : 1)
									.frame(width: isPrimaryInProgress ? 0 : nil, alignment: .leading)
							}
							.frame(width: isPrimaryInProgress ? 26 : 68, alignment: .center)
							.animation(.easeInOut(duration: 0.22), value: isPrimaryInProgress)
							.padding(.horizontal, 8)
							.padding(.vertical, 3)
						}
							.juiceGradientGlassProminentButtonStyle(controlSize: .small)
							.buttonBorderShape(.capsule)
						.disabled(!isEnabled)
						.allowsHitTesting(!isPrimaryInProgress)
						.accessibilityLabel(primaryTitle)
					Button {
						guard isEnabled else { return }
						onSecondary()
					} label: {
						Image(systemName: "xmark")
							.font(.system(size: 11, weight: .regular))
							.padding(.horizontal, -5)
							.padding(.vertical, 2)
					}
					.nativeActionButtonStyle(.secondary, controlSize: .large)
					.buttonBorderShape(.automatic)
					.disabled(!isEnabled)
					.accessibilityLabel(secondaryTitle)
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
		.onChange(of: externalExpandTrigger) { _, _ in
			guard !isExpanded else { return }
			withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
				isExpanded = true
			}
		}
	}
}

private struct SelectionButtonTransitionState: ViewModifier {
	let opacity: Double
	let scale: CGFloat
	let blur: CGFloat

	func body(content: Content) -> some View {
		content
			.opacity(opacity)
			.scaleEffect(scale, anchor: .center)
			.blur(radius: blur)
	}
}

private struct FolderScanBadgeIcon: View {
	let size: CGFloat
	let isAnimating: Bool
	@State private var bounce = false
	@State private var breathe = false

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			Image(systemName: "folder")
				.font(.system(size: size, weight: .regular))
				.scaleEffect(isAnimating && breathe ? 1.06 : 1)

			ZStack {
				Circle()
					.fill(.thinMaterial)
					.frame(width: size * 0.7, height: size * 0.7)
				Image(systemName: "magnifyingglass")
					.font(.system(size: size * 0.42, weight: .semibold))
			}
			.scaleEffect(isAnimating && bounce ? 1.16 : 1)
			.offset(
				x: size * 0.14,
				y: size * 0.14 + (isAnimating && bounce ? -size * 0.06 : 0)
			)
		}
		.onAppear {
			updateAnimations()
		}
		.onChange(of: isAnimating) { _, _ in
			updateAnimations()
		}
	}

	private func updateAnimations() {
		guard isAnimating else {
			bounce = false
			breathe = false
			return
		}
		bounce = false
		breathe = false
		withAnimation(
			.interpolatingSpring(stiffness: 260, damping: 13)
				.repeatForever(autoreverses: true)
		) {
			bounce = true
		}
		withAnimation(
			.easeInOut(duration: 1.15)
				.repeatForever(autoreverses: true)
		) {
			breathe = true
		}
	}
}

#Preview {
	ImportView(model: .sample)
		.environmentObject(InspectorCoordinator())
		.environmentObject(LocalCatalog())
		.frame(width: 800, height: 500)
		.background(JuiceGradient())
}
