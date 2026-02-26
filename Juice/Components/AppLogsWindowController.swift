#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class AppLogsWindowController: NSObject, NSWindowDelegate {
	static let shared = AppLogsWindowController()

	private var window: NSWindow?

	private override init() {}

	func show() {
		if let window {
			window.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
			return
		}

		let hosting = NSHostingController(rootView: AppLogsWindowView())
		let newWindow = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 900, height: 540),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		newWindow.title = "Juice Logs"
		newWindow.contentViewController = hosting
		newWindow.isReleasedWhenClosed = false
		newWindow.center()
		newWindow.delegate = self
		newWindow.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
		window = newWindow
	}

	func windowWillClose(_ notification: Notification) {
		if let closingWindow = notification.object as? NSWindow, closingWindow == window {
			window = nil
		}
	}
}
#endif
