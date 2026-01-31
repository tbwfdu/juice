import SwiftUI
import AppKit

@MainActor
final class GlassWindowPresenter: ObservableObject {
	static let shared = GlassWindowPresenter()

	private var controllers: [String: GlassWindowController] = [:]
	@Published private(set) var isPresenting = false
	private let shadowPadding: CGFloat = 12
	private let shadowBottomPadding: CGFloat = 20
	private var contentCenterOffset: CGFloat {
		(shadowBottomPadding - shadowPadding) / 2
	}

	func present(
		id: String,
		title: String = "",
		size: CGSize,
		content: AnyView,
		onClose: (() -> Void)? = nil
	) {
		let paddedSize = paddedContentSize(for: size)
		let paddedContent = paddedContentView(content, size: size)
		if let controller = controllers[id] {
			controller.update(
				content: paddedContent,
				size: paddedSize,
				title: title,
				shadowPadding: shadowPadding,
				shadowBottomPadding: shadowBottomPadding,
				onClose: onClose
			)
			controller.show()
			isPresenting = true
			return
		}

		let controller = GlassWindowController(
			content: paddedContent,
			size: paddedSize,
			title: title,
			shadowPadding: shadowPadding,
			shadowBottomPadding: shadowBottomPadding
		) { [weak self] in
			self?.controllers[id] = nil
			self?.isPresenting = !(self?.controllers.isEmpty ?? true)
			onClose?()
		}
		controllers[id] = controller
		isPresenting = true
		controller.show()
	}

	func dismiss(id: String) {
		guard let controller = controllers[id] else { return }
		controller.close()
		controllers[id] = nil
		isPresenting = !controllers.isEmpty
	}

	private func paddedContentView(_ content: AnyView, size: CGSize) -> AnyView {
		AnyView(
			content
				.frame(width: size.width, height: size.height)
				.padding(EdgeInsets(
					top: shadowPadding,
					leading: shadowPadding,
					bottom: shadowBottomPadding,
					trailing: shadowPadding
				))
		)
	}

	private func paddedContentSize(for size: CGSize) -> CGSize {
		CGSize(
			width: size.width + shadowPadding * 2,
			height: size.height + shadowPadding + shadowBottomPadding
		)
	}
}

@MainActor
private final class GlassWindowController: NSObject, NSWindowDelegate {
	private let hostingView: NSHostingView<AnyView>
	private let window: NSWindow
	private var onClose: (() -> Void)?
	private weak var parentWindow: NSWindow?
	private var shadowPadding: CGFloat
	private var shadowBottomPadding: CGFloat
	private var contentCenterOffset: CGFloat {
		(shadowBottomPadding - shadowPadding) / 2
	}

	init(content: AnyView, size: CGSize, title: String, shadowPadding: CGFloat, shadowBottomPadding: CGFloat, onClose: (() -> Void)?) {
		self.hostingView = NSHostingView(rootView: content)
		self.window = NSWindow(
			contentRect: NSRect(origin: .zero, size: size),
			styleMask: [.titled, .closable, .fullSizeContentView],
			backing: .buffered,
			defer: false
		)
		self.onClose = onClose
		self.shadowPadding = shadowPadding
		self.shadowBottomPadding = shadowBottomPadding
		super.init()

		window.title = title
		window.titleVisibility = .hidden
		window.titlebarAppearsTransparent = true
		window.isOpaque = false
		window.backgroundColor = .clear
		window.isMovable = false
		window.isMovableByWindowBackground = false
		window.isExcludedFromWindowsMenu = true
		window.collectionBehavior.insert(.transient)
		window.collectionBehavior.insert(.ignoresCycle)
		window.standardWindowButton(.closeButton)?.isHidden = true
		window.standardWindowButton(.miniaturizeButton)?.isHidden = true
		window.standardWindowButton(.zoomButton)?.isHidden = true
		window.hasShadow = false
		window.isReleasedWhenClosed = false
		window.delegate = self
		window.contentView = hostingView
		hostingView.wantsLayer = true
		hostingView.layer?.backgroundColor = NSColor.clear.cgColor
	}

	func update(
		content: AnyView,
		size: CGSize,
		title: String,
		shadowPadding: CGFloat,
		shadowBottomPadding: CGFloat,
		onClose: (() -> Void)?
	) {
		window.title = title
		hostingView.rootView = content
		window.setContentSize(size)
		self.shadowPadding = shadowPadding
		self.shadowBottomPadding = shadowBottomPadding
		self.onClose = onClose
	}

	func show() {
		NSApp.activate(ignoringOtherApps: true)
		centerOverParentWindow()
		window.makeKeyAndOrderFront(nil)
	}

	func close() {
		window.close()
	}

	func windowWillClose(_ notification: Notification) {
		if let parentWindow {
			parentWindow.removeChildWindow(window)
		}
		onClose?()
	}

	private func centerOverParentWindow() {
		guard let parentWindow = NSApp.mainWindow ?? NSApp.keyWindow else {
			window.center()
			return
		}

		self.parentWindow = parentWindow
		let parentFrame = parentWindow.frame
		let size = window.frame.size
		let origin = NSPoint(
			x: parentFrame.midX - size.width / 2,
			y: parentFrame.midY - size.height / 2 - contentCenterOffset
		)
		window.setFrameOrigin(origin)
		parentWindow.addChildWindow(window, ordered: .above)
	}
}
