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
	@State private var queueNoticeTask: Task<Void, Never>?
	@State private var confirmationVisible = false
	@State private var confirmationMode: ConfirmationActionMode = .upload
	@StateObject private var downloadQueueModel = DownloadQueueViewModel()
	@State private var downloadQueueTab:
		QueuePanelContent<AnyView, AnyView>.Tab = .queue
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
				VStack(alignment: .leading) {
					HStack(alignment: .top) {
						// Primary updates content panel.
						leftPanel(
							panelMinHeight: panelMinHeight,
							panelMinWidth: CGFloat(panelMinWidth)
						)
					}
					.frame(maxWidth: .infinity, alignment: .topLeading)
					.padding(.horizontal, 20)
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
			.onChange(of: inspector.isPresented) { _, isPresented in
				if isPresented, selectedApp == nil {
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
		ZStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 16) {
				SectionHeader(
					"Application Updates",
					subtitle: "Query Workspace ONE for Application Updates"
				)
				//queryButtonsRow()
				buttonsView()
				if !uemApps.isEmpty {
					let updates: [UemApplication] = uemApps.filter {
						($0.hasUpdate ?? false)
					}
					let displayedApps: [UemApplication] =
						showAllUemApps ? uemApps : updates
					updatesHeaderRow(displayedApps: displayedApps)
						.frame(minWidth: 550)
						.frame(
							maxWidth: 900,
							alignment: .init(
								horizontal: .center,
								vertical: .center
							)
						).padding(0)
				}
				appsListSection()
			}
			if let notice = queueNotice {
				leftPanelQueueNotice(notice)
					.transition(
						.opacity.combined(with: .scale(scale: 0.96, anchor: .center))
					)
					.allowsHitTesting(false)
			}
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
		.animation(.bouncy(duration: 0.22, extraBounce: 0.08), value: queueNotice)
	}

	@ViewBuilder
	private func queryButtonsRow() -> some View {
		HStack(spacing: 8) {
			#if os(macOS)
				if #available(macOS 26.0, *) {
							Button(action: queryAllApps) {
								HStack(spacing: 5) {
									CloudQueryBadgeIcon(
										size: 11,
										isAnimating: isQueryingUem
									)
									Text("Query")
										.font(.system(size: 12, weight: .regular))
								}
							.padding(.horizontal, 8)
							.padding(.vertical, 3)
						}
						.juiceGradientGlassProminentButtonStyle(controlSize: .small)
						.buttonBorderShape(.capsule)

					Button(action: clearQueriedApps) {
						Image(systemName: "xmark")
							.font(.system(size: 11, weight: .regular))
							.padding(.horizontal, -5)
							.padding(.vertical, 2)
					}
					.padding(1)
					.buttonStyle(.glass)
					.controlSize(.large)
					.buttonBorderShape(.automatic)
					.disabled(uemApps.isEmpty)
				} else {
							Button(action: queryAllApps) {
								HStack(spacing: 5) {
									CloudQueryBadgeIcon(
										size: 11,
										isAnimating: isQueryingUem
									)
									Text("Query")
										.font(.system(size: 12, weight: .regular))
								}
							.padding(.horizontal, 8)
							.padding(.vertical, 3)
						}
						.juiceGradientGlassProminentButtonStyle(controlSize: .small)
						.buttonBorderShape(.capsule)

					Button(action: clearQueriedApps) {
						Image(systemName: "xmark")
							.font(.system(size: 11, weight: .regular))
							.padding(.horizontal, -5)
							.padding(.vertical, 2)
					}
					.nativeActionButtonStyle(.secondary, controlSize: .large)
					.buttonBorderShape(.automatic)
					.disabled(uemApps.isEmpty)
				}
			#else
					Button(action: queryAllApps) {
						HStack(spacing: 5) {
							CloudQueryBadgeIcon(
								size: 11,
								isAnimating: isQueryingUem
							)
							Text("Query")
								.font(.system(size: 12, weight: .regular))
						}
					.padding(.horizontal, 8)
					.padding(.vertical, 3)
				}
				.juiceGradientGlassProminentButtonStyle(controlSize: .small)
				.buttonBorderShape(.capsule)

				Button(action: clearQueriedApps) {
					Image(systemName: "xmark")
						.font(.system(size: 11, weight: .regular))
						.padding(.horizontal, -5)
						.padding(.vertical, 2)
				}
				.nativeActionButtonStyle(.secondary, controlSize: .large)
				.buttonBorderShape(.automatic)
				.disabled(uemApps.isEmpty)
			#endif
		}
	}

	@ViewBuilder
	private func buttonsView() -> some View {
		ActionButtonsAvailabilityAdapter(
			primaryTitle: "Query",
			secondaryTitle: "Clear",
			isEnabled: true,
			isSecondaryEnabled: !isQueryingUem,
			isPrimaryInProgress: isQueryingUem,
			externalExpandTrigger: expandActionsTrigger,
			onPrimary: {
				queryAllApps()
			},
			onSecondary: {
				clearQueriedApps()
			}
		)
	}

	private func queryAllApps() {
		guard !isQueryingUem else { return }
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

	private func clearQueriedApps() {
		guard !isQueryingUem else { return }
		withAnimation(.bouncy(duration: 0.3, extraBounce: 0.1)) {
			uemApps.removeAll()
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
					let updates: [UemApplication] = uemApps.filter {
						($0.hasUpdate ?? false)
					}
					let displayedApps: [UemApplication] =
						showAllUemApps ? uemApps : updates
					FlowLayout(spacing: 6, rowSpacing: 6, rowAlignment: .center)
					{
						ForEach(
							Array(displayedApps.enumerated()),
							id: \.element.id
						) { index, app in
							let hasUpdate: Bool = app.hasUpdate ?? false
							AnimatedAppCard(
								app: app,
								delay: Double(index) * 0.04,
								isSelected: selectedAppKeys.contains(
									appKey(app)
								),
								onToggleSelect: hasUpdate
									? { toggleSelection(for: app) } : nil,
								onDetails: hasUpdate
									? { selectedApp = app } : nil,
								onAddToQueue: hasUpdate
									? { addToQueue(app) } : nil
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
					
					.padding(.top, 6)
					.padding(.bottom, 16)
					.padding(.horizontal, 6)
					.background(Color.clear)
					.frame(minWidth: 300)
					.frame(idealWidth: 800)
					.frame(maxWidth: 900)
					//.border(.red, width: 1)
				}
				.panelContentScrollChrome(
					topInset: 0,
					bottomContentInset: !selectedAppKeys.isEmpty ? 60 : 20
				)
				.scrollContentBackground(.hidden)
				.background(Color.clear)
					if !selectedAppKeys.isEmpty {
						Button("Add Selected (\(selectedAppKeys.count))") {
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
					.animation(.bouncy(duration: 0.28, extraBounce: 0.18), value: selectedAppKeys.isEmpty)
					.background(Color.clear)
					.frame(maxHeight: 500)
					.frame(minWidth: 500)
			//.border(.blue, width: 3)
		}
	}

	@ViewBuilder
	private func updatesHeaderRow(displayedApps: [UemApplication]) -> some View
	{
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
			#if os(macOS)
				if #available(macOS 26.0, *) {
					Button {
						selectAllUpdatableApps(from: displayedApps)
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
					.disabled(!displayedApps.contains(where: { $0.hasUpdate ?? false }))
				} else {
					Button {
						selectAllUpdatableApps(from: displayedApps)
					} label: {
						Image(systemName: "checkmark.rectangle.stack")
							.font(.system(size: 11, weight: .regular))
							.padding(.horizontal, -3)
							.padding(.vertical, 2)
					}
					.nativeActionButtonStyle(.secondary, controlSize: .large)
					.buttonBorderShape(.automatic)
					.disabled(!displayedApps.contains(where: { $0.hasUpdate ?? false }))
				}
			#else
				Button {
					selectAllUpdatableApps(from: displayedApps)
				} label: {
					Image(systemName: "checkmark.rectangle.stack")
						.font(.system(size: 11, weight: .regular))
						.padding(.horizontal, -3)
						.padding(.vertical, 2)
				}
				.nativeActionButtonStyle(.secondary, controlSize: .large)
				.buttonBorderShape(.automatic)
				.disabled(!displayedApps.contains(where: { $0.hasUpdate ?? false }))
			#endif
		}
	}

	@ViewBuilder
	private func updatesHeaderTitle(displayedApps: [UemApplication])
		-> some View
	{
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
			notice: .constant(nil),
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
				},
				onClose: {
					selectedApp = nil
					inspector
						.hide()
				}
			)
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
	fileprivate func selectAllUpdatableApps(
		from displayedApps: [UemApplication]
	) {
		let updatableKeys =
			displayedApps
			.filter { $0.hasUpdate ?? false }
			.map(appKey)
		guard !updatableKeys.isEmpty else { return }
		let updatableSet = Set(updatableKeys)
		let allAlreadySelected = updatableSet.isSubset(of: selectedAppKeys)
		if allAlreadySelected {
			selectedAppKeys.subtract(updatableSet)
		} else {
			selectedAppKeys.formUnion(updatableSet)
		}
	}

	fileprivate func toggleSelection(for app: UemApplication) {
		guard app.hasUpdate ?? false else { return }
		let key = appKey(app)
		if selectedAppKeys.contains(key) {
			selectedAppKeys.remove(key)
		} else {
			selectedAppKeys.insert(key)
		}
	}

fileprivate func addToQueue(
	_ app: UemApplication,
	showNotice: Bool = true,
	notifyBadge: Bool = true
)
	{
		guard app.hasUpdate ?? false else { return }
		let key = appKey(app)
		guard !queueItems.contains(where: { $0.id == key }) else {
			if showNotice {
				showQueueNotice("Already in queue", isDuplicate: true)
			}
			return
		}
		let wasQueueEmpty = queueItems.isEmpty
		queueItems.append(queueItem(from: app))
		queuedSourceAppsByKey[key] = app
		if notifyBadge {
			inspector.notifyQueueAdded(
				by: 1,
				triggerInspectorAttention: wasQueueEmpty && !inspector.isPresented
			)
		}
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
		let wasQueueEmpty = queueItems.isEmpty
		for app in selectedApps {
			addToQueue(app, showNotice: false, notifyBadge: false)
		}
		inspector.notifyQueueAdded(
			by: selectedApps.count,
			triggerInspectorAttention: wasQueueEmpty && !inspector.isPresented
		)
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

	fileprivate func restoreQueueItemsToUpdates(
		_ removedItems: [CaskApplication]
	) {
		guard !removedItems.isEmpty else { return }
		var restored: [UemApplication] = []

		for item in removedItems {
			let key = item.id
			guard !uemApps.contains(where: { appKey($0) == key }) else {
				continue
			}

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
		expandActionsTrigger &+= 1
	}

	fileprivate func rebuildUemAppFromQueueItem(
		_ item: CaskApplication,
		key: String
	) -> UemApplication {
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
		let notice = QueuePanelContent<AnyView, AnyView>.Notice(
			message: message,
			isDuplicate: isDuplicate
		)
		queueNoticeTask?.cancel()
		withAnimation(.bouncy(duration: 0.2, extraBounce: 0.08)) {
			queueNotice = notice
		}
		queueNoticeTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 1_500_000_000)
			guard !Task.isCancelled else { return }
			withAnimation(.easeInOut(duration: 0.14)) {
				queueNotice = nil
			}
		}
	}

	@ViewBuilder
	fileprivate func leftPanelQueueNotice(
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
				.foregroundStyle(.primary)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 8)
		.background {
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
		}
	}
}

private struct CloudQueryBadgeIcon: View {
	let size: CGFloat
	let isAnimating: Bool
	@State private var bounce = false
	@State private var breathe = false

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			Image(systemName: "icloud")
				.font(.system(size: size, weight: .semibold))
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
			updateBounceAnimation()
		}
		.onChange(of: isAnimating) { _, _ in
			updateBounceAnimation()
		}
	}

	private func updateBounceAnimation() {
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

private struct AnimatedAppCard: View {
	let app: UemApplication
	let delay: Double
	let isSelected: Bool
	let onToggleSelect: (() -> Void)?
	let onDetails: (() -> Void)?
	let onAddToQueue: (() -> Void)?
	@State private var isVisible = false

	var body: some View {
		AppDetailCard(
			item: app,
			isSelected: isSelected,
			onToggleSelect: onToggleSelect,
			onDetails: onDetails,
			onAddToQueue: onAddToQueue
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
		let knobShadow = GlassThemeTokens.shadow(
			for: context,
			elevation: .small
		)

		ZStack(alignment: .leading) {
			track
				.frame(width: trackSize.width, height: trackSize.height)
			Circle()
				.fill(
					GlassThemeTokens.windowBackgroundBase(for: context).opacity(
						isOn ? 0.98 : 0.9
					)
				)
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
				fillOpacity: GlassThemeTokens.panelBaseTintOpacity(
					for: context
				),
				surfaceOpacity: 1
			)
			.glassCompatBorder(
				in: shape,
				context: context,
				role: .standard,
				lineWidth: 0.8
			)
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

@available(macOS 26.0, iOS 16.0, *)
private struct ActionButtonsGlass: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let isSecondaryEnabled: Bool
	let isPrimaryInProgress: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void
	let externalExpandTrigger: Int

	@State private var isClearExpanded = false
	@State private var expandedPadding: CGFloat = 0
	@State private var expandedOpacity: Double = 1.0
	
	@State private var phase: CGFloat = 0
	
	@Namespace private var namespace

	var body: some View {
		//GlassEffectContainer(spacing: 10) {
			HStack(spacing: 10) {
					Button(action: {
						guard isEnabled, !isPrimaryInProgress else { return }
						onPrimary()
						expandClearIfNeeded()
					}) {
						HStack(spacing: 5) {
							QueryUEMBadgeIcon(size: 11, isAnimating: isPrimaryInProgress)
							Text("Query")
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

				if isClearExpanded {
						Button(action: {
							guard isSecondaryEnabled else { return }
							onSecondary()
							collapseExpanded()
						}) {
							Image(systemName: "xmark")
								.font(.system(size: 11, weight: .regular))
								.padding(.horizontal, -5)
								.padding(.vertical, 2)
						}
						.liquidNoticeStyle(isVisible: isClearExpanded, phase: phase)
						.opacity(expandedOpacity)
						.padding(.leading, expandedPadding)
						.buttonStyle(.glass)
						.controlSize(.large)
						.buttonBorderShape(.automatic)
						.disabled(!isEnabled || !isSecondaryEnabled)
						.accessibilityLabel(secondaryTitle)
						.glassEffectID("glassSecondary", in: namespace)

						.onAppear {
							withAnimation(.bouncy(duration: 0.2, extraBounce: 0.28)) {
								phase = 1
							}
						}
				}
			}
		//}
		.frame(maxWidth: .infinity, alignment: .leading)
		.onChange(of: externalExpandTrigger) { _, _ in
			expandClearIfNeeded()
		}
	}

	private func expandClearIfNeeded() {
		guard !isClearExpanded else { return }
		withAnimation(.bouncy(duration: 0.3, extraBounce: 0.08)) {
			isClearExpanded = true
		}
	}

	private func collapseExpanded() {

		Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.05))
			withAnimation(.easeInOut(duration: 0.1)) {
				phase = 2
			}
			try? await Task.sleep(for: .seconds(0.05))
			withAnimation(.easeOut(duration: 0.12)) {
				phase = 0
				isClearExpanded = false
			}
		}

		//		withAnimation(.bouncy(duration: 0.28, extraBounce: 0.06)) {
		//			isClearExpanded.toggle()
		//		}
	}
}

private struct ActionButtonsAvailabilityAdapter: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let isSecondaryEnabled: Bool
	let isPrimaryInProgress: Bool
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
						isSecondaryEnabled: isSecondaryEnabled,
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
						isSecondaryEnabled: isSecondaryEnabled,
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
	let isSecondaryEnabled: Bool
	let isPrimaryInProgress: Bool
	let externalExpandTrigger: Int
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isClearExpanded = false

	var body: some View {
		HStack(spacing: 16) {
				Button {
					guard isEnabled, !isPrimaryInProgress else { return }
					onPrimary()
					expandClearIfNeeded()
			} label: {
					HStack(spacing: 5) {
						QueryUEMBadgeIcon(size: 11, isAnimating: isPrimaryInProgress)
						Text("Query")
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

			if isClearExpanded {
				Button {
					guard isEnabled, isSecondaryEnabled else { return }
					onSecondary()
					collapseExpanded()
				} label: {
					Image(systemName: "xmark")
						.font(.system(size: 11, weight: .regular))
						.padding(.horizontal, -5)
						.padding(.vertical, 2)
				}
				.nativeActionButtonStyle(.secondary, controlSize: .large)
				.buttonBorderShape(.automatic)
				.disabled(!isEnabled || !isSecondaryEnabled)
				.accessibilityLabel(secondaryTitle)
				.transition(.move(edge: .trailing).combined(with: .opacity))
			}
		}
		.onChange(of: externalExpandTrigger) { _, _ in
			expandClearIfNeeded()
		}
	}

	private func collapseExpanded() {
		withAnimation(.easeOut(duration: 0.15)) {
			isClearExpanded = false
		}
	}

	private func expandClearIfNeeded() {
		guard !isClearExpanded else { return }
		withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
			isClearExpanded = true
		}
	}
}

private struct QueryUEMBadgeIcon: View {
	let size: CGFloat
	let isAnimating: Bool
	@State private var bounce = false
	@State private var breathe = false

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			Image(systemName: "icloud")
				.font(.system(size: size, weight: .semibold))
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
			updateBounceAnimation()
		}
		.onChange(of: isAnimating) { _, _ in
			updateBounceAnimation()
		}
	}

	private func updateBounceAnimation() {
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

struct LiquidNoticeModifier: ViewModifier {
	let isVisible: Bool
	let phase: CGFloat // 0...1 (drive with animation)

	func body(content: Content) -> some View {
		if #available(macOS 26.0, iOS 26.0, *) {
			content
				.scaleEffect(0.9 + (0.16 * phase))
				.blur(radius: (1 - phase) * 6)             // unblur on appear
				.opacity(isVisible ? (0.82 + 0.18 * phase) : 0)
				//.glassEffect(.clear)
		} else {
			content
				.scaleEffect(0.9 + (0.16 * phase))
				.blur(radius: (1 - phase) * 4)
				.opacity(isVisible ? (0.85 + 0.15 * phase) : 0)
		}
	}
}

extension View {
	func liquidNoticeStyle(isVisible: Bool, phase: CGFloat) -> some View {
		modifier(LiquidNoticeModifier(isVisible: isVisible, phase: phase))
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
						stops: JuiceBackgroundStyle.v1
							.legacyTopGradientMaskStops,
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.ignoresSafeArea(edges: .top)
		}
}
