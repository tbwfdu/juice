import SwiftUI

struct ContentView: View {
    @State private var selection: NavigationItem? = .landing
    private let model = PageViewData.instance
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isHoveringSidebar = false
    @ObservedObject private var glassPresenter = GlassWindowPresenter.shared

    init(initialSelection: NavigationItem? = .landing) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationMenu(selection: $selection)
                .onHover { hovering in isHoveringSidebar = hovering }
                .onChange(of: selection) { _, _ in
                    columnVisibility = .detailOnly
                }
        } detail: {
            ZStack(alignment: .top) {
                WindowGlassBackground()
                    .ignoresSafeArea()
                let currentSelection = selection ?? .landing
                let showHeader = currentSelection != .landing
                let useGradientBackground = currentSelection == .landing
                    || currentSelection == .search
                    || currentSelection == .updates
                    || currentSelection == .importApps
                    || currentSelection == .settings
                let contentTopPadding: CGFloat = {
                    guard showHeader else { return 0 }
                    return (currentSelection == .search || currentSelection == .updates || currentSelection == .importApps || currentSelection == .settings) ? 80 : 10
                }()
                if useGradientBackground {
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
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, contentTopPadding)
                if showHeader {
                    GradientHeaderBar(title: "Juice", backgroundStyle: useGradientBackground ? .clear : .gradient)
                        .zIndex(1)
                }
                if glassPresenter.isPresenting {
                    WindowBlurOverlay()
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isHoveringSidebar {
                    columnVisibility = .detailOnly
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 320)
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

@available(macOS 26.0, *)
struct ExpandableMenu: View {
    @State private var isExpanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 16) {
                if isExpanded {
                    Button("Camera", systemImage: "camera") { }
                        .glassEffect(.regular.interactive())
                        .glassEffectID("camera", in: namespace)

                    Button("Photos", systemImage: "photo") { }
                        .glassEffect(.regular.interactive())
                        .glassEffectID("photos", in: namespace)
                }

                Button {
                    withAnimation(.bouncy) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .glassEffectID("toggle", in: namespace)
            }
        }
    }
}

// Fallback for earlier macOS versions where GlassEffectContainer is unavailable
struct ExpandableMenu_PrebigSurFallback: View {
    @State private var isExpanded = false

    var body: some View {
        HStack(spacing: 16) {
            if isExpanded {
                Button("Camera", systemImage: "camera") { }
                Button("Photos", systemImage: "photo") { }
            }
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// Typealias to expose a single name `ExpandableMenu` across OS versions
@available(macOS, introduced: 13)
struct ExpandableMenu_AvailabilityAdapter: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            ExpandableMenu()
        } else {
            ExpandableMenu_PrebigSurFallback()
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 44, weight: .bold))
            Text(subtitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .padding(48)
        )
    }
}

#Preview("Landing") {
	
    ContentView(initialSelection: .landing)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 900, height: 600)
}
#Preview("Search") {
    ContentView(initialSelection: .search)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 900, height: 600)
}

#Preview("Updates") {
    ContentView(initialSelection: .updates)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 900, height: 600)
}

#Preview("Import Apps") {
    ContentView(initialSelection: .importApps)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 900, height: 600)
}

#Preview("Settings") {
    ContentView(initialSelection: .settings)
        .environmentObject(LocalCatalog(/* init with preview-safe data if needed */))
        .frame(width: 900, height: 600)
}

#Preview("Expandable Menu") {
    if #available(macOS 26.0, *) {
        ExpandableMenu()
    } else {
        ExpandableMenu_PrebigSurFallback()
    }
}

#Preview("Expandable Menu over Gradient") {
	ZStack {
		JuiceGradient()
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.ignoresSafeArea()

		if #available(macOS 26.0, *) {
			ExpandableMenu()
		} else {
			ExpandableMenu_PrebigSurFallback()
		}
	}
	.frame(width: 600, height: 300)
}

