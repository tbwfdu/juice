import SwiftUI

struct ContentView: View {
    private let landingBackgroundStyle = JuiceBackgroundStyle.v1
    private let nonLandingBackgroundStyle = JuiceBackgroundStyle.v2
	private let useAlternativeOverlayToolbarControls = true
	private let navWidthRange: ClosedRange<CGFloat> = 220...420
	private let inspectorWidthRange: ClosedRange<CGFloat> = 320...500

    @Environment(\.colorScheme) private var colorScheme
	@AppStorage("juice.navigationPanelWidth") private var storedNavigationWidth: Double = 280
	@AppStorage("juice.inspectorPanelWidth") private var storedInspectorWidth: Double = 400
    @State private var selection: NavigationItem? = .landing
    private let model = PageViewData.instance
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @ObservedObject private var glassPresenter = GlassWindowPresenter.shared
	@StateObject private var inspector = InspectorCoordinator()
    @StateObject private var windowFocusObserver = WindowFocusObserver()
    @State private var inspectorWidth: CGFloat = 400
	@State private var isNavigationPresented = false
	@State private var navigationWidth: CGFloat = 280
	@State private var pendingPanelOpen: PendingPanelOpen?
	@State private var panelTransitionTask: Task<Void, Never>?

	private enum PendingPanelOpen {
		case navigation
		case inspector
	}

    init(initialSelection: NavigationItem? = .search) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
		ZStack(alignment: .top) {
			let currentSelection = selection ?? .landing
			let activeBackgroundStyle = currentSelection == .landing ? landingBackgroundStyle : nonLandingBackgroundStyle
			let showHeader = currentSelection != .landing
			let contentTopPadding: CGFloat = {
				guard showHeader else { return 0 }
				return 65
			}()
			if activeBackgroundStyle.usesWordGlassMaskBackground {
				JuiceGlassWordBackground(style: activeBackgroundStyle, showsDesktopWallpaper: false)
					.ignoresSafeArea()
			} else {
				WindowGlassBackground()
					.ignoresSafeArea()
			}
			if activeBackgroundStyle.showsLegacyTopGradient {
				JuiceGradient()
					.frame(maxWidth: .infinity)
					.frame(height: activeBackgroundStyle.legacyTopGradientHeight)
					.mask(
						LinearGradient(
							stops: activeBackgroundStyle.legacyTopGradientMaskStops,
							startPoint: .top,
							endPoint: .bottom
						)
					)
					.ignoresSafeArea(edges: .top)
			}
			detailView
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.padding(.top, contentTopPadding)
			if showHeader {
				GradientHeaderBar(title: "Juice", backgroundStyle: activeBackgroundStyle.headerBackgroundStyle)
					.zIndex(1)
			}

					let navControlLeadingInset: CGFloat = 89
					let navControlTopInset: CGFloat = 8
					HStack {
						if !isNavigationPresented {
							navigationControlButton
								.padding(.top, navControlTopInset + 5)
								.padding(.leading, navControlLeadingInset)
								.transition(outerControlMorphTransition)
						}
						Spacer()
					}
						.animation(
							.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.18),
							value: isNavigationPresented
						)
					.zIndex(99)

			// Floating Inspector Control
			if currentSelection != .landing && currentSelection != .settings {
				let inspectorOffset: CGFloat = inspector.isPresented ? (inspectorWidth - 5) : 0
				HStack {
					Spacer()
					if !inspector.isPresented {
						inspectorControlButton
							.padding(.top, 13)
							.padding(.trailing, 16 + inspectorOffset)
							.transition(outerControlMorphTransition)
					}
				}
					.animation(
						.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.18),
						value: inspector.isPresented
					)
				.zIndex(99)
			}

			if glassPresenter.isPresenting {
				WindowBlurOverlay()
					.ignoresSafeArea()
					.transition(.opacity)
					.zIndex(2)
			}

				NavigationOverlayView(
					selection: $selection,
					panelWidth: navigationWidth,
					widthRange: navWidthRange,
					isPresented: isNavigationPresented,
					onWidthChange: { newWidth in
						navigationWidth = newWidth
					},
					onResizeEnded: { finalWidth in
						storedNavigationWidth = Double(finalWidth)
					},
					onDismiss: {
						isNavigationPresented = false
					}
				)
				.zIndex((isNavigationPresented || pendingPanelOpen == .navigation) ? 6 : 4)

				InspectorOverlayView(
					content: inspector.content,
				hasContent: inspector.hasContent,
				isPresented: inspector.isPresented,
				panelWidth: inspectorWidth,
				widthRange: inspectorWidthRange,
				isPinned: $inspector.isPinned,
				onWidthChange: { newWidth in
					inspectorWidth = newWidth
				},
				onResizeEnded: { finalWidth in
					storedInspectorWidth = Double(finalWidth)
				},
					onDismiss: {
						guard !inspector.isPinned else { return }
						inspector.hide(resetContent: false)
					}
				)
				.zIndex((inspector.isPresented || pendingPanelOpen == .inspector) ? 6 : 4)
			}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.ignoresSafeArea(edges: [.top, .bottom])
        .toolbarBackground(.hidden, for: .windowToolbar)
        .environmentObject(inspector)
		.onChange(of: selection) { _, _ in
			isNavigationPresented = false
			inspector.hide()
		}
		.onChange(of: isNavigationPresented) { _, isPresented in
			guard pendingPanelOpen == nil else { return }
			guard isPresented, inspector.isPresented else { return }
			// If inspector is already open, collapse it first before opening nav.
			coordinatePanelTransition(open: .navigation)
		}
		.onChange(of: inspector.isPresented) { _, isPresented in
			guard pendingPanelOpen == nil else { return }
			guard isPresented, isNavigationPresented else { return }
			// If nav is already open, collapse it first before opening inspector.
			coordinatePanelTransition(open: .inspector)
		}
        .background(WindowFocusReader { window in
            windowFocusObserver.attach(window)
        })
		.onAppear {
			navigationWidth = clampNavigationWidth(CGFloat(storedNavigationWidth))
			inspectorWidth = clampInspectorWidth(CGFloat(storedInspectorWidth))
		}
		}

	private func clampNavigationWidth(_ width: CGFloat) -> CGFloat {
		max(navWidthRange.lowerBound, min(navWidthRange.upperBound, width))
	}

	private func clampInspectorWidth(_ width: CGFloat) -> CGFloat {
		max(inspectorWidthRange.lowerBound, min(inspectorWidthRange.upperBound, width))
	}

	@ViewBuilder
	private var detailView: some View {
		switch selection ?? .landing {
		case .landing:
			LandingView(model: model)
		case .search:
			SearchView(model: model)
		case .updates:
			UpdatesView(model: model)
		case .importApps:
			ImportView(model: model)
		case .settings:
			SettingsView(model: model)
		}
	}

	private func coordinatePanelTransition(open target: PendingPanelOpen) {
		pendingPanelOpen = target
		panelTransitionTask?.cancel()
		let collapseDelayNanoseconds: UInt64 = 16_000_000

		// Start collapse animation immediately for whichever panel is open.
		isNavigationPresented = false
		inspector.hide(resetContent: false)

		panelTransitionTask = Task { @MainActor in
			// Kick open almost immediately (next-frame cadence) so handoff feels snappy.
			try? await Task.sleep(nanoseconds: collapseDelayNanoseconds)
			guard pendingPanelOpen == target else { return }
			switch target {
			case .navigation:
				withAnimation(navPanelAnimation(expanding: true)) {
					isNavigationPresented = true
				}
			case .inspector:
				inspector.isPresented = true
			}
			pendingPanelOpen = nil
		}
	}

	/// Intercepts nav open requests while inspector is presented so we can
	/// run a single collapse-then-open transition without a brief pre-open flicker.
	private var navigationPresentationBinding: Binding<Bool> {
		Binding(
			get: { isNavigationPresented },
			set: { newValue in
				guard newValue != isNavigationPresented else { return }
				if newValue, inspector.isPresented {
					coordinatePanelTransition(open: .navigation)
				} else {
					isNavigationPresented = newValue
				}
			}
		)
	}

	@ViewBuilder
	private var navigationControlButton: some View {
		if useAlternativeOverlayToolbarControls {
			NavigationOverlayToolbarControl(
				isPresented: navigationPresentationBinding
			)
		} else {
			NavigationOverlayControl(
				isPresented: navigationPresentationBinding
			)
		}
	}

	@ViewBuilder
	private var inspectorControlButton: some View {
		if useAlternativeOverlayToolbarControls {
			InspectorOverlayToolbarControl(
				inspector: inspector,
				columnVisibility: $columnVisibility
			)
		} else {
			InspectorControl(
				inspector: inspector,
				columnVisibility: $columnVisibility
			)
		}
	}
}

struct JuiceGradient: View {
    var body: some View {
        LinearGradient.juice
    }
}

private func navPanelAnimation(expanding: Bool) -> Animation {
	expanding
		? .spring(response: 0.36, dampingFraction: 0.78)
		: .spring(response: 0.28, dampingFraction: 0.9)
}

private var outerControlMorphTransition: AnyTransition {
	.asymmetric(
		insertion: .modifier(
			active: OuterControlMorphState(opacity: 0, scale: 0.9, blur: 4, offsetY: 0),
			identity: OuterControlMorphState(opacity: 1, scale: 1, blur: 0, offsetY: 0)
		),
		removal: .modifier(
			active: OuterControlMorphState(opacity: 0, scale: 0.86, blur: 7, offsetY: 0),
			identity: OuterControlMorphState(opacity: 1, scale: 1, blur: 0, offsetY: 0)
		)
	)
}

private struct OuterControlMorphState: ViewModifier {
	let opacity: Double
	let scale: CGFloat
	let blur: CGFloat
	let offsetY: CGFloat

	func body(content: Content) -> some View {
		content
			.opacity(opacity)
			.scaleEffect(scale, anchor: .center)
			.blur(radius: blur)
			.offset(y: offsetY)
	}
}

private struct InspectorOverlayView: View {
	@Environment(\.colorScheme) private var colorScheme
    let content: AnyView
    let hasContent: Bool
    let isPresented: Bool
	let panelWidth: CGFloat
    let widthRange: ClosedRange<CGFloat>
	let isPinned: Binding<Bool>
    let onWidthChange: (CGFloat) -> Void
	let onResizeEnded: ((CGFloat) -> Void)?
	let onDismiss: () -> Void
	@State private var resizeStartWidth: CGFloat?
	@State private var isResizing = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		let glassState = GlassStateContext(colorScheme: colorScheme, isFocused: true)
        let clampedWidth = max(widthRange.lowerBound, min(widthRange.upperBound, panelWidth))
        let hiddenOffset = clampedWidth + 40

		ZStack(alignment: .topTrailing) {
			if isPresented {
				Color.clear
					.contentShape(Rectangle())
					.ignoresSafeArea()
					.onTapGesture {
						onDismiss()
					}
					.allowsHitTesting(true)
			}

				VStack(alignment: .leading, spacing: 0) {
					if hasContent {
						content
					} else {
						
					}
				}
				.transaction { transaction in
					if isResizing {
						transaction.animation = nil
					}
				}
				.padding(.horizontal, 0)
				.padding(.top, 0)
				.padding(.bottom, 0)
				.frame(width: clampedWidth)
				.frame(maxHeight: .infinity, alignment: .top)
				.background {
					Color.clear.glassCompatSurface(
						in: shape,
						style: .regular,
						context: glassState,
						fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
						fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
						surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: glassState)
					)
				}
			.clipShape(shape)
			.glassCompatBorder(in: shape, context: glassState, role: .standard)
			.overlay(alignment: .topLeading) {
				HStack(spacing: 4) {
					Button(action: onDismiss) {
						Image(systemName: "sidebar.right")
							.symbolVariant(.fill)
							.font(.system(size: 14, weight: .regular))
							.frame(width: 28, height: 22)
							.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
					.help("Collapse")

					Button {
						isPinned.wrappedValue.toggle()
					} label: {
						Image(systemName: isPinned.wrappedValue ? "pin.fill" : "pin")
							.font(.system(size: 12, weight: .regular))
							.frame(width: 28, height: 22)
							.rotationEffect(.degrees(isPinned.wrappedValue ? 0 : 30))
							.foregroundStyle(isPinned.wrappedValue ? Color.accentColor : .secondary)
						}
						.buttonStyle(.plain)
						.help(isPinned.wrappedValue ? "Unpin Inspector" : "Pin Inspector")
						.padding(.top, 2)
						.padding(.leading, -7)
					}
				.padding(.top, 8)
				.padding(.leading, 10)
				.opacity(isPresented ? 1 : 0)
				.allowsHitTesting(isPresented)
			}
			.overlay(
				ZStack {
					RadialGradient(
						colors: [GlassThemeTokens.textPrimary(for: glassState).opacity(0.35), .clear],
						center: .topLeading,
						startRadius: 0,
						endRadius: 10
					)
					RadialGradient(
						colors: [GlassThemeTokens.textPrimary(for: glassState).opacity(0.26), .clear],
						center: .bottomTrailing,
						startRadius: 0,
						endRadius: 10
					)
				}
				.clipShape(shape)
				.blendMode(.screen)
				.allowsHitTesting(false)
			)
				.glassCompatShadow(context: glassState, elevation: .panel)
				.overlay(alignment: .leading) {
					VStack {
						Spacer(minLength: 0)
						Capsule(style: .continuous)
							.fill(.secondary.opacity(0.22))
							.frame(width: 4, height: 72)
							.padding(.leading, 2)
							.contentShape(Rectangle())
							.gesture(
								DragGesture(minimumDistance: 0, coordinateSpace: .global)
									.onChanged { value in
										if resizeStartWidth == nil {
											resizeStartWidth = panelWidth
											isResizing = true
										}
										let baseWidth = resizeStartWidth ?? panelWidth
										let nextWidth = baseWidth - value.translation.width
										let clampedNextWidth = max(widthRange.lowerBound, min(widthRange.upperBound, nextWidth))
										onWidthChange(clampedNextWidth)
									}
									.onEnded { value in
										let baseWidth = resizeStartWidth ?? panelWidth
										let nextWidth = baseWidth - value.translation.width
										let finalWidth = max(widthRange.lowerBound, min(widthRange.upperBound, nextWidth))
										onWidthChange(finalWidth)
										onResizeEnded?(finalWidth)
										resizeStartWidth = nil
										isResizing = false
									}
							)
						Spacer(minLength: 0)
					}
				}
				.padding(.top, 8)
				.padding(.trailing, 8)
				.padding(.bottom, 8)
			// Composite into one layer so initial present animates panel + content together.
			.compositingGroup()
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
				.opacity(isPresented ? 1 : 0)
				.offset(x: isPresented ? 0 : hiddenOffset)
				.onTapGesture {
					// Consume taps inside the panel so they don't dismiss it.
				}
				.allowsHitTesting(isPresented)
				.animation(.easeInOut(duration: 0.18), value: isPresented)
		}
		.allowsHitTesting(isPresented)
    }
}

private struct NavigationOverlayView: View {
	@Binding var selection: NavigationItem?
	let panelWidth: CGFloat
	let widthRange: ClosedRange<CGFloat>
	let isPresented: Bool
	let onWidthChange: (CGFloat) -> Void
	let onResizeEnded: ((CGFloat) -> Void)?
	let onDismiss: () -> Void
	@State private var resizeStartWidth: CGFloat?
	@State private var isResizing = false

	var body: some View {
		let clampedWidth = max(widthRange.lowerBound, min(widthRange.upperBound, panelWidth))
		let hiddenOffset = clampedWidth + 40
		ZStack(alignment: .topLeading) {
			if isPresented {
				Color.clear
					.contentShape(Rectangle())
					.ignoresSafeArea()
					.onTapGesture {
						onDismiss()
					}
					.allowsHitTesting(true)
			}

			NavigationMenu(
				selection: $selection,
				onCollapse: { onDismiss() },
				panelWidth: clampedWidth
			)
				.transaction { transaction in
					if isResizing {
						transaction.animation = nil
					}
				}
				.overlay(alignment: .trailing) {
					VStack {
						Spacer(minLength: 0)
						Capsule(style: .continuous)
							.fill(.secondary.opacity(0.22))
							.frame(width: 4, height: 72)
							.padding(.trailing, 2)
							.contentShape(Rectangle())
							.gesture(
								DragGesture(minimumDistance: 0, coordinateSpace: .global)
									.onChanged { value in
										if resizeStartWidth == nil {
											resizeStartWidth = panelWidth
											isResizing = true
										}
										let baseWidth = resizeStartWidth ?? panelWidth
										let nextWidth = baseWidth + value.translation.width
										let clampedNextWidth = max(widthRange.lowerBound, min(widthRange.upperBound, nextWidth))
										onWidthChange(clampedNextWidth)
									}
									.onEnded { value in
										let baseWidth = resizeStartWidth ?? panelWidth
										let nextWidth = baseWidth + value.translation.width
										let finalWidth = max(widthRange.lowerBound, min(widthRange.upperBound, nextWidth))
										onWidthChange(finalWidth)
										onResizeEnded?(finalWidth)
										resizeStartWidth = nil
										isResizing = false
									}
							)
						Spacer(minLength: 0)
					}
				}
				.padding(.leading, 8)
				.padding(.top, 8)
				.padding(.bottom, 8)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
					.opacity(isPresented ? 1 : 0)
					.offset(x: isPresented ? 0 : -hiddenOffset)
					.onTapGesture {
						// Consume taps inside the panel so they don't dismiss it.
					}
					.allowsHitTesting(isPresented)
					.animation(.easeInOut(duration: 0.18), value: isPresented)
		}
		.allowsHitTesting(isPresented)
	}
}

private struct NavigationOverlayControl: View {
	@Environment(\.colorScheme) private var colorScheme
	@Binding var isPresented: Bool
	@StateObject private var focusObserver = WindowFocusObserver()
	private let baseOpacity: Double = 0.85
	private let hoverOpacity: Double = 0.6
	private let pressedOpacity: Double = 0.5
	@Namespace private var controls

	private var iconOpacity: CGFloat {
		focusObserver.isFocused ? 0.9 : 0.3
	}

	var body: some View {
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer(spacing: 30) {
					HStack(spacing: 35) {
						NavigationGlassToolButton(
						icon: isPresented ? "chevron.left.square" : "chevron.right.square",
						iconOpacity: iconOpacity,
						baseOpacity: baseOpacity,
						hoverOpacity: hoverOpacity,
						pressedOpacity: pressedOpacity,
						focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7
						) {
							withAnimation(navPanelAnimation(expanding: !isPresented)) {
								isPresented.toggle()
							}
						}
					.glassEffect(.regular.interactive())
					.glassEffectUnion(id: "nav-button", namespace: controls)
					.modifier(
						PressableOpacity(
							baseOpacity: baseOpacity,
							hoverOpacity: hoverOpacity,
							pressedOpacity: pressedOpacity,
							focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7
						)
					)
				}
			}
			.background(WindowFocusReader { focusObserver.attach($0) })
			} else {
				Button {
					withAnimation(navPanelAnimation(expanding: !isPresented)) {
						isPresented.toggle()
					}
				} label: {
				Image(systemName: isPresented ? "chevron.left.square" : "chevron.right.square")
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(GlassThemeTokens.textPrimary(for: glassState).opacity(Double(iconOpacity)))
					.frame(width: 40, height: 36)
					.contentShape(Capsule())
			}
			.buttonStyle(.plain)
			.background(backgroundShape)
			.clipShape(Capsule())
			.overlay(
				Capsule()
					.stroke(
						GlassThemeTokens.borderColor(for: glassState, role: .strong),
						lineWidth: 1
					)
			)
			.glassCompatShadow(context: glassState, elevation: .panel)
			.background(WindowFocusReader { focusObserver.attach($0) })
			.modifier(
				PressableOpacity(
					baseOpacity: baseOpacity,
					hoverOpacity: hoverOpacity,
					pressedOpacity: pressedOpacity,
					focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7
				)
			)
		}
	}

	@ViewBuilder
	private var backgroundShape: some View {
		let shape = Capsule()
		if #available(macOS 26.0, iOS 26.0, *) {
			GlassEffectContainer {
				shape
					.fill(.clear)
					.glassEffect(.regular, in: shape)
			}
		} else {
			shape.fill(.ultraThinMaterial)
		}
	}
}

private struct NavigationOverlayToolbarControl: View {
	@Environment(\.colorScheme) private var colorScheme
	@Binding var isPresented: Bool
	@StateObject private var focusObserver = WindowFocusObserver()

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
		Button {
			withAnimation(navPanelAnimation(expanding: !isPresented)) {
				isPresented.toggle()
			}
		} label: {
			Image(systemName: isPresented ? "sidebar.left" : "sidebar.left")
				.symbolVariant(isPresented ? .fill : .none)
				.font(.system(size: 14, weight: .regular))
				.frame(width: 28, height: 22)
				.contentShape(shape)
		}
		.buttonStyle(.plain)
		.background {
			Color.clear
				.glassCompatSurface(
					in: shape,
					style: .clear,
					context: glassState,
					fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
					fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
					surfaceOpacity: 1
				)
		}
		.clipShape(shape)
		.glassCompatBorder(in: shape, context: glassState, role: .standard)
		.glassCompatShadow(context: glassState, elevation: .small)
		.background(WindowFocusReader { focusObserver.attach($0) })
	}
}

private struct InspectorOverlayToolbarControl: View {
	@Environment(\.colorScheme) private var colorScheme
	@ObservedObject var inspector: InspectorCoordinator
	@Binding var columnVisibility: NavigationSplitViewVisibility
	@StateObject private var focusObserver = WindowFocusObserver()
	@State private var showQueueBadge = false
	@State private var badgeScale: CGFloat = 0.6
	@State private var badgeOffset: CGFloat = 6
	@State private var badgeOpacity: Double = 0
	@State private var badgeTask: Task<Void, Never>?
	@State private var attentionScale: CGFloat = 1
	@State private var attentionRotation: Double = 0

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
	}

	var body: some View {
		let _ = columnVisibility
		let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
		return ZStack(alignment: .topTrailing) {
			Button {
				withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
					if inspector.isPresented {
						inspector.hide(resetContent: false)
					} else {
						inspector.isPresented = true
					}
				}
			} label: {
				Image(systemName: inspector.isPresented ? "sidebar.right" : "sidebar.right")
					.symbolVariant(inspector.isPresented ? .fill : .none)
					.font(.system(size: 14, weight: .regular))
					.frame(width: 28, height: 22)
					.contentShape(shape)
			}
			.buttonStyle(.plain)
			.background {
				Color.clear
					.glassCompatSurface(
						in: shape,
						style: .clear,
						context: glassState,
						fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
						fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
						surfaceOpacity: 1
					)
			}
			.clipShape(shape)
			.glassCompatBorder(in: shape, context: glassState, role: .standard)
			.glassCompatShadow(context: glassState, elevation: .small)
			.background(WindowFocusReader { focusObserver.attach($0) })
			queueAddBadge
		}
		.scaleEffect(attentionScale)
		.rotationEffect(.degrees(attentionRotation))
		.onChange(of: inspector.queueAddCounter) { _, _ in
			triggerQueueBadge()
		}
		.onChange(of: inspector.queueAddAttentionCounter) { _, _ in
			triggerInspectorAttention()
		}
	}

	private var queueAddBadge: some View {
		let badgeCount = max(1, inspector.queueAddLastIncrement)
		let textColor: Color = colorScheme == .light ? .white : .black
		return Group {
			if showQueueBadge {
				Text("+\(badgeCount)")
					.font(.system(size: 12, weight: .bold))
					.foregroundStyle(textColor)
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(
						Capsule()
							.fill(Color.accentColor)
							.glassCompatShadow(context: glassState, elevation: .small)
					)
					.scaleEffect(badgeScale)
					.opacity(badgeOpacity)
					.offset(x: 4, y: badgeOffset)
					.allowsHitTesting(false)
			}
		}
	}

	private func triggerQueueBadge() {
		badgeTask?.cancel()
		showQueueBadge = true
		badgeScale = 0.6
		badgeOffset = 15
		badgeOpacity = 0
		withAnimation(.easeOut(duration: 0.16)) {
			badgeOpacity = 1
			badgeScale = 1.15
			badgeOffset = 2
		}
		withAnimation(.easeInOut(duration: 0.14).delay(0.16)) {
			badgeScale = 1.0
		}
		withAnimation(.easeIn(duration: 0.6).delay(0.25)) {
			badgeOpacity = 0
			badgeOffset = -16
		}
		badgeTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 900_000_000)
			showQueueBadge = false
		}
	}

	private func triggerInspectorAttention() {
		attentionScale = 1
		attentionRotation = 0

		withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) {
			attentionScale = 1.12
			attentionRotation = -3
		}

		withAnimation(.easeInOut(duration: 0.09).delay(0.1)) {
			attentionRotation = 3
		}

		withAnimation(.easeInOut(duration: 0.09).delay(0.19)) {
			attentionRotation = -1.5
		}

		withAnimation(.spring(response: 0.28, dampingFraction: 0.72).delay(0.28))
		{
			attentionScale = 1
			attentionRotation = 0
		}
	}
}

@available(macOS 26.0, *)
private struct NavigationGlassToolButton: View {
	@Environment(\.colorScheme) private var colorScheme
	let icon: String
	let iconOpacity: CGFloat
	let baseOpacity: Double
	let hoverOpacity: Double
	let pressedOpacity: Double
	let focusMultiplier: Double
	let action: () -> Void
	@State private var isHovered = false
	@State private var isPressed = false

	private var currentOpacity: Double {
		let base = isPressed ? pressedOpacity : (isHovered ? hoverOpacity : baseOpacity)
		return base * focusMultiplier
	}

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusMultiplier >= 0.99,
			isEnabled: true,
			isHovered: isHovered,
			isPressed: isPressed
		)
	}

	@ViewBuilder
	private var glowBackground: some View {
		if isHovered && !isPressed {
			let glowColor: Color = .primary
			Circle()
				.fill(
					RadialGradient(
						colors: [glowColor.opacity(0.1), .clear],
						center: .center,
						startRadius: 5,
						endRadius: 20
					)
				)
				.blur(radius: 3)
		}
		if isPressed {
			let glowColor: Color = .primary
			Circle()
				.fill(
					RadialGradient(
						colors: [glowColor.opacity(0.2), .clear],
						center: .center,
						startRadius: 5,
						endRadius: 30
					)
				)
				.blur(radius: 3)
		}
	}

	private var pressGesture: some Gesture {
		DragGesture(minimumDistance: 0)
			.onChanged { _ in
				if !isPressed { isPressed = true }
			}
			.onEnded { _ in
				isPressed = false
				action()
			}
	}

	private var buttonLabel: some View {
		ZStack {
			Image(systemName: icon)
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(Color(.labelColor.withAlphaComponent(iconOpacity)))
				.opacity(currentOpacity)
				.animation(.easeInOut(duration: 0.12), value: isHovered)
		}
		.frame(width: 12, height: 24)
	}

	var body: some View {
		let shadow = GlassThemeTokens.shadow(for: glassState, elevation: .card)
		Button(action: action) {
			buttonLabel
		}
		.background { glowBackground }
		.overlay(Color.primary.opacity(0.001))
		.modifier(ButtonStyleAvailabilityModifier())
		.controlSize(.large)
		.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
		.onHover { hovering in
			isHovered = hovering
		}
		.gesture(pressGesture)
	}
}

struct PlaceholderView: View {
	@Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String

    var body: some View {
		let context = GlassStateContext(colorScheme: colorScheme, isFocused: true)
		let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 44, weight: .bold))
            Text(subtitle)
                .font(.system(size: 16, weight: .semibold))
				.foregroundStyle(GlassThemeTokens.textSecondary(for: context))
        }
		.foregroundStyle(GlassThemeTokens.textPrimary(for: context))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
			shape
				.fill(GlassThemeTokens.overlayColor(for: context, role: .standard))
				.overlay(
					shape.strokeBorder(
						GlassThemeTokens.borderColor(for: context, role: .standard)
					)
				)
				.padding(48)
        )
    }
}



#Preview("Landing") {
	
    ContentView(initialSelection: .landing)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 1200, height: 700)
}
#Preview("Search") {
    ContentView(initialSelection: .search)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 1200, height: 700)
}

#Preview("Updates") {
    ContentView(initialSelection: .updates)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 1200, height: 700)
}

#Preview("Import Apps") {
    ContentView(initialSelection: .importApps)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 1200, height: 700)
}

#Preview("Settings") {
    ContentView(initialSelection: .settings)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 1200, height: 700)
}
