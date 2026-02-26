import SwiftUI
#if os(macOS)
import AppKit
#endif

// Consolidated background styling and window-focus visual helpers.
// Used by: ContentView and JuiceGradientGlassPreviewView.

// MARK: - Style Versioning

enum JuiceBackgroundStyleVersion: String {
    case v1
    case v2
}

struct JuiceBackgroundStyle {
    let version: JuiceBackgroundStyleVersion

    // Shared layout behavior
    let usesWordGlassMaskBackground: Bool
    let usesWindowGlassBase: Bool
    let headerBackgroundStyle: GradientHeaderBar.BackgroundStyle

    // Legacy gradient (v1)
    let showsLegacyTopGradient: Bool
    let legacyTopGradientHeight: CGFloat
    let legacyTopGradientMaskStops: [Gradient.Stop]

    // Word-glass style (v2)
    let wordText: String
    let wordTracking: CGFloat
    let wordMinSize: CGFloat
    let wordMaxSize: CGFloat
    let wordSizeFactor: CGFloat
    let gradientOpacityLight: Double
    let gradientOpacityDark: Double
    let wordOverlayOpacityLight: Double
    let wordOverlayOpacityDark: Double
    let wordGlowOpacityLight: Double
    let wordGlowOpacityDark: Double
    let vignetteTopOpacityLight: Double
    let vignetteTopOpacityDark: Double
    let vignetteBottomOpacityLight: Double
    let vignetteBottomOpacityDark: Double

    // Wallpaper treatment (preview/testing only)
    let desktopWallpaperOverlayLight: Double
    let desktopWallpaperOverlayDark: Double

    // v1 note: pre text-mask era styling from ContentView:
    // WindowGlassBackground + top JuiceGradient (height 500) with this fade mask.
    static let v1 = JuiceBackgroundStyle(
        version: .v1,
        usesWordGlassMaskBackground: false,
        usesWindowGlassBase: true,
        headerBackgroundStyle: .clear,
        showsLegacyTopGradient: true,
        legacyTopGradientHeight: 500,
        legacyTopGradientMaskStops: [
            .init(color: .white, location: 0.0),
            .init(color: .white, location: 0.55),
            .init(color: .white.opacity(0.7), location: 0.7),
            .init(color: .white.opacity(0.3), location: 0.82),
            .init(color: .white.opacity(0.0), location: 1.0),
        ],
        wordText: "",
        wordTracking: -20,
        wordMinSize: 180,
        wordMaxSize: 380,
        wordSizeFactor: 0.31,
        gradientOpacityLight: 0.86,
        gradientOpacityDark: 0.92,
        wordOverlayOpacityLight: 0.08,
        wordOverlayOpacityDark: 0.08,
        wordGlowOpacityLight: 0.02,
        wordGlowOpacityDark: 0.02,
        vignetteTopOpacityLight: 0.015,
        vignetteTopOpacityDark: 0.09,
        vignetteBottomOpacityLight: 0.008,
        vignetteBottomOpacityDark: 0.03,
        desktopWallpaperOverlayLight: 0.08,
        desktopWallpaperOverlayDark: 0.18
    )

    // v2 note: current test style with full Juice gradient and glass-masked word.
    static let v2 = JuiceBackgroundStyle(
        version: .v2,
        usesWordGlassMaskBackground: true,
        usesWindowGlassBase: false,
        headerBackgroundStyle: .clear,
        showsLegacyTopGradient: false,
        legacyTopGradientHeight: 500,
        legacyTopGradientMaskStops: v1.legacyTopGradientMaskStops,
        wordText: "",
        wordTracking: -10,
        wordMinSize: 180,
        wordMaxSize: 380,
        wordSizeFactor: 0.31,
        gradientOpacityLight: 0.98,
        gradientOpacityDark: 0.98,
        wordOverlayOpacityLight: 0.28,
        wordOverlayOpacityDark: 0.28,
        wordGlowOpacityLight: 0.12,
        wordGlowOpacityDark: 0.12,
        vignetteTopOpacityLight: 0.015,
        vignetteTopOpacityDark: 0.09,
        vignetteBottomOpacityLight: 0.008,
        vignetteBottomOpacityDark: 0.03,
        desktopWallpaperOverlayLight: 0.08,
        desktopWallpaperOverlayDark: 0.18
    )
}

// MARK: - Window Background Composition

struct WindowGlassBackground: View {
    @StateObject private var focusObserver = WindowFocusObserver()
    @StateObject private var motionObserver = WindowMotionObserver()

    var body: some View {
        let shape = Rectangle()
        ZStack {
            if motionObserver.isMoving {
                shape.fill(.ultraThinMaterial)
            } else {
                Group {
                    if #available(macOS 26.0, iOS 26.0, *) {
                        ZStack {
                            shape.fill(.ultraThinMaterial)
                            GlassEffectContainer {
                                shape
                                    .fill(Color.clear)
                                    .glassEffect(.regular, in: shape)
                            }
                        }
                    } else {
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    }
                }
            }
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.12)
        }
        .background(WindowFocusReader { window in
            focusObserver.attach(window)
            motionObserver.attach(window)
        })
    }
}

struct WindowBlurOverlay: View {
    var body: some View {
        let shape = Rectangle()
        ZStack {
            if #available(macOS 26.0, iOS 26.0, *) {
                GlassEffectContainer {
                    shape
                        .fill(Color.clear)
                        .glassEffect(.regular, in: shape)
                }
                GlassEffectContainer {
                    shape
                        .fill(Color.clear)
                        .glassEffect(.regular, in: shape)
                }
                .opacity(0.65)
            } else {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                VisualEffectView(material: .underWindowBackground, blendingMode: .withinWindow)
                    .opacity(0.6)
            }
            shape.fill(Color.black.opacity(0.12))
        }
        .opacity(0.85)
    }
}

@MainActor
final class WindowFocusObserver: NSObject, ObservableObject {
    @Published var isFocused: Bool = true

    private weak var window: NSWindow?

    func attach(_ window: NSWindow?) {
        guard self.window !== window else { return }
        stopObserving()
        self.window = window
        guard let window else { return }
        refreshFocus(using: window)
        startObserving(window)
    }

    private func startObserving(_ window: NSWindow) {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleFocusChange(_:)), name: NSWindow.didBecomeKeyNotification, object: window)
        center.addObserver(self, selector: #selector(handleFocusChange(_:)), name: NSWindow.didResignKeyNotification, object: window)
        center.addObserver(self, selector: #selector(handleFocusChange(_:)), name: NSWindow.didBecomeMainNotification, object: window)
        center.addObserver(self, selector: #selector(handleFocusChange(_:)), name: NSWindow.didResignMainNotification, object: window)
    }

    private func refreshFocus(using window: NSWindow) {
        isFocused = window.isKeyWindow || window.isMainWindow
    }

    @objc private func handleFocusChange(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        refreshFocus(using: window)
    }

    private func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }

    @MainActor deinit {
        stopObserving()
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct WindowFocusReader: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            onResolve(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            onResolve(nsView?.window)
        }
    }
}

#Preview {
    WindowGlassBackground()
        .frame(width: 600, height: 400)
}

struct JuiceGlassWordBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var focusObserver = WindowFocusObserver()
    @StateObject private var motionObserver = WindowMotionObserver()
    var style: JuiceBackgroundStyle = .v2
    var showsDesktopWallpaper: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let textSize = min(max(width * style.wordSizeFactor, style.wordMinSize), style.wordMaxSize)
            let hasWord = !style.wordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let textShape = Text(style.wordText)
				.font(.system(size: textSize, weight: .heavy))
                .tracking(style.wordTracking)
					.padding(.horizontal, 10)

            ZStack {
                if showsDesktopWallpaper {
                    MacOSDesktopWallpaperBackdrop(style: style)
                }

                backgroundGlassLayer

                if colorScheme == .dark {
                    darkModeBaseGradient
                        .opacity(style.gradientOpacityDark)
                        .ignoresSafeArea()

                    LinearGradient(
                        colors: [
                            Color("#FC642D").opacity(0.16),
                            Color("#DC1A78").opacity(0.15),
                            Color("#7A2BFF").opacity(0.10),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    // Keep a small amount of brand character without washing out dark mode.
                    RadialGradient(
                        colors: [
                            Color("#FC642D").opacity(0.24),
                            Color("#DC1A78").opacity(0.16),
                            .clear,
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 700
                    )
                    .ignoresSafeArea()

                } else {
                    LinearGradient.juice
                        .opacity(style.gradientOpacityLight)
                        .ignoresSafeArea()
                }

                if hasWord, !motionObserver.isMoving {
                    WindowGlassBackground()
                        .mask {
                            textShape
                                .padding(.horizontal, 18)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        }
                        .compositingGroup()
                        .blur(radius: 6.0)
                        .colorMultiply(colorScheme == .light ? .black : .white)
                        .opacity(style.version == .v2 ? 0.42 : 1.0)
                        .overlay {
                            textShape
                                .foregroundStyle(
                                    colorScheme == .light
                                        ? Color.black.opacity(style.wordOverlayOpacityLight)
                                        : Color.white.opacity(style.wordOverlayOpacityDark)
                                )
                                .padding(.horizontal, 18)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        }
                        .blur(radius: 3.4)

                    textShape
                        .foregroundStyle(
                            colorScheme == .light
                                ? Color.black.opacity(style.wordGlowOpacityLight)
                                : Color.white.opacity(style.wordGlowOpacityDark)
                        )
                        .blur(radius: 10.5)
                        .padding(.horizontal, 18)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(colorScheme == .dark ? style.vignetteTopOpacityDark : style.vignetteTopOpacityLight),
                                .clear,
                                Color.black.opacity(colorScheme == .dark ? style.vignetteBottomOpacityDark : style.vignetteBottomOpacityLight)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .background(WindowFocusReader { window in
            focusObserver.attach(window)
            motionObserver.attach(window)
        })
        .ignoresSafeArea()
    }

    private var darkModeBaseGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color("#2D3447"),
                Color("#2B2940"),
                Color("#222D46"),
                Color("#1A2238"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var backgroundGlassLayer: some View {
        let shape = Rectangle()
        if motionObserver.isMoving {
            shape.fill(.ultraThinMaterial)
        } else if #available(macOS 26.0, iOS 26.0, *) {
            GlassEffectContainer {
                shape
                    .fill(Color.clear)
                    .glassEffect(.clear, in: shape)
            }
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }
}

final class WindowMotionObserver: NSObject, ObservableObject {
    @Published private(set) var isMoving: Bool = false

    private weak var window: NSWindow?
    private var clearWorkItem: DispatchWorkItem?

    func attach(_ window: NSWindow?) {
        guard self.window !== window else { return }
        stopObserving()
        self.window = window
        startObserving(window)
    }

    private func startObserving(_ window: NSWindow?) {
        guard let window else { return }
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleMoveLikeEvent(_:)),
            name: NSWindow.willMoveNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(handleMoveLikeEvent(_:)),
            name: NSWindow.didMoveNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(handleMoveLikeEvent(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(handleMoveLikeEvent(_:)),
            name: NSWindow.willStartLiveResizeNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(handleEndResize(_:)),
            name: NSWindow.didEndLiveResizeNotification,
            object: window
        )
    }

    @objc private func handleMoveLikeEvent(_ notification: Notification) {
        setMovingTemporarily()
    }

    @objc private func handleEndResize(_ notification: Notification) {
        clearWorkItem?.cancel()
        isMoving = false
    }

    private func setMovingTemporarily() {
        isMoving = true
        clearWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.isMoving = false
        }
        clearWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    private func stopObserving() {
        NotificationCenter.default.removeObserver(self)
        clearWorkItem?.cancel()
        clearWorkItem = nil
        isMoving = false
    }

    deinit {
        stopObserving()
    }
}

private struct MacOSDesktopWallpaperBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    let style: JuiceBackgroundStyle

    var body: some View {
        #if os(macOS)
        if let image = wallpaperImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .saturation(1.05)
                .overlay {
                    Color.black.opacity(colorScheme == .dark ? style.desktopWallpaperOverlayDark : style.desktopWallpaperOverlayLight)
                }
                .ignoresSafeArea()
        } else {
            fallbackBackground
        }
        #else
        fallbackBackground
        #endif
    }

    #if os(macOS)
    private var wallpaperImage: NSImage? {
        let fileName = colorScheme == .dark ? "iMac Purple.heic" : "Sonoma.heic"
        let path = "/System/Library/Desktop Pictures/\(fileName)"
        if let image = NSImage(contentsOfFile: path) {
            return image
        }

        let desktopPicturesPath = "/System/Library/Desktop Pictures"
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: desktopPicturesPath),
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        let imageURL = urls.first { url in
            let ext = url.pathExtension.lowercased()
            return ext == "heic" || ext == "jpg" || ext == "jpeg" || ext == "png"
        }

        return imageURL.flatMap { NSImage(contentsOf: $0) }
    }
    #endif

    private var fallbackBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.14, green: 0.2, blue: 0.35),
                Color(red: 0.3, green: 0.22, blue: 0.4),
                Color(red: 0.12, green: 0.14, blue: 0.23)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
