import SwiftUI

struct ContentView: View {
    private let landingBackgroundStyle = JuiceBackgroundStyle.v1
    private let nonLandingBackgroundStyle = JuiceBackgroundStyle.v2

    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: NavigationItem? = .landing
    private let model = PageViewData.instance
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isHoveringSidebar = false
    @ObservedObject private var glassPresenter = GlassWindowPresenter.shared
	@StateObject private var inspector = InspectorCoordinator()
    @StateObject private var windowFocusObserver = WindowFocusObserver()
    @State private var inspectorWidth: CGFloat = 400

    init(initialSelection: NavigationItem? = .search) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationMenu(selection: $selection)
                .onHover { hovering in isHoveringSidebar = hovering }
                .onChange(of: selection) { _, _ in
                    columnVisibility = .detailOnly
					inspector.hide()
                }
				
        } detail: {
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
                .zIndex(4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isHoveringSidebar {
                    columnVisibility = .detailOnly
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: [.top, .leading, .bottom])
        }
        .onChange(of: columnVisibility) { _, newValue in
            if newValue == .all {
                inspector.hide()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 350)
        .environmentObject(inspector)
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

}

struct JuiceGradient: View {
    var body: some View {
        LinearGradient.juice
    }
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
