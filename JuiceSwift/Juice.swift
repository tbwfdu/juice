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
        private var trafficLightCloseY: CGFloat?
        private var initialReapplyTask: Task<Void, Never>?
        // Adjust these to tune the traffic-light insets from the top-left titlebar edge.
        private let trafficLightLeadingInset: CGFloat = 20
        private let trafficLightTopInset: CGFloat = 20

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if configuredWindow !== window {
                configuredWindow = window
                trafficLightRelativeOffsets = nil
                trafficLightCloseY = nil
                initialReapplyTask?.cancel()
                stopObserving()
            }
            applyConfig()
            scheduleInitialReapplyPasses()
            startObserving()
        }

        @MainActor deinit {
            initialReapplyTask?.cancel()
            stopObserving()
        }

        func applyConfig() {
            guard let window = self.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            // Prevent dragging from any arbitrary point in the content area.
            // Keep native window movement behavior scoped to titlebar/standard drag regions.
            window.isMovableByWindowBackground = false
            window.isOpaque = false
            window.backgroundColor = .clear
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

            if trafficLightCloseY == nil {
                let initialCloseY: CGFloat
                if container.isFlipped {
                    initialCloseY = trafficLightTopInset
                } else {
                    initialCloseY = max(0, container.bounds.height - close.frame.height - trafficLightTopInset)
                }
                trafficLightCloseY = initialCloseY
            }
            let closeY = trafficLightCloseY ?? close.frame.minY

            // Keep this deterministic and non-animated so controls do not visibly jump.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                context.allowsImplicitAnimation = false

                close.setFrameOrigin(
                    CGPoint(
                        x: round(trafficLightLeadingInset),
                        y: round(closeY)
                    )
                )

                if let offsets = trafficLightRelativeOffsets {
                    mini.setFrameOrigin(
                        CGPoint(
                            x: round(trafficLightLeadingInset + offsets.mini.x),
                            y: round(closeY + offsets.mini.y)
                        )
                    )
                    zoom.setFrameOrigin(
                        CGPoint(
                            x: round(trafficLightLeadingInset + offsets.zoom.x),
                            y: round(closeY + offsets.zoom.y)
                        )
                    )
                }
            }
        }

        private func scheduleInitialReapplyPasses() {
            initialReapplyTask?.cancel()
            initialReapplyTask = Task { @MainActor [weak self] in
                // First couple of runloop/layout passes are where AppKit finalizes titlebar controls.
                self?.applyConfig()
                if let window = self?.window {
                    self?.applyTrafficLightInsets(in: window)
                }
                try? await Task.sleep(nanoseconds: 16_000_000)   // ~1 frame
                self?.applyConfig()
                if let window = self?.window {
                    self?.applyTrafficLightInsets(in: window)
                }
                try? await Task.sleep(nanoseconds: 90_000_000)   // post-layout settle
                self?.applyConfig()
                if let window = self?.window {
                    self?.applyTrafficLightInsets(in: window)
                }
            }
        }

        private func startObserving() {
            stopObserving()
            guard let window = self.window else { return }
            let center = NotificationCenter.default
            let names: [NSNotification.Name] = [
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didResizeNotification,
                NSWindow.didChangeScreenNotification
            ]
            observers = names.map { name in
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        self?.reapplyTrafficLightsIfStable()
                    }
                }
            }
        }

        private func stopObserving() {
            let center = NotificationCenter.default
            for token in observers {
                center.removeObserver(token)
            }
            observers.removeAll()
        }

        private func reapplyTrafficLightsIfStable() {
            guard let window = self.window else { return }
            guard window.inLiveResize == false else { return }
            guard window.contentView?.inLiveResize != true else { return }
            applyConfig()
            applyTrafficLightInsets(in: window)
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
