import SwiftUI

struct ContentView: View {
    private let landingBackgroundStyle = JuiceBackgroundStyle.v1
    private let nonLandingBackgroundStyle = JuiceBackgroundStyle.v2

    @Environment(\.colorScheme) private var colorScheme
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
				return (currentSelection == .search || currentSelection == .updates || currentSelection == .importApps || currentSelection == .settings) ? 80 : 10
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

					let navOffset: CGFloat = isNavigationPresented ? (navigationWidth - 5) : 0
					let navControlLeadingInset: CGFloat = 84
					let navExpandedExtraInset: CGFloat = isNavigationPresented ? 2 : 0
					HStack {
						NavigationOverlayControl(isPresented: navigationPresentationBinding)
							.padding(.top, 8)
							.padding(.leading, navControlLeadingInset + navOffset + navExpandedExtraInset)
						Spacer()
					}
				.zIndex(99)

			// Floating Inspector Control
			if currentSelection != .landing && currentSelection != .settings {
				let inspectorOffset: CGFloat = inspector.isPresented ? (inspectorWidth - 5) : 0
				HStack {
					Spacer()
					InspectorControl(inspector: inspector, columnVisibility: $columnVisibility)
						.padding(.top, 8)
						.padding(.trailing, 16 + inspectorOffset)
				}
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
					isPresented: isNavigationPresented,
				onWidthChange: { newWidth in
					navigationWidth = newWidth
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
				widthRange: 400...500,
				onWidthChange: { newWidth in
					inspectorWidth = newWidth
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
        .overlay {
			let glassState = GlassStateContext(
				colorScheme: colorScheme,
				isFocused: windowFocusObserver.isFocused
			)
            GlassThemeTokens.windowBackgroundBase(for: glassState)
                .opacity(windowFocusObserver.isFocused ? 0 : (colorScheme == .light ? 0.10 : 0.12))
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
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
		let collapseDelayNanoseconds: UInt64 = 32_000_000

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
}

struct JuiceGradient: View {
    var body: some View {
        LinearGradient.juice
    }
}

private func navPanelAnimation(expanding: Bool) -> Animation {
	expanding
		? .spring(response: 0.52, dampingFraction: 0.72)
		: .spring(response: 0.40, dampingFraction: 0.86)
}

private struct InspectorOverlayView: View {
	@Environment(\.colorScheme) private var colorScheme
    let content: AnyView
    let hasContent: Bool
    let isPresented: Bool
    let widthRange: ClosedRange<CGFloat>
    let onWidthChange: (CGFloat) -> Void
	let onDismiss: () -> Void
    @State private var measuredWidth: CGFloat = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		let glassState = GlassStateContext(colorScheme: colorScheme, isFocused: true)
        let paddedWidth = measuredWidth > 0 ? (measuredWidth + 40) : widthRange.lowerBound
        let clampedWidth = max(widthRange.lowerBound, min(widthRange.upperBound, paddedWidth))
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
						.background(
							GeometryReader { proxy in
								Color.clear
									.preference(key: InspectorContentWidthKey.self, value: proxy.size.width)
							}
						)
				} else {
					VStack(alignment: .leading, spacing: 6) {
						Text("Inspector")
							.font(.system(size: 16, weight: .semibold))
						Text("Select an item to see details.")
							.font(.system(size: 12, weight: .medium))
							.foregroundStyle(.secondary)
					}
					.padding(.top, 6)
				}
			}
			.padding(20)
			.frame(width: clampedWidth)
			.frame(maxHeight: .infinity, alignment: .top)
			.background {
				Color.clear
					.glassCompatSurface(
						in: shape,
						style: .regular,
						context: glassState,
						fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
						fillOpacity: 0.40,
						surfaceOpacity: 0.90
					)
			}
			.clipShape(shape)
			.glassCompatBorder(in: shape, context: glassState, role: .standard)
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
			.padding(.top, 8)
			.padding(.trailing, 8)
			.padding(.bottom, 8)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
			.opacity(isPresented ? 1 : 0)
			.offset(x: isPresented ? 0 : hiddenOffset)
			.allowsHitTesting(isPresented)
			.animation(.easeInOut(duration: 0.25), value: isPresented)
			.onTapGesture {
				// Consume taps inside the panel so they don't dismiss it.
			}
		}
		.onPreferenceChange(InspectorContentWidthKey.self) { newWidth in
			guard newWidth > 0 else { return }
			if newWidth != measuredWidth {
				measuredWidth = newWidth
			}
			let nextWidth = max(widthRange.lowerBound, min(widthRange.upperBound, newWidth + 40))
			onWidthChange(nextWidth)
		}
    }
}

private struct InspectorContentWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private struct NavigationOverlayView: View {
	@Binding var selection: NavigationItem?
	let isPresented: Bool
	let onWidthChange: (CGFloat) -> Void
	let onDismiss: () -> Void
	@State private var measuredWidth: CGFloat = 280

	var body: some View {
		let hiddenOffset = measuredWidth + 40
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

			NavigationMenu(selection: $selection)
				.padding(.leading, 8)
				.padding(.top, 8)
				.padding(.bottom, 8)
				.background(
					GeometryReader { proxy in
						Color.clear
							.preference(key: NavigationOverlayWidthKey.self, value: proxy.size.width)
					}
				)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
					.opacity(isPresented ? 1 : 0)
					.offset(x: isPresented ? 0 : -hiddenOffset)
					.allowsHitTesting(isPresented)
					.animation(.easeInOut(duration: 0.25), value: isPresented)
					.onTapGesture {
						// Consume taps inside the panel so they don't dismiss it.
					}
		}
		.onPreferenceChange(NavigationOverlayWidthKey.self) { newWidth in
			guard newWidth > 0 else { return }
			if newWidth != measuredWidth {
				measuredWidth = newWidth
			}
			onWidthChange(newWidth)
		}
	}
}

private struct NavigationOverlayWidthKey: PreferenceKey {
	static let defaultValue: CGFloat = 280
	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		let next = nextValue()
		if next > 0 {
			value = next
		}
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
