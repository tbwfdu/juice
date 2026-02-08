import SwiftUI
#if os(macOS)
import AppKit
#endif

// Updates page.
// Layout ownership:
// - Left panel: available updates, filters, and selection.
// - Inspector panel: queue/results/download processing.

struct UpdatesView: View {
	// MARK: - Inputs & Environment

	let model: PageViewData
	@EnvironmentObject private var inspector: InspectorCoordinator
	@EnvironmentObject private var catalog: LocalCatalog
	@Environment(\.colorScheme) private var colorScheme
	@State private var rightTab: QueuePanelContent<AnyView, AnyView>.Tab =
		.queue
	@State private var queueItems: [CaskApplication] = []
	@State private var queuedSourceAppsByKey: [String: UemApplication] = [:]
	@State private var resultsItems: [CaskApplication] = []
	@State private var uemApps: [UemApplication] = []
	@State private var isQueryingUem = false
	@State private var showAllUemApps = false
	@State private var selectedApp: UemApplication?
	@State private var selectedAppKeys: Set<String> = []
	@State private var queueNotice: QueuePanelContent<AnyView, AnyView>.Notice?
	@State private var confirmationVisible = false
	@State private var confirmationMode: ConfirmationActionMode = .upload
	@StateObject private var downloadQueueModel = DownloadQueueViewModel()
	@State private var downloadQueueTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
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
				VStack(alignment: .leading) {
					HStack(alignment: .top) {
						// Primary updates content panel.
						leftPanel(
							panelMinHeight: panelMinHeight,
							panelMinWidth: CGFloat(panelMinWidth)
						)
					}
					.frame(maxWidth: .infinity, alignment: .topLeading)
					.padding(.horizontal, 40)
					.padding(.vertical, 0)
					.contentShape(Rectangle())
					.onTapGesture {
						// Click-away dismiss for inspector detail.
						if inspector.isPresented {
							selectedApp = nil
							inspector.hide()
						}
					}
					Spacer(minLength: 20)
				}

				EmptyView()
			}
			.onAppearUnlessPreview {
				panelMinHeightCache = panelMinHeight
			}
			.onChange(of: panelMinHeight) { _, newValue in
				panelMinHeightCache = newValue
				if inspector.isPresented, selectedApp == nil {
					if downloadQueueModel.shouldPresentPanel {
						inspector.show(
							downloadPanelView(panelMinHeight: newValue)
						)
					} else {
						inspector.show(queuePanelView(panelMinHeight: newValue))
					}
				}
			}
			.onChange(of: queueItems.count) { oldValue, newValue in
				guard oldValue == 0, newValue > 0 else { return }
				guard !inspector.isPresented, selectedApp == nil else { return }
				inspector.show(
					queuePanelView(panelMinHeight: panelMinHeightCache)
				)
			}
			.onChange(of: inspector.isPresented) { _, isPresented in
				if isPresented, selectedApp == nil {
					if downloadQueueModel.shouldPresentPanel {
						inspector.show(
							downloadPanelView(panelMinHeight: panelMinHeightCache)
						)
					} else {
						inspector.show(
							queuePanelView(panelMinHeight: panelMinHeightCache)
						)
					}
				} else if !isPresented {
					selectedApp = nil
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
			queueItems = model.queueItems
			resultsItems = model.updateItems
			DispatchQueue.main.async {
				withAnimation(.bouncy(duration: 0.35, extraBounce: 0.12)) {
					uemApps = model.uemApps
				}
			}
		}
		.sheet(isPresented: $confirmationVisible) {
			QueueActionSheet(
				mode: confirmationMode,
				itemCount: queueItems.count,
				onConfirm: {
					confirmationVisible = false
					startQueueProcessing(mode: confirmationMode)
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
				"Application Updates",
				subtitle: "Query Workspace ONE for Application Updates"
			)
			queryButtonsRow()
			if !uemApps.isEmpty {
				let updates: [UemApplication] = uemApps.filter { ($0.hasUpdate ?? false) }
				let displayedApps: [UemApplication] = showAllUemApps ? uemApps : updates
				updatesHeaderRow(displayedApps: displayedApps)
					.frame(minWidth: 550)
					.frame(
						maxWidth: 900,
						alignment: .init(
							horizontal: .center,
							vertical: .center
						)
					)
			}
			appsListSection()
		}
		.padding(16)
		.frame(
			minWidth: CGFloat(panelMinWidth),
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
		private func queryButtonsRow() -> some View {
			HStack(spacing: 8) {
				Button("Get All Apps") {
					Task { @MainActor in
						isQueryingUem = true
						let apps: [UemApplication] = await UEMService.instance
						.getAllApps().compactMap { $0 }
					withAnimation(.bouncy(duration: 0.35, extraBounce: 0.12)) {
						uemApps = apps
						selectedAppKeys.removeAll()
						selectedApp = nil
							isQueryingUem = false
						}
					}
				}
				.nativeActionButtonStyle(.primary, controlSize: .large)
				Button("Clear") {
					withAnimation(.bouncy(duration: 0.3, extraBounce: 0.1)) {
						uemApps.removeAll()
					}
				}
				.nativeActionButtonStyle(.secondary, controlSize: .large)
				.disabled(uemApps.isEmpty)
			}
		}

	@ViewBuilder
	private func appsListSection() -> some View {
		if isQueryingUem {
			VStack(alignment: .center) {
				VStack(alignment: .center, spacing: 10) {
					ThinkingIndicator(
						phrases: [
							"Querying Workspace ONE",
							"Evaluating Matches",
							"Identifying Updates",
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
		} else if uemApps.count > 0 {
			ZStack(alignment: .bottom) {
				ScrollView {
					let updates: [UemApplication] = uemApps.filter { ($0.hasUpdate ?? false) }
					let displayedApps: [UemApplication] = showAllUemApps ? uemApps : updates
					FlowLayout(spacing: 6, rowSpacing: 6, rowAlignment: .center) {
						ForEach(Array(displayedApps.enumerated()), id: \.element.id) { index, app in
							let hasUpdate: Bool = app.hasUpdate ?? false
							AnimatedAppCard(
								app: app,
								delay: Double(index) * 0.04,
								isSelected: selectedAppKeys.contains(appKey(app)),
								onToggleSelect: hasUpdate ? { toggleSelection(for: app) } : nil,
								onDetails: hasUpdate ? { selectedApp = app } : nil
							)
							.transition(
								.asymmetric(
									insertion: .move(edge: .top).combined(with: .opacity),
									removal: .scale(scale: 0.9).combined(with: .opacity)
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
					//.border(.red, width: 1)
				}
				.scrollContentBackground(.hidden)
				.background(Color.clear)

						if !selectedAppKeys.isEmpty {
							Button("Add Selected (\(selectedAppKeys.count))") {
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
			//.border(.blue, width: 3)
		}
	}

	@ViewBuilder
	private func updatesHeaderRow(displayedApps: [UemApplication]) -> some View {
		HStack(alignment: .center, spacing: 8) {
			updatesHeaderTitle(displayedApps: displayedApps)
			Spacer(minLength: 1)
			Toggle(
				"Show All",
				isOn: showAllToggleBinding
			)
			.labelStyle(.iconOnly)
			.toggleStyle(.switch)
			.controlSize(.regular)
			.frame(
				maxWidth: 900,
				alignment: .init(
					horizontal: .trailing,
					vertical: .center
				)
			)
			.padding(
				EdgeInsets(
					top: 0,
					leading: 0,
					bottom: 0,
					trailing: 5
				)
			)
		}
	}

	@ViewBuilder
	private func updatesHeaderTitle(displayedApps: [UemApplication]) -> some View {
		HStack(spacing: 8) {
			JuiceTypography.sectionTitle(
				showAllUemApps
					? "All Apps" : "Available Updates"
			)
			.id(
				showAllUemApps
					? "title_all" : "title_updates"
			)

			if !displayedApps.isEmpty && !showAllUemApps {
				InfoBadge(count: displayedApps.count)
			}
		}
	}

	private var showAllToggleBinding: Binding<Bool> {
		Binding(
			get: { showAllUemApps },
			set: { newValue in
				withAnimation(
					.bouncy(duration: 0.3, extraBounce: 0.1)
				) {
					showAllUemApps = newValue
				}
			}
		)
	}

	@ViewBuilder
	private func queuePanelView(panelMinHeight: CGFloat) -> some View {
			InspectorUpdatesQueuePanelView(
				tab: $rightTab,
				notice: $queueNotice,
				queueItems: $queueItems,
				resultsItems: $resultsItems,
				selectedAppKeys: $selectedAppKeys,
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
					restoreQueueItemsToUpdates(removedItems)
				}
			)
		}

	@ViewBuilder
	private func downloadPanelView(panelMinHeight: CGFloat) -> some View {
		DownloadQueuePanelContent(
			model: downloadQueueModel,
			tab: $downloadQueueTab,
			panelMinHeight: panelMinHeight
		)
	}

	private func updateInspector() {
		guard let app = selectedApp else {
			if inspector.isPresented {
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
			return
		}
		inspector.show(
			AppDetailContent(
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
					inspector
						.hide()
				}
			)
			.padding(-20)
		)
	}

	private func startQueueProcessing(mode: ConfirmationActionMode) {
		guard !queueItems.isEmpty else { return }
		downloadQueueModel.configure(
			queue: queueItems,
			mode: mode,
			recipes: catalog.recipes
		)
		queueItems.removeAll()
		queuedSourceAppsByKey.removeAll()
		selectedAppKeys.removeAll()
		inspector.show(
			downloadPanelView(panelMinHeight: panelMinHeightCache)
		)
		downloadQueueModel.start()
	}
}

extension UpdatesView {
	fileprivate func toggleSelection(for app: UemApplication) {
		guard app.hasUpdate ?? false else { return }
		let key = appKey(app)
		if selectedAppKeys.contains(key) {
			selectedAppKeys.remove(key)
		} else {
			selectedAppKeys.insert(key)
		}
	}

		fileprivate func addToQueue(_ app: UemApplication, showNotice: Bool = true)
		{
			guard app.hasUpdate ?? false else { return }
			let key = appKey(app)
		guard !queueItems.contains(where: { $0.id == key }) else {
			if showNotice {
				showQueueNotice("Already in queue", isDuplicate: true)
			}
			return
			}
			queueItems.append(queueItem(from: app))
			queuedSourceAppsByKey[key] = app
			inspector.notifyQueueAdded()
			uemApps.removeAll { appKey($0) == key }
			selectedAppKeys.remove(key)
		if showNotice {
			showQueueNotice("Added to queue", isDuplicate: false)
		}
	}

	fileprivate func addSelectedToQueue() {
		let selectedApps = uemApps.filter {
			selectedAppKeys.contains(appKey($0)) && ($0.hasUpdate ?? false)
		}
		guard !selectedApps.isEmpty else { return }
		for app in selectedApps {
			addToQueue(app, showNotice: false)
		}
		if selectedApps.count == 1 {
			showQueueNotice("Added to queue", isDuplicate: false)
		} else {
			showQueueNotice(
				"Added \(selectedApps.count) apps to queue",
				isDuplicate: false
			)
		}
	}

		fileprivate func removeFromQueue(_ app: UemApplication) {
			let key = appKey(app)
			let removedItems = queueItems.filter { $0.id == key }
			withAnimation(.easeInOut(duration: 0.2)) {
				queueItems.removeAll { $0.id == key }
			}
			restoreQueueItemsToUpdates(removedItems)
		}

		fileprivate func restoreQueueItemsToUpdates(_ removedItems: [CaskApplication]) {
			guard !removedItems.isEmpty else { return }
			var restored: [UemApplication] = []

			for item in removedItems {
				let key = item.id
				guard !uemApps.contains(where: { appKey($0) == key }) else { continue }

				if let source = queuedSourceAppsByKey.removeValue(forKey: key) {
					restored.append(source)
				} else {
					restored.append(rebuildUemAppFromQueueItem(item, key: key))
				}
			}

			guard !restored.isEmpty else { return }
			withAnimation(.easeInOut(duration: 0.2)) {
				uemApps.insert(contentsOf: restored, at: 0)
			}
		}

		fileprivate func rebuildUemAppFromQueueItem(_ item: CaskApplication, key: String) -> UemApplication {
			UemApplication(
				applicationName: item.displayName,
				bundleId: item.token,
				appVersion: item.version,
				actualFileVersion: item.version,
				appType: nil,
				status: nil,
				platform: nil,
				supportedModels: nil,
				assignmentStatus: nil,
				categoryList: nil,
				smartGroups: nil,
				isReimbursable: nil,
				applicationSource: nil,
				locationGroupId: nil,
				rootLocationGroupName: item.desc,
				organizationGroupUuid: nil,
				largeIconUri: nil,
				mediumIconUri: nil,
				smallIconUri: nil,
				pushMode: nil,
				appRank: nil,
				assignedDeviceCount: nil,
				installedDeviceCount: nil,
				notInstalledDeviceCount: nil,
				autoUpdateVersion: nil,
				enableProvisioning: nil,
				isDependencyFile: nil,
				contentGatewayId: nil,
				iconFileName: nil,
				applicationFileName: item.url,
				metadataFileName: nil,
				numericId: nil,
				uuid: key,
				isSelected: false,
				hasUpdate: true,
				isLatest: nil,
				wasMatched: nil,
				updatedApplicationGuid: nil,
				updatedApplication: item
			)
		}

	fileprivate func appKey(_ app: UemApplication) -> String {
		if let uuid = app.uuid, !uuid.isEmpty {
			return uuid
		}
		if let numeric = app.numericId?.value {
			return String(numeric)
		}
		if !app.bundleId.isEmpty {
			return app.bundleId
		}
		return app.applicationName
	}

	fileprivate func queueItem(from app: UemApplication) -> CaskApplication {
		if let updated = app.updatedApplication {
			return updated
		}
		return CaskApplication(
			token: appKey(app),
			fullToken: appKey(app),
			name: [app.applicationName],
			desc: app.rootLocationGroupName ?? app.bundleId,
			url: app.applicationFileName,
			version: app.appVersion,
			matchingRecipeId: nil
		)
	}

	fileprivate func showQueueNotice(_ message: String, isDuplicate: Bool) {
		queueNotice = .init(message: message, isDuplicate: isDuplicate)
	}
}

private struct AnimatedAppCard: View {
	let app: UemApplication
	let delay: Double
	let isSelected: Bool
	let onToggleSelect: (() -> Void)?
	let onDetails: (() -> Void)?
	@State private var isVisible = false

	var body: some View {
		AppDetailCard(
			item: app,
			isSelected: isSelected,
			onToggleSelect: onToggleSelect,
			onDetails: onDetails
		)
		.opacity(isVisible ? 1 : 0)
		.offset(y: isVisible ? 0 : 8)
		.onAppearUnlessPreview {
			withAnimation(
				.bouncy(duration: 0.45, extraBounce: 0.12).delay(delay)
			) {
				isVisible = true
			}
		}
	}
}

private struct GlassSwitchToggleStyle: ToggleStyle {
	@Environment(\.controlSize) private var controlSize
	@Environment(\.colorScheme) private var colorScheme
	#if os(macOS)
	@Environment(\.controlActiveState) private var controlActiveState
	#endif

	private var isWindowActive: Bool {
		#if os(macOS)
		return controlActiveState == .active
		#else
		return true
		#endif
	}

	func makeBody(configuration: Configuration) -> some View {
		Button {
			configuration.isOn.toggle()
		} label: {
			HStack(spacing: 10) {
				configuration.label
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.secondary)
				switchView(isOn: configuration.isOn)
			}
		}
		.buttonStyle(.plain)
		//.animation(.easeOut(duration: 0.18), value: configuration.isOn)
	}

	@ViewBuilder
	private func switchView(isOn: Bool) -> some View {
		let trackSize = trackDimensions
		let knobDiameter = knobSize
		let padding = (trackSize.height - knobDiameter) / 2
		let travel = trackSize.width - knobDiameter - padding * 2
		let context = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: isWindowActive,
			isEnabled: true
		)
		let knobShadow = GlassThemeTokens.shadow(for: context, elevation: .small)

		ZStack(alignment: .leading) {
			track
				.frame(width: trackSize.width, height: trackSize.height)
			Circle()
				.fill(GlassThemeTokens.windowBackgroundBase(for: context).opacity(isOn ? 0.98 : 0.9))
				.frame(width: knobDiameter, height: knobDiameter)
				.shadow(
					color: knobShadow.color,
					radius: knobShadow.radius,
					x: knobShadow.x,
					y: knobShadow.y
				)
				.padding(padding)
				.offset(x: isOn ? travel : 0)
		}
		.contentShape(Capsule())
	}

	@ViewBuilder
	private var track: some View {
		let shape = Capsule(style: .continuous)
		let context = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: isWindowActive,
			isEnabled: true
		)
		Color.clear
			.glassCompatSurface(
				in: shape,
				style: .regular,
				context: context,
				fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
				fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: context),
				surfaceOpacity: 1
			)
			.glassCompatBorder(in: shape, context: context, role: .standard, lineWidth: 0.8)
	}

	private var trackDimensions: CGSize {
		switch controlSize {
		case .mini:
			return CGSize(width: 30, height: 16)
		case .small:
			return CGSize(width: 34, height: 18)
		case .regular:
			return CGSize(width: 38, height: 20)
		case .large:
			return CGSize(width: 44, height: 24)
		case .extraLarge:
			return CGSize(width: 50, height: 28)
		@unknown default:
			return CGSize(width: 38, height: 20)
		}
	}

	private var knobSize: CGFloat {
		switch controlSize {
		case .mini:
			return 12
		case .small:
			return 14
		case .regular:
			return 16
		case .large:
			return 20
		case .extraLarge:
			return 24
		@unknown default:
			return 16
		}
	}
}

#Preview {
	UpdatesView(model: .sample)
		.environmentObject(InspectorCoordinator())
		.environmentObject(LocalCatalog())
		.frame(width: 700, height: 400)
			.background {
				JuiceGradient()
					.frame(maxWidth: .infinity)
					.frame(height: 500)
					.mask(
						LinearGradient(
							stops: JuiceBackgroundStyle.v1.legacyTopGradientMaskStops,
							startPoint: .top,
							endPoint: .bottom
						)
				)
				.ignoresSafeArea(edges: .top)
		}
}
