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
	@ObservedObject var state: ImportViewState
	@EnvironmentObject private var inspector: InspectorCoordinator
	@EnvironmentObject private var catalog: LocalCatalog
	@EnvironmentObject private var downloadQueueModel: DownloadQueueViewModel
	@Environment(\.colorScheme) private var colorScheme

	// MARK: - View State

	@State private var queueNoticeTask: Task<Void, Never>?
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

	@State private var importTopRowHeight: CGFloat = 0

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

	private func binding<T>(
		_ keyPath: ReferenceWritableKeyPath<ImportViewState, T>
	) -> Binding<T> {
		Binding(
			get: { state[keyPath: keyPath] },
			set: { state[keyPath: keyPath] = $0 }
		)
	}

	private var rightTab: QueuePanelContent<AnyView, AnyView>.Tab {
		get { state.rightTab }
		nonmutating set { state.rightTab = newValue }
	}

	private var downloadQueueTab: QueuePanelContent<AnyView, AnyView>.Tab {
		get { state.downloadQueueTab }
		nonmutating set { state.downloadQueueTab = newValue }
	}

	private var queueItems: [ImportedApplication] {
		get { state.queueItems }
		nonmutating set { state.queueItems = newValue }
	}

	private var resultsItems: [ImportedApplication] {
		get { state.resultsItems }
		nonmutating set { state.resultsItems = newValue }
	}

	private var queueNotice: QueuePanelContent<AnyView, AnyView>.Notice? {
		get { state.queueNotice }
		nonmutating set { state.queueNotice = newValue }
	}

	private var importApps: [ImportedApplication] {
		get { state.importApps }
		nonmutating set { state.importApps = newValue }
	}

	private var selectedApp: ImportedApplication? {
		get { state.selectedApp }
		nonmutating set { state.selectedApp = newValue }
	}

	private var selectedAppIds: Set<UUID> {
		get { state.selectedAppIds }
		nonmutating set { state.selectedAppIds = newValue }
	}

	private var isScanning: Bool {
		get { state.isScanning }
		nonmutating set { state.isScanning = newValue }
	}

	private var selectedFolderURL: URL? {
		get { state.selectedFolderURL }
		nonmutating set { state.selectedFolderURL = newValue }
	}

	private var suppressQueueAutoShow: Bool {
		get { state.suppressQueueAutoShow }
		nonmutating set { state.suppressQueueAutoShow = newValue }
	}

	private var showingDetails: Bool {
		get { state.showingDetails }
		nonmutating set { state.showingDetails = newValue }
	}

	private var confirmationVisible: Bool {
		get { state.confirmationVisible }
		nonmutating set { state.confirmationVisible = newValue }
	}

	private var confirmationMode: ConfirmationActionMode {
		get { state.confirmationMode }
		nonmutating set { state.confirmationMode = newValue }
	}

	private var expandActionsTrigger: Int {
		get { state.expandActionsTrigger }
		nonmutating set { state.expandActionsTrigger = newValue }
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
						mainContentPanel(
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
					if downloadQueueModel.shouldPresentPanel {
						inspector.show(
							downloadPanelView(panelMinHeight: newValue)
						)
					} else {
						inspector.show(queuePanelView(panelMinHeight: newValue))
					}
				}
			}
			.onChange(of: inspector.isPresented) { _, isPresented in
				if !isPresented {
					selectedApp = nil
					showingDetails = false
					return
				}
				if selectedApp == nil, !suppressQueueAutoShow, !showingDetails {
					if downloadQueueModel.shouldPresentPanel {
						inspector.show(
							downloadPanelView(
								panelMinHeight: panelMinHeightCache
							)
						)
					} else {
						inspector.show(
							queuePanelView(panelMinHeight: panelMinHeightCache)
						)
					}
				}
			}
			.onChange(of: downloadQueueModel.shouldPresentPanel) {
				_,
				shouldPresent in
				if inspector.isPresented, selectedApp == nil {
					if shouldPresent {
						inspector.show(
							downloadPanelView(
								panelMinHeight: panelMinHeightCache
							)
						)
					} else {
						inspector.show(
							queuePanelView(panelMinHeight: panelMinHeightCache)
						)
					}
				}
			}
			.onChange(of: downloadQueueModel.stage) { _, newStage in
				if inspector.isPresented, selectedApp == nil {
					if newStage == .completed || newStage == .cancelled {
						inspector.show(
							downloadPanelView(
								panelMinHeight: panelMinHeightCache
							)
						)
					}
				}
			}
		}
		.onChange(of: selectedApp?.id) { _, _ in
			updateInspector()
		}
		.onDisappear {
			if selectedApp != nil || !downloadQueueModel.shouldPresentPanel {
				inspector.hide()
			}
			queueNoticeTask?.cancel()
			queueNoticeTask = nil
		}
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.ifAvailableMacOS14ContentMarginsElsePadding()
		.onAppearUnlessPreview {
			if !state.hasInitialized {
				importApps = model.importItems
				queueItems = []
				resultsItems = model.importResults
				state.hasInitialized = true
			}
			
			// Ensure inspector content is correct on appear
			if selectedApp == nil {
				if downloadQueueModel.shouldPresentPanel {
					inspector.show(
						downloadPanelView(panelMinHeight: panelMinHeightCache > 0 ? panelMinHeightCache : basePanelMinHeight)
					)
				}
			}
		}
		.sheet(isPresented: binding(\.confirmationVisible)) {
			QueueActionSheet(
				mode: confirmationMode,
				itemCount: queueItems.count,
				onConfirm: {
					confirmationVisible = false
					if confirmationMode == .download {
						completeDownloadOnlyQueue()
					} else if confirmationMode == .upload {
						startQueueProcessing()
					}
				},
				onCancel: {
					confirmationVisible = false
				}
			)
		}
	}

	@ViewBuilder
	private func mainContentPanel(panelMinHeight: CGFloat, panelMinWidth: CGFloat)
		-> some View
	{
		let panelShape = RoundedRectangle(cornerRadius: 20, style: .continuous)
		let hasResults = !importApps.isEmpty
		ZStack(alignment: .top) {
				if hasResults {
					leftPanelGlassRow(
						backgroundTopInset: max(0, importTopRowHeight - 4),
						showsTopBorder: false
					) {
						importListSection(topOverlayHeight: importTopRowHeight)
					}
				}

				leftPanelGlassRow(
					showsBottomBorder: hasResults ? false : true,
					cornerRadius: 20,
					corners: hasResults ? [.topLeft, .topRight] : .allCorners
				) {
				VStack(alignment: .leading, spacing: 16) {
					SectionHeader(
						"Import Applications",
						subtitle:
							"Upload local packages and metadata for Workspace ONE."
					)
					importActionRow().frame(alignment: .leading)
					if hasResults {
						importHeaderRow()
							.frame(minWidth: 300)
							.frame(maxWidth: 900, alignment: .center)
					} else if isScanning {
						Spacer(minLength: 20)
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
						Spacer(minLength: 0)
					} else {
						Spacer(minLength: 0)
					}
				}
				.padding(16)
				.frame(
					maxHeight: hasResults ? nil : .infinity,
					alignment: .topLeading
				)
			}
			.background(
				GeometryReader { proxy in
					Color.clear.preference(
						key: ImportHeaderRowHeightKey.self,
						value: proxy.size.height
					)
				}
			)
		}
		.onPreferenceChange(ImportHeaderRowHeightKey.self) { newValue in
			if newValue > 0 {
				importTopRowHeight = newValue
			}
		}
		.frame(
			minWidth: panelMinWidth,
			minHeight: panelMinHeight,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.frame(maxWidth: .infinity, alignment: .topLeading)
		.layoutPriority(1)
		.background(colorScheme == .dark ? Color.black.opacity(0.48) : Color.white)
		.background {
			if #available(macOS 26.0, iOS 16.0, *) {
				GlassEffectContainer {
					panelShape
						.fill(Color.clear)
						.glassEffect(.regular, in: panelShape).tint(Color.black)
				}
			} else {
				panelShape.fill(.ultraThinMaterial)
			}
		}
		.clipShape(panelShape)
		.overlay {
			panelShape.strokeBorder(panelBorderColor)
		}
		//.glassCompatShadow(context: glassState, elevation: .panel)
		.background(WindowFocusReader { focusObserver.attach($0) })
		.zIndex(1)
		.overlay(alignment: .center) {
			if let notice = queueNotice {
				leftPanelQueueNotice(notice)
					.transition(
						.opacity.combined(with: .scale(scale: 0.96, anchor: .center))
					)
					.allowsHitTesting(false)
			}
		}
		.modifier(QueueNoticeAnimationBypass(value: queueNotice))
	}

	@ViewBuilder
	private func leftPanelGlassRow<Content: View>(
		preferMaterialFallback: Bool = false,
		backgroundTopInset: CGFloat = 0,
		showsTopBorder: Bool = true,
		showsBottomBorder: Bool = true,
		showsGlass: Bool = true,
		cornerRadius: CGFloat = 0,
		corners: CustomRoundedCorners.Corner = .allCorners,
		contentTopClip: CGFloat = 0,
		@ViewBuilder content: () -> Content
	) -> some View {
		let shape = CustomRoundedCorners(radius: cornerRadius, corners: corners)
		let borderColor = Color.white.opacity(0.0)
		let glassStart = max(0, backgroundTopInset + contentTopClip)
		let borderStart = max(0, backgroundTopInset)
		if #available(macOS 26.0, iOS 16.0, *) {
			content()
				.frame(maxWidth: .infinity, alignment: .topLeading)
				.background {
					if showsGlass {
						ZStack {
							if preferMaterialFallback || colorScheme == .dark {
								shape.fill(.ultraThinMaterial)
							} else {
								GlassEffectContainer {
									shape
										.fill(Color.clear)
										.glassEffect(.regular, in: shape)
								}
							}
							shape.fill(
								Color.black.opacity(colorScheme == .dark ? 0.34 : 0.08)
							)
							shape
								.fill(
									LinearGradient(
										colors: [
											Color.white.opacity(0.03),
											.clear,
										],
										startPoint: .top,
										endPoint: .bottom
									)
								)
								.scaleEffect(x: 1, y: 0.5, anchor: .top)
						}
						.mask {
							VStack(spacing: 0) {
								Color.clear.frame(height: glassStart)
								Rectangle().fill(Color.white)
							}
						}
						.transaction { transaction in
							transaction.animation = nil
						}
						.allowsHitTesting(false)
					}
				}
				.overlay {
					ZStack {
						HStack(spacing: 0) {
							Rectangle().fill(borderColor).frame(width: 1)
							Spacer(minLength: 0)
							Rectangle().fill(borderColor).frame(width: 1)
						}
						if showsTopBorder {
							VStack(spacing: 0) {
								Rectangle().fill(borderColor).frame(height: 1)
								Spacer(minLength: 0)
							}
						}
						if showsBottomBorder {
							VStack(spacing: 0) {
								Spacer(minLength: 0)
								Rectangle().fill(borderColor).frame(height: 1)
							}
						}
					}
					.mask {
						VStack(spacing: 0) {
							Color.clear.frame(height: borderStart)
							Rectangle().fill(Color.white)
						}
					}
					.allowsHitTesting(false)
				}
				.clipShape(shape)
		} else {
			content()
				.frame(maxWidth: .infinity, alignment: .topLeading)
				.background {
					if showsGlass {
						shape
							.fill(
								Color(nsColor: .windowBackgroundColor).opacity(
									colorScheme == .dark ? 0.92 : 0.94
								)
							)
							.mask {
								VStack(spacing: 0) {
									Color.clear.frame(height: glassStart)
									Rectangle().fill(Color.white)
								}
							}
						.transaction { transaction in
							transaction.animation = nil
						}
						.allowsHitTesting(false)
					}
				}
				.overlay {
					ZStack {
						HStack(spacing: 0) {
							Rectangle().fill(borderColor).frame(width: 1)
							Spacer(minLength: 0)
							Rectangle().fill(borderColor).frame(width: 1)
						}
						if showsTopBorder {
							VStack(spacing: 0) {
								Rectangle().fill(borderColor).frame(height: 1)
								Spacer(minLength: 0)
							}
						}
						if showsBottomBorder {
							VStack(spacing: 0) {
								Spacer(minLength: 0)
								Rectangle().fill(borderColor).frame(height: 1)
							}
						}
					}
					.mask {
						VStack(spacing: 0) {
							Color.clear.frame(height: borderStart)
							Rectangle().fill(Color.white)
						}
					}
					.allowsHitTesting(false)
				}
				.clipShape(shape)
		}
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

					#if os(macOS)
						if #available(macOS 26.0, *) {
							Button(action: {
								if selectFolder() {
									expandActionsTrigger &+= 1
								}
							}) {
								Image(systemName: "plus")
									.symbolRenderingMode(.hierarchical)
								.symbolVariant(.none)
								.fontWeight(.regular)
								.padding(.horizontal, 2)
								.padding(.vertical, 2)
						}
						.padding(1)
						.juiceGradientGlassProminentButtonStyle(controlSize: .large)
						.frame(minWidth: 30, minHeight: 30)
						} else {
							Button("Select Folder") {
								if selectFolder() {
									expandActionsTrigger &+= 1
								}
							}
							.juiceGradientGlassProminentButtonStyle(controlSize: .large)
							.padding(.horizontal, 4)
							.frame(minWidth: 110, minHeight: 30)
						}
					#else
						Button("Select Folder") {
							if selectFolder() {
								expandActionsTrigger &+= 1
							}
						}
						.juiceGradientGlassProminentButtonStyle(controlSize: .large)
						.padding(.horizontal, 4)
					.frame(minWidth: 110, minHeight: 30)
				#endif
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
				.padding(.leading, 10)
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
				.padding(.horizontal, 12)
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
				.juiceFullValueHelp(fullValue: selectedFolderURL?.path ?? "")
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
					.juiceHelp(HelpText.Import.selectAll)
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
					.juiceHelp(HelpText.Import.selectAll)
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
				.juiceHelp(HelpText.Import.selectAll)
			#endif
		}
	}

	@ViewBuilder
	private func importListSection(topOverlayHeight: CGFloat = 0) -> some View {
		Group {
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
								#if os(macOS)
									if #available(macOS 26.0, *) {
										ImportAppDetailCard(
											item: app,
											isSelected: selectedAppIds.contains(app.id),
											onToggleSelect: { toggleSelection(for: app) },
											onDetails: { showDetails(for: app) },
											onAddToQueue: { addToQueue(app) }
										)
									} else {
										ImportAppDetailCard(
											item: app,
											isSelected: selectedAppIds.contains(app.id),
											onToggleSelect: { toggleSelection(for: app) },
											onDetails: { showDetails(for: app) },
											onAddToQueue: { addToQueue(app) }
										)
									}
								#else
									ImportAppDetailCard(
										item: app,
										isSelected: selectedAppIds.contains(app.id),
										onToggleSelect: { toggleSelection(for: app) },
										onDetails: { showDetails(for: app) },
										onAddToQueue: { addToQueue(app) }
									)
								#endif
							}
						}
						.padding(.top, topOverlayHeight + 6)
						.padding(.bottom, 16)
						.padding(.horizontal, 6)
						.background(Color.clear)
						.frame(minWidth: 300)
						.frame(idealWidth: 800)
						.frame(maxWidth: 900)
					}
					.panelContentScrollChrome(
						topInset: 0,
						bottomContentInset: !selectedAppIds.isEmpty ? 60 : 20,
						applyMask: false
					)
					.contentMargins(.top, topOverlayHeight + 2, for: .scrollIndicators)
					.contentMargins(.bottom, 10, for: .scrollIndicators)
					.scrollContentBackground(.hidden)
					.background(Color.clear)

					if !selectedAppIds.isEmpty {
						#if os(macOS)
							if #available(macOS 26.0, *) {
								Button("Add Selected (\(selectedAppIds.count))") {
									addSelectedToQueue()
								}
								.nativeActionButtonStyle(.secondary, controlSize: .large)
								.juiceHelp(HelpText.Import.addSelected)
								.padding(.trailing, 20)
								.padding(.bottom, 16)
								.glassCompatShadow(context: glassState, elevation: .card)
								.zIndex(2)
							} else {
								Button("Add Selected (\(selectedAppIds.count))") {
									addSelectedToQueue()
								}
								.nativeActionButtonStyle(.secondary, controlSize: .large)
								.juiceHelp(HelpText.Import.addSelected)
								.padding(.trailing, 20)
								.padding(.bottom, 16)
								.zIndex(2)
								.transition(.opacity)
							}
						#else
							Button("Add Selected (\(selectedAppIds.count))") {
								addSelectedToQueue()
							}
							.nativeActionButtonStyle(.secondary, controlSize: .large)
							.juiceHelp(HelpText.Import.addSelected)
							.padding(.trailing, 20)
							.padding(.bottom, 16)
							.glassCompatShadow(context: glassState, elevation: .card)
							.zIndex(2)
						#endif
					}
				}
				.modifier(FallbackImportSelectionAnimationBypass(value: selectedAppIds.isEmpty))
				.background(Color.clear)
				.frame(minWidth: 500)
			} else {
				Color.clear
			}
		}
		.frame(maxHeight: .infinity, alignment: .topLeading)
		.frame(minWidth: 500)
	}

	@ViewBuilder
	private func queuePanelView(panelMinHeight: CGFloat) -> some View {
		InspectorImportQueuePanelView(
			tab: binding(\.rightTab),
			queueItems: binding(\.queueItems),
			resultsItems: binding(\.resultsItems),
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

	@ViewBuilder
	private func downloadPanelView(panelMinHeight: CGFloat) -> some View {
		DownloadQueuePanelContent(
			model: downloadQueueModel,
			tab: binding(\.downloadQueueTab),
			panelMinHeight: panelMinHeight
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

	private func addToQueue(
		_ app: ImportedApplication,
		showNotice: Bool = true,
		notifyBadge: Bool = true
	) {
		guard !queueItems.contains(where: { $0.id == app.id }) else {
			if showNotice {
				showQueueNotice("Already in Queue", isDuplicate: true)
			}
			return
		}
		if !resultsItems.isEmpty {
			resultsItems.removeAll()
			downloadQueueTab = .queue
			rightTab = .queue
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
		if showNotice {
			showQueueNotice("App added to Queue", isDuplicate: false)
		}
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
		if !resultsItems.isEmpty {
			resultsItems.removeAll()
			downloadQueueTab = .queue
			rightTab = .queue
		}
		let wasQueueEmpty = queueItems.isEmpty
		for app in selectedApps {
			addToQueue(app, showNotice: false, notifyBadge: false)
		}
		inspector.notifyQueueAdded(
			by: selectedApps.count,
			triggerInspectorAttention: wasQueueEmpty && !inspector.isPresented
		)
		if selectedApps.count == 1 {
			showQueueNotice("App added to Queue", isDuplicate: false)
		} else {
			showQueueNotice(
				"Added \(selectedApps.count) apps to Queue",
				isDuplicate: false
			)
		}
	}

	@discardableResult
	private func selectFolder() -> Bool {
		#if os(macOS)
			let panel = NSOpenPanel()
			panel.canChooseDirectories = true
			panel.canChooseFiles = false
			panel.allowsMultipleSelection = false
			panel.prompt = "Choose Folder"
			if panel.runModal() == .OK {
				selectedFolderURL = panel.url
				return panel.url != nil
			}
			return false
		#else
			return false
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

	private func completeDownloadOnlyQueue() {
		guard !queueItems.isEmpty else { return }
		let queuedItems = queueItems
		let existingIds = Set(resultsItems.map(\.id))
		let uniqueQueuedItems = queuedItems.filter { !existingIds.contains($0.id) }
		withAnimation(.easeInOut(duration: 0.2)) {
			resultsItems.insert(contentsOf: uniqueQueuedItems, at: 0)
			queueItems.removeAll()
			selectedAppIds.removeAll()
		}
		let noun = uniqueQueuedItems.count == 1 ? "app" : "apps"
		showQueueNotice("Completed \(uniqueQueuedItems.count) \(noun) (download only)", isDuplicate: false)
	}

	private func startQueueProcessing() {
		guard !queueItems.isEmpty else { return }
		downloadQueueModel.configureForImport(
			items: queueItems,
			recipes: catalog.recipes
		)
		queueItems.removeAll()
		selectedAppIds.removeAll()
		inspector.show(
			downloadPanelView(panelMinHeight: panelMinHeightCache)
		)
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

	private func showQueueNotice(_ message: String, isDuplicate: Bool) {
		let notice = QueuePanelContent<AnyView, AnyView>.Notice(
			message: message,
			isDuplicate: isDuplicate
		)
		queueNoticeTask?.cancel()
		#if os(macOS)
			if #available(macOS 26.0, *) {
				withAnimation(.bouncy(duration: 0.2, extraBounce: 0.08)) {
					queueNotice = notice
				}
			} else {
				withAnimation(.easeInOut(duration: 0.16)) {
					queueNotice = notice
				}
			}
		#else
			withAnimation(.bouncy(duration: 0.2, extraBounce: 0.08)) {
				queueNotice = notice
			}
		#endif
		queueNoticeTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 1_500_000_000)
			guard !Task.isCancelled else { return }
			withAnimation(.easeInOut(duration: 0.14)) {
				queueNotice = nil
			}
		}
	}

	@ViewBuilder
	private func leftPanelQueueNotice(
		_ notice: QueuePanelContent<AnyView, AnyView>.Notice
	) -> some View {
		let shape = Capsule()
		HStack(spacing: 8) {
			Image(
				systemName: notice.isDuplicate
					? "exclamationmark.triangle.fill"
					: "checkmark.circle.fill"
			)
			.foregroundStyle(notice.isDuplicate ? Color.orange : Color.green)
			.font(.system(size: 14, weight: .bold))
			Text(notice.message)
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 8)
		.background {
			#if os(macOS)
				if #available(macOS 26.0, *) {
					Color.clear
						.glassCompatSurface(
							in: shape,
							style: .clear,
							context: glassState,
							fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
							fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
							surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: glassState)
						)
						.glassCompatBorder(in: shape, context: glassState, role: .standard)
						.glassCompatShadow(context: glassState, elevation: .panel)
				} else {
					shape
						.fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
						.overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8))
				}
			#else
				Color.clear
					.glassCompatSurface(
						in: shape,
						style: .clear,
						context: glassState,
						fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
						fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
						surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: glassState)
					)
					.glassCompatBorder(in: shape, context: glassState, role: .standard)
					.glassCompatShadow(context: glassState, elevation: .panel)
			#endif
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
							.juiceHelp(HelpText.Import.scan)
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
								.padding(.horizontal, 2)
								.padding(.vertical, 2)
						}
						.padding(1)
						.buttonStyle(.glass)
						.controlSize(.large)
						.buttonBorderShape(.automatic)
						.disabled(!isEnabled)
						.juiceHelp(HelpText.Import.clear)
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

	var body: some View {
		HStack(spacing: 10) {
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
			.juiceGradientGlassProminentButtonStyle(controlSize: .large)
			.disabled(!isEnabled)
			.allowsHitTesting(!isPrimaryInProgress)
			.juiceHelp(HelpText.Import.scan)
			.accessibilityLabel(primaryTitle)

			Button {
				guard isEnabled else { return }
				onSecondary()
			} label: {
				Image(systemName: "xmark")
					.font(.system(size: 11, weight: .regular))
					.padding(.horizontal, 2)
					.padding(.vertical, 2)
			}
			.nativeActionButtonStyle(.secondary, controlSize: .large)
			.frame(width: 36, height: 36)
			.disabled(!isEnabled)
			.juiceHelp(HelpText.Import.clear)
			.accessibilityLabel(secondaryTitle)
		}
	}
}

#if os(macOS)
private struct QueueNoticeAnimationBypass<Value: Equatable>: ViewModifier {
	let value: Value
	func body(content: Content) -> some View {
		if #available(macOS 26.0, *) {
			content.animation(.bouncy(duration: 0.22, extraBounce: 0.08), value: value)
		} else {
			content.animation(.easeInOut(duration: 0.16), value: value)
		}
	}
}

private struct FallbackImportSelectionAnimationBypass<Value: Equatable>: ViewModifier {
	let value: Value
	func body(content: Content) -> some View {
		if #available(macOS 26.0, *) {
			content.animation(.bouncy(duration: 0.28, extraBounce: 0.18), value: value)
		} else {
			content.animation(.easeInOut(duration: 0.15), value: value)
		}
	}
}
#else
private struct QueueNoticeAnimationBypass<Value: Equatable>: ViewModifier {
	let value: Value
	func body(content: Content) -> some View {
		content.animation(.bouncy(duration: 0.22, extraBounce: 0.08), value: value)
	}
}
#endif

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

private struct ImportHeaderRowHeightKey: PreferenceKey {
	static let defaultValue: CGFloat = 0
	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		let next = nextValue()
		if next > 0 {
			value = next
		}
	}
}

#Preview {
	ImportView(model: .sample, state: ImportViewState())
		.environmentObject(InspectorCoordinator())
		.environmentObject(LocalCatalog())
		.environmentObject(DownloadQueueViewModel())
		.frame(width: 800, height: 500)
		.background(JuiceGradient())
}
