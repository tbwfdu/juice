import SwiftUI

struct UpdatesView: View {
	let model: PageViewData
	@EnvironmentObject private var inspector: InspectorCoordinator
	@State private var rightTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
	@State private var queueItems: [CaskApplication] = []
	@State private var resultsItems: [CaskApplication] = []
	@State private var uemApps: [UemApplication] = []
	@State private var isQueryingUem = false
	@State private var showAllUemApps = false
	@State private var selectedApp: UemApplication?
	@State private var selectedAppKeys: Set<String> = []
	@State private var queueNotice: QueuePanelContent<AnyView, AnyView>.Notice?
	@State private var confirmationVisible = false
	@State private var confirmationMode: ConfirmationActionMode = .upload
	private let basePanelMinHeight: CGFloat = 680
	private let bottomBarHeight: CGFloat = 88
	private let panelGlassOpacity: CGFloat = 0.95
	@StateObject private var focusObserver = WindowFocusObserver()
	@State private var panelMinHeightCache: CGFloat = 0

	private var glassBaseOpacity: CGFloat {
		focusObserver.isFocused ? 0.6 : 0.3
	}

	var body: some View {
		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - bottomBarHeight)
			let panelMinHeight = min(basePanelMinHeight, availableHeight)
			let panelMinWidth = 550
			ZStack(alignment: .bottomTrailing) {
				VStack(alignment: .leading) {
					HStack(alignment: .top) {
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
						if inspector.isPresented {
							selectedApp = nil
							inspector.hide()
						}
					}
					Spacer(minLength: 20)
				}

				EmptyView()
			}
			.onAppear {
				panelMinHeightCache = panelMinHeight
			}
			.onChange(of: panelMinHeight) { _, newValue in
				panelMinHeightCache = newValue
				if inspector.isPresented, selectedApp == nil {
					inspector.show(queuePanelView(panelMinHeight: newValue))
				}
			}
			.onChange(of: queueItems.count) { oldValue, newValue in
				guard oldValue == 0, newValue > 0 else { return }
				guard !inspector.isPresented, selectedApp == nil else { return }
				inspector.show(queuePanelView(panelMinHeight: panelMinHeightCache))
			}
			.onChange(of: inspector.isPresented) { _, isPresented in
				if isPresented, selectedApp == nil {
					inspector.show(queuePanelView(panelMinHeight: panelMinHeightCache))
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
		.onAppear {
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
				},
				onCancel: {
					confirmationVisible = false
				}
			)
		}
	}

	@ViewBuilder
	private func leftPanel(panelMinHeight: CGFloat, panelMinWidth: CGFloat) -> some View {
		VStack(alignment: .leading, spacing: 16) {
			SectionHeader(
				"Application Updates",
				subtitle: "Query Workspace ONE for Application Updates"
			)
			HStack(spacing: 8) {
				JuiceButtons.primary("Get All Apps") {
					Task {
						isQueryingUem = true
						let apps = await UEMService.instance
							.getAllApps().compactMap {
								$0
							}
						withAnimation(.bouncy(duration: 0.35, extraBounce: 0.12)) {
							uemApps = apps
							selectedAppKeys.removeAll()
							selectedApp = nil
							isQueryingUem = false
						}
					}
				}
				JuiceButtons.secondary("Clear") {
					withAnimation(.bouncy(duration: 0.3, extraBounce: 0.1)) {
						uemApps.removeAll()
					}
				}
				.disabled(uemApps.isEmpty)
			}
			if !uemApps.isEmpty {
				let updates = uemApps.filter { ($0.hasUpdate ?? false) }
				let displayedApps = showAllUemApps ? uemApps : updates
				HStack(alignment: .center, spacing: 8) {
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
					Spacer(minLength: 1)
					Toggle("Show All", isOn: Binding(
						get: { showAllUemApps },
						set: { newValue in
							withAnimation(.bouncy(duration: 0.3, extraBounce: 0.1)) {
								showAllUemApps = newValue
							}
						}
					))
						.labelStyle(.iconOnly)
						.toggleStyle(.switch)
						.controlSize(.regular)
						.frame(
							maxWidth: .infinity,
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
				.frame(minWidth: 550)
				.frame(
					maxWidth: .infinity,
					alignment: .init(
						horizontal: .center,
						vertical: .center
					)
				)
			}
			if isQueryingUem {
				VStack(alignment: .center) {
					VStack(alignment: .center, spacing: 10) {
						ThinkingIndicator(
							phrases: [
								"Querying Workspace ONE",
								"Evaluating Matches",
								"Identifying Updates"
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
						LazyVGrid(
							columns: [
								GridItem(.flexible(), spacing: 5),
								GridItem(.flexible(), spacing: 5),
							],
							alignment: .center,
							spacing: 4
						) {
							let updates = uemApps.filter {
								($0.hasUpdate ?? false)
							}
							let displayedApps =
								showAllUemApps ? uemApps : updates
							ForEach(Array(displayedApps.enumerated()), id: \.element.id) { index, app in
								let hasUpdate = app.hasUpdate ?? false
								AnimatedAppCard(
									app: app,
									delay: Double(index) * 0.04,
									isSelected: selectedAppKeys.contains(appKey(app)),
									onToggleSelect: hasUpdate ? {
										toggleSelection(for: app)
									} : nil,
									onDetails: hasUpdate ? {
										selectedApp = app
									} : nil
								)
									.transition(.asymmetric(
										insertion: .move(edge: .top).combined(with: .opacity),
										removal: .scale(scale: 0.9).combined(with: .opacity)
									))
							}
						}
						.padding(.vertical, 6)
						.padding(.horizontal, 6)
						.background(Color.clear)
					}
					.scrollContentBackground(.hidden)
					.background(Color.clear)

					if !selectedAppKeys.isEmpty {
						JuiceButtons.primary("Add Selected (\(selectedAppKeys.count))") {
							addSelectedToQueue()
						}
						.padding(.trailing, 20)
						.padding(.bottom, 16)
						.shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
					}

				}
				.background(Color.clear)
				.frame(maxHeight: 500)
				.frame(minWidth: 550)

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
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer {
					shape
						.fill(Color.white).opacity(glassBaseOpacity)
						.glassEffect(.regular, in: shape)
				}
				.opacity(panelGlassOpacity)
			} else {
				shape.fill(.ultraThinMaterial)
					.opacity(panelGlassOpacity)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.strokeBorder(.white.opacity(0.12))
		}
		.shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
		.background(WindowFocusReader { focusObserver.attach($0) })
		.zIndex(1)
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
			}
		)
	}

	private func updateInspector() {
		guard let app = selectedApp else {
			if inspector.isPresented {
				inspector.show(queuePanelView(panelMinHeight: panelMinHeightCache))
			}
			return
		}
		inspector.show(
			AppDetailContent(
				item: app,
				onAddToQueue: {
					addToQueue(app)
					selectedApp = nil
					inspector.show(queuePanelView(panelMinHeight: panelMinHeightCache))
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
}

private extension UpdatesView {
	func toggleSelection(for app: UemApplication) {
		guard app.hasUpdate ?? false else { return }
		let key = appKey(app)
		if selectedAppKeys.contains(key) {
			selectedAppKeys.remove(key)
		} else {
			selectedAppKeys.insert(key)
		}
	}

	func addToQueue(_ app: UemApplication, showNotice: Bool = true) {
		guard app.hasUpdate ?? false else { return }
		let key = appKey(app)
		guard !queueItems.contains(where: { $0.id == key }) else {
			if showNotice {
				showQueueNotice("Already in queue", isDuplicate: true)
			}
			return
		}
		queueItems.append(queueItem(from: app))
		inspector.notifyQueueAdded()
		uemApps.removeAll { appKey($0) == key }
		selectedAppKeys.remove(key)
		if showNotice {
			showQueueNotice("Added to queue", isDuplicate: false)
		}
	}

	func addSelectedToQueue() {
		let selectedApps = uemApps.filter { selectedAppKeys.contains(appKey($0)) && ($0.hasUpdate ?? false) }
		guard !selectedApps.isEmpty else { return }
		for app in selectedApps {
			addToQueue(app, showNotice: false)
		}
		if selectedApps.count == 1 {
			showQueueNotice("Added to queue", isDuplicate: false)
		} else {
			showQueueNotice("Added \(selectedApps.count) apps to queue", isDuplicate: false)
		}
	}

	func removeFromQueue(_ app: UemApplication) {
		let key = appKey(app)
		withAnimation(.easeInOut(duration: 0.2)) {
			queueItems.removeAll { $0.id == key }
		}
	}

	func appKey(_ app: UemApplication) -> String {
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

	func queueItem(from app: UemApplication) -> CaskApplication {
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

	func showQueueNotice(_ message: String, isDuplicate: Bool) {
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
            .onAppear {
                withAnimation(.bouncy(duration: 0.45, extraBounce: 0.12).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

private struct GlassSwitchToggleStyle: ToggleStyle {
	@Environment(\.controlSize) private var controlSize

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

		ZStack(alignment: .leading) {
			track
				.frame(width: trackSize.width, height: trackSize.height)
			Circle()
				.fill(Color.white.opacity(isOn ? 0.98 : 0.9))
				.frame(width: knobDiameter, height: knobDiameter)
				.shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
				.padding(padding)
				.offset(x: isOn ? travel : 0)
		}
		.contentShape(Capsule())
	}

	@ViewBuilder
	private var track: some View {
		let shape = Capsule(style: .continuous)
		if #available(macOS 26.0, iOS 26.0, *) {
			GlassEffectContainer {
				shape
					.fill(Color.clear)
					.glassEffect(.regular, in: shape)
			}
		} else {
			shape.fill(.ultraThinMaterial)
		}
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
		.frame(width: 700, height: 400)
		.background(){
			JuiceGradient()
				.frame(maxWidth: .infinity)
				.frame(height: 500)
				.mask(
					LinearGradient(
						stops: [
							.init(color: Color.white, location: 0.0),
							.init(color: Color.white, location: 0.55),
							.init(color: Color.white.opacity(0.7), location: 0.7),
							.init(color: Color.white.opacity(0.3), location: 0.82),
							.init(color: Color.white.opacity(0.0), location: 1.0)
						],
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.ignoresSafeArea(edges: .top)
		}
}
