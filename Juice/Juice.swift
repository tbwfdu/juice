import SwiftUI
import AppKit
import os
import Runtime

@main
struct Juice: App {
	static let mainWindowSceneID = "juice.main.window"
    @StateObject private var catalog = LocalCatalog()
	@StateObject private var appVisibility = AppVisibilityCoordinator.shared
    @State private var hasBootstrapped = false
	@NSApplicationDelegateAdaptor(JuiceAppDelegate.self) private var appDelegate
	
	let logPrefix = "Juice"
	let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "Juice",
		category: "OnLoaded"
	)
	
    var body: some Scene {
        WindowGroup(id: Self.mainWindowSceneID) {
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

		MenuBarExtra("Juice", image: "JuiceMenuBarIcon") { JuiceMenuBarContent() }
    }

    @MainActor
    private func bootstrapApp() async {
		let settingsStore = SettingsStore()
		do {
			try settingsStore.migrateEnvironmentSecretsIfNeeded()
		} catch {
			appLog(
				.error,
				"JuiceBootstrap",
				"Failed to migrate environment secrets to keychain: \(error.localizedDescription)"
			)
		}
		let settings = settingsStore.load()
		JuiceStyleConfig.shared.applyProminentTint(
			hex: settings.prominentButtonTintHex
		)
		settingsStore.syncWidgetFromStoredState()
		await Runtime.Config.applySettings(settings)
    }

}

private struct JuiceMenuBarContent: View {
	@Environment(\.openWindow) private var openWindow
	@ObservedObject private var appVisibility = AppVisibilityCoordinator.shared

	private var keepRunningMenuTitle: String {
		appVisibility.isKeepRunningEnabled ? "Keep running: On" : "Keep running: Off"
	}

	var body: some View {
		Button("Open Juice") {
			openWindow(id: Juice.mainWindowSceneID)
			AppVisibilityCoordinator.shared.restoreMainWindowFromMenuBar()
		}
		Toggle(
			keepRunningMenuTitle,
			isOn: Binding(
				get: { appVisibility.isKeepRunningEnabled },
				set: { newValue in
					appVisibility.setKeepRunningEnabled(newValue)
					AppVisibilityCoordinator.shared.handleKeepRunningPreferenceChanged(
						enabled: newValue
					)
				}
			)
		)
		.help(HelpText.Actions.keepRunning)
		Divider()
		Button("Quit Juice") {
			AppVisibilityCoordinator.shared.performExplicitQuit()
		}
	}
}

@MainActor
final class JuiceAppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		// Keep the process alive when windows close; explicit terminate paths still exit.
		return false
	}

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		if AppVisibilityCoordinator.shared.shouldAllowExplicitTermination() {
			return .terminateNow
		}
		if AppVisibilityCoordinator.shared.isKeepRunningEnabled {
			AppVisibilityCoordinator.shared.hideAppToMenuBarOnly()
			return .terminateCancel
		}
		return .terminateNow
	}
}

@MainActor
final class AppVisibilityCoordinator: ObservableObject {
	static let shared = AppVisibilityCoordinator()
	static let keepRunningDefaultsKey = "juice.keepRunningInMenuBar"

	@Published private(set) var keepRunningEnabled: Bool

	private init() {
		self.keepRunningEnabled = UserDefaults.standard.bool(forKey: Self.keepRunningDefaultsKey)
	}
	private var hasExplicitQuitRequest = false

	var isKeepRunningEnabled: Bool {
		keepRunningEnabled
	}

	func setKeepRunningEnabled(_ enabled: Bool) {
		keepRunningEnabled = enabled
		UserDefaults.standard.set(enabled, forKey: Self.keepRunningDefaultsKey)
	}

	func handleKeepRunningPreferenceChanged(enabled: Bool) {
		guard !enabled else { return }
		hasExplicitQuitRequest = false
		if NSApp.activationPolicy() != .regular {
			setDockVisibleMode()
		}
	}

	func requestExplicitQuit() {
		hasExplicitQuitRequest = true
	}

	func performExplicitQuit() {
		requestExplicitQuit()
		NSApp.terminate(nil)
	}

	func performOnboardingDeclineQuit() {
		requestExplicitQuit()
		NSApp.terminate(nil)
		Task { @MainActor in
			try? await Task.sleep(nanoseconds: 300_000_000)
			guard !NSRunningApplication.current.isTerminated else { return }
			_ = NSRunningApplication.current.forceTerminate()
		}
	}

	func shouldAllowExplicitTermination() -> Bool {
		if hasExplicitQuitRequest {
			hasExplicitQuitRequest = false
			return true
		}
		return false
	}

	func setDockVisibleMode() {
		_ = NSApp.setActivationPolicy(.regular)
	}

	func setMenuBarOnlyMode() {
		_ = NSApp.setActivationPolicy(.accessory)
	}

	func hideMainWindowToMenuBar(_ window: NSWindow) {
		guard isKeepRunningEnabled else { return }
		window.orderOut(nil)
		setMenuBarOnlyMode()
	}

	func hideAppToMenuBarOnly() {
		for window in NSApp.windows where !(window is NSPanel) {
			window.orderOut(nil)
		}
		setMenuBarOnlyMode()
	}

	func restoreMainWindowFromMenuBar() {
		setDockVisibleMode()
		NSApp.activate(ignoringOtherApps: true)
		guard let window = mainWindowCandidate else { return }
		if window.isMiniaturized {
			window.deminiaturize(nil)
		}
		window.makeKeyAndOrderFront(nil)
	}

	private var mainWindowCandidate: NSWindow? {
		if let keyWindow = NSApp.windows.first(where: { $0.isKeyWindow && !($0 is NSPanel) }) {
			return keyWindow
		}
		if let visibleWindow = NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) {
			return visibleWindow
		}
		return NSApp.windows.first(where: { !($0 is NSPanel) })
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
        private var trafficLightConstraints: [NSLayoutConstraint] = []
        private weak var trafficLightConstraintContainer: NSView?
        private var initialReapplyTask: Task<Void, Never>?
		private weak var closeButton: NSButton?
        // Adjust these to tune the traffic-light insets from the top-left titlebar edge.
        private let trafficLightLeadingInset: CGFloat = 20
        private let trafficLightTopInset: CGFloat = 20

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if configuredWindow !== window {
                configuredWindow = window
                trafficLightRelativeOffsets = nil
                NSLayoutConstraint.deactivate(trafficLightConstraints)
                trafficLightConstraints.removeAll()
                trafficLightConstraintContainer = nil
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
			installCloseButtonHandler(for: window)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            // Prevent dragging from any arbitrary point in the content area.
            // Keep native window movement behavior scoped to titlebar/standard drag regions.
            window.isMovableByWindowBackground = false
            window.isOpaque = false
            window.backgroundColor = .clear
        }

		private func installCloseButtonHandler(for window: NSWindow) {
			guard let button = window.standardWindowButton(.closeButton) else { return }
			if closeButton !== button {
				closeButton = button
			}
			button.target = self
			button.action = #selector(handleCloseButtonPressed(_:))
		}

		@objc
		private func handleCloseButtonPressed(_ sender: Any?) {
			guard let window = self.window else { return }
			if AppVisibilityCoordinator.shared.isKeepRunningEnabled {
				AppVisibilityCoordinator.shared.hideMainWindowToMenuBar(window)
				return
			}
			AppVisibilityCoordinator.shared.performExplicitQuit()
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

            if trafficLightConstraintContainer !== container {
                NSLayoutConstraint.deactivate(trafficLightConstraints)
                trafficLightConstraints.removeAll()
                trafficLightConstraintContainer = container
            }

            if trafficLightConstraints.isEmpty, let offsets = trafficLightRelativeOffsets {
                close.translatesAutoresizingMaskIntoConstraints = false
                mini.translatesAutoresizingMaskIntoConstraints = false
                zoom.translatesAutoresizingMaskIntoConstraints = false

                trafficLightConstraints = [
                    close.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: trafficLightLeadingInset),
                    close.topAnchor.constraint(equalTo: container.topAnchor, constant: trafficLightTopInset),
                    mini.leadingAnchor.constraint(equalTo: close.leadingAnchor, constant: offsets.mini.x),
                    mini.topAnchor.constraint(equalTo: close.topAnchor, constant: offsets.mini.y),
                    zoom.leadingAnchor.constraint(equalTo: close.leadingAnchor, constant: offsets.zoom.x),
                    zoom.topAnchor.constraint(equalTo: close.topAnchor, constant: offsets.zoom.y)
                ]
                NSLayoutConstraint.activate(trafficLightConstraints)
            }

            container.layoutSubtreeIfNeeded()
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
