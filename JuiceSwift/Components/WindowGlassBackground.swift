import SwiftUI
import AppKit

struct WindowGlassBackground: View {
    @StateObject private var focusObserver = WindowFocusObserver()

    var body: some View {
        let shape = Rectangle()
        let isFocused = focusObserver.isFocused
        ZStack {
            Group {
                if #available(macOS 26.0, iOS 26.0, *) {
                    ZStack {
                        if isFocused {
                            shape.fill(.ultraThinMaterial)
                        } else {
                            shape.fill(.ultraThinMaterial)
                                .opacity(0.25)
                        }
                        GlassEffectContainer {
                            shape
                                .fill(Color.clear)
                                .glassEffect(.regular, in: shape)
                        }
                        if !isFocused {
                            GlassEffectContainer {
                                shape
                                    .fill(Color.clear)
                                    .glassEffect(.regular, in: shape)
                            }
                            .opacity(0.35)
                        }
                    }
                } else {
                    VisualEffectView(
                        material: isFocused ? .hudWindow : .underWindowBackground,
                        blendingMode: .behindWindow
                    )
                    if !isFocused {
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .opacity(0.35)
                    }
                }
            }
            Color(nsColor: .windowBackgroundColor)
                .opacity(isFocused ? 0.5 : 0.12)
        }
        .background(WindowFocusReader { window in
            focusObserver.attach(window)
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
