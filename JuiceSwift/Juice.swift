import SwiftUI
import AppKit
import os
import Runtime

@main
struct Juice: App {
    @StateObject private var catalog = LocalCatalog()
    @State private var hasBootstrapped = false
	
	let logPrefix = "Juice"
	let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "Juice",
		category: "OnLoaded"
	)
	
    var body: some Scene {
        WindowGroup {
            ContentView()
                //.frame(minWidth: 1150, minHeight: 600)
				.frame(minWidth: 700, minHeight: 600)
                .background(WindowConfigurator())
                .environmentObject(catalog)
                .task {
                    guard !hasBootstrapped else { return }
                    hasBootstrapped = true
                    await bootstrapApp()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }

    @MainActor
    private func bootstrapApp() async {
		let settings = SettingsStore().load()
		await Runtime.Config.applySettings(settings)
    }
}


struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = ObservingView()
        view.applyConfig()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ObservingView)?.applyConfig()
    }

    @MainActor private final class ObservingView: NSView {
        private var observers: [NSObjectProtocol] = []
        private weak var configuredWindow: NSWindow?
        private var trafficLightRelativeOffsets: (mini: CGPoint, zoom: CGPoint)?
        // Adjust these to tune the traffic-light insets from the top-left titlebar edge.
        private let trafficLightLeadingInset: CGFloat = 20
        private let trafficLightTopInset: CGFloat = 20

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if configuredWindow !== window {
                configuredWindow = window
                trafficLightRelativeOffsets = nil
            }
            applyConfig()
            startObserving()
        }

        @MainActor deinit {
            stopObserving()
        }

        func applyConfig() {
            guard let window = self.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
            applyTrafficLightInsets(in: window)
        }

        private func applyTrafficLightInsets(in window: NSWindow) {
            guard
                let close = window.standardWindowButton(.closeButton),
                let mini = window.standardWindowButton(.miniaturizeButton),
                let zoom = window.standardWindowButton(.zoomButton),
                let container = close.superview
            else {
                return
            }

            if trafficLightRelativeOffsets == nil {
                trafficLightRelativeOffsets = (
                    mini: CGPoint(
                        x: mini.frame.minX - close.frame.minX,
                        y: mini.frame.minY - close.frame.minY
                    ),
                    zoom: CGPoint(
                        x: zoom.frame.minX - close.frame.minX,
                        y: zoom.frame.minY - close.frame.minY
                    )
                )
            }

            let closeY: CGFloat
            if container.isFlipped {
                closeY = trafficLightTopInset
            } else {
                closeY = max(0, container.bounds.height - close.frame.height - trafficLightTopInset)
            }

            close.setFrameOrigin(CGPoint(x: trafficLightLeadingInset, y: closeY))

            if let offsets = trafficLightRelativeOffsets {
                mini.setFrameOrigin(
                    CGPoint(
                        x: trafficLightLeadingInset + offsets.mini.x,
                        y: closeY + offsets.mini.y
                    )
                )
                zoom.setFrameOrigin(
                    CGPoint(
                        x: trafficLightLeadingInset + offsets.zoom.x,
                        y: closeY + offsets.zoom.y
                    )
                )
            }
        }

        private func startObserving() {
            stopObserving()
            guard let window = self.window else { return }
            let center = NotificationCenter.default
            let names: [NSNotification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didBecomeMainNotification
            ]
            observers = names.map { name in
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        self?.applyConfig()
                    }
                }
            }
        }

        private func stopObserving() {
            let center = NotificationCenter.default
            for token in observers { center.removeObserver(token) }
            observers.removeAll()
        }
    }
}

actor Runtime {

	private let fallbackEnvironment = UemEnvironment()
	private(set) var environments: [UemEnvironment]
	private(set) var activeEnvironment: UemEnvironment
	private(set) var activeEnvironmentUuid: String?

	// Expose a Singleton like instance here
	static let Config = Runtime()

	private init() {
		self.environments = [fallbackEnvironment]
		self.activeEnvironment = fallbackEnvironment
		self.activeEnvironmentUuid = nil
	}

	func applySettings(_ settings: SettingsStore.SettingsState) {
		let incoming = settings.uemEnvironments.isEmpty ? [fallbackEnvironment] : settings.uemEnvironments
		self.environments = incoming
		self.activeEnvironmentUuid = settings.activeEnvironmentUuid
		self.activeEnvironment = resolveActiveEnvironment(
			environments: incoming,
			activeUuid: settings.activeEnvironmentUuid
		)
	}

	func updateActiveEnvironment(uuid: String?) {
		self.activeEnvironmentUuid = uuid
		self.activeEnvironment = resolveActiveEnvironment(
			environments: environments,
			activeUuid: uuid
		)
	}

	func updateEnvironments(_ updated: [UemEnvironment], activeUuid: String?) {
		let incoming = updated.isEmpty ? [fallbackEnvironment] : updated
		self.environments = incoming
		self.activeEnvironmentUuid = activeUuid
		self.activeEnvironment = resolveActiveEnvironment(
			environments: incoming,
			activeUuid: activeUuid
		)
	}

	func currentActiveEnvironment() async -> UemEnvironment {
		activeEnvironment
	}

	private func resolveActiveEnvironment(
		environments: [UemEnvironment],
		activeUuid: String?
	) -> UemEnvironment {
		guard let activeUuid, !activeUuid.isEmpty else {
			return environments.first ?? fallbackEnvironment
		}
		return environments.first(where: { $0.orgGroupUuid == activeUuid })
			?? environments.first
			?? fallbackEnvironment
	}

	//Not used but good to refer back to:

	// Mutable state
	private var settings: [String: Any] = [:]

	// Writes are automatically thread-safe in an actor
	func update(key: String, value: Any) {
		settings[key] = value
	}

	// Reads must be awaited when called from outside the actor
	func get(key: String) -> Any? {
		return settings[key]
	}

}
