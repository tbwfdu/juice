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
				.frame(minWidth: 650, minHeight: 600)
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
        //let _ = await UEMService.instance.getOrgGroupUuid()
        //let allApps: [UemApplication?] = await UEMService.instance.getAllApps()
		//printAsJSON(allApps)
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

	private let environment1 = UemEnvironment(
		id: UUID(),
		friendlyName: "CN1831 UAT",
		uemUrl: "https://as1831.awmdm.com",
		clientId: "004650ae8aaf4ac69967fe8c03d6aab6",
		clientSecret: "C7EC752B0774BF0658E441B0A0968FF9",
		oauthRegion: "https://uat.uemauth.workspaceone.com",
		orgGroupName: "DropbearLabs - UAT",
		orgGroupId: "1418",
		orgGroupUuid: "94e8fd6d-cb42-4692-bde0-3cbb9249ee6a"
	)

	let environments: [UemEnvironment]
	let activeEnvironment: UemEnvironment

	// Expose a Singleton like instance here
	static let Config = Runtime()

	private init() {
		self.environments = [environment1]
		self.activeEnvironment = environment1
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
