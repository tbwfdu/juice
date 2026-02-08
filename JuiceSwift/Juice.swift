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

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
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
        }

        private func startObserving() {
            stopObserving()
            guard let window = self.window else { return }
            let center = NotificationCenter.default
            let names: [NSNotification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didBecomeMainNotification,
                NSWindow.didResizeNotification
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
