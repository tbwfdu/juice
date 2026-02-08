import SwiftUI
import AppKit

// Consolidated inspector presentation/coordinator and floating controls.
// Used by: ContentView and all page views that render inspector content.

@MainActor
final class GlassWindowPresenter: ObservableObject {
	// MARK: - Singleton

	static let shared = GlassWindowPresenter()

	private var controllers: [String: GlassWindowController] = [:]
	@Published private(set) var isPresenting = false
	private let shadowPadding: CGFloat = 12
	private let shadowBottomPadding: CGFloat = 20
	private var contentCenterOffset: CGFloat {
		(shadowBottomPadding - shadowPadding) / 2
	}

	// MARK: - Window Lifecycle

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

final class InspectorCoordinator: ObservableObject {
	@Published var isPresented = false
	@Published var hasContent = false
	@Published var content: AnyView = AnyView(EmptyView())
	@Published var isPinned = false
	@Published private(set) var queueAddCounter: Int = 0

	func show<Content: View>(_ content: Content) {
		withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
			self.content = AnyView(content)
			hasContent = true
			isPresented = true
		}
	}

	func hide(resetContent: Bool = true) {
		withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
			isPresented = false
			isPinned = false
			if resetContent {
				content = AnyView(EmptyView())
				hasContent = false
			}
		}
	}

	func notifyQueueAdded() {
		queueAddCounter += 1
	}
}

@available(macOS 26.0, *)
private struct GlassToolButton: View {
	@Environment(\.colorScheme) private var colorScheme
	let icon: String
	let iconOpacity: CGFloat
	let baseOpacity: Double
	let hoverOpacity: Double
	let pressedOpacity: Double
	let focusMultiplier: Double
	let size: String?
	let action: () -> Void
	@State private var isHovered = false
	@State private var isPressed = false

    init(
        icon: String,
        iconOpacity: CGFloat,
        baseOpacity: Double,
        hoverOpacity: Double,
        pressedOpacity: Double,
        focusMultiplier: Double,
        action: @escaping () -> Void,
        size: String? = nil
    ) {
        self.icon = icon
        self.iconOpacity = iconOpacity
        self.baseOpacity = baseOpacity
        self.hoverOpacity = hoverOpacity
        self.pressedOpacity = pressedOpacity
        self.focusMultiplier = focusMultiplier
        self.action = action
        self.size = size
    }

	private var currentOpacity: Double {
		let base =
			isPressed
			? pressedOpacity : (isHovered ? hoverOpacity : baseOpacity)
		return base * focusMultiplier
	}

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusMultiplier >= 0.99,
			isEnabled: true,
			isHovered: isHovered,
			isPressed: isPressed
		)
	}

    @ViewBuilder
    private var glowBackground: some View {
        if isHovered && !isPressed {
            let glowColor: Color = .primary
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 20
                    )
                )
                .blur(radius: 3)
        }
        if isPressed {
            let glowColor: Color = .primary
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 30
                    )
                )
                .blur(radius: 3)
        }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isPressed { isPressed = true }
            }
            .onEnded { _ in
                isPressed = false
                self.action()
            }
    }

    private var buttonLabel: some View {
        ZStack {
            Image(systemName: icon)
				.font(size == "small" ? .system(size: 11, weight: .regular) : .system(size: 16, weight: .regular))
                .foregroundStyle(
                    Color(.labelColor.withAlphaComponent(iconOpacity))
                )
                .opacity(currentOpacity)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
		.frame(width: 12, height: 24)
    }

	var body: some View {
		let shadow = GlassThemeTokens.shadow(for: glassState, elevation: .card)
        Button(action: action) {
            buttonLabel
        }
        .background { glowBackground }
        .overlay(Color.primary.opacity(0.001))
        .modifier(ButtonStyleAvailabilityModifier())
		.controlSize(.large)
		.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        .onHover { hovering in
            isHovered = hovering
        }
        .gesture(pressGesture)
	}
}

struct InspectorControl: View {
	// MARK: - Inputs & State

	@Environment(\.colorScheme) private var colorScheme
	@ObservedObject var inspector: InspectorCoordinator
	@Binding var columnVisibility: NavigationSplitViewVisibility
	@StateObject private var focusObserver = WindowFocusObserver()
	private let baseOpacity: Double = 0.85
	private let hoverOpacity: Double = 0.6
	private let pressedOpacity: Double = 0.5
	@State private var showQueueBadge = false
	@State private var badgeScale: CGFloat = 0.6
	@State private var badgeOffset: CGFloat = 6
	@State private var badgeOpacity: Double = 0
	@State private var badgeTask: Task<Void, Never>?

	@Namespace var controls

	// MARK: - Body

	var body: some View {
		let _: CGFloat = 40.0
		let iconOpacity: CGFloat = focusObserver.isFocused ? 0.9 : 0.3
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
		if #available(macOS 26.0, iOS 26.0, *) {
			// Modern glass effect path.
			ZStack(alignment: .topTrailing) {
				GlassEffectContainer(spacing: 30) {
					HStack(spacing: 35) {
						//BUTTON1
						GlassToolButton(
							icon: inspector.isPresented
								? "chevron.right.square" : "chevron.left.square",
							iconOpacity: iconOpacity,
							baseOpacity: baseOpacity,
							hoverOpacity: hoverOpacity,
							pressedOpacity: pressedOpacity,
							focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7,
							action: {
								withAnimation(
									.spring(response: 0.45, dampingFraction: 0.8)
								) {
									if inspector.isPresented {
										inspector.hide(resetContent: false)
									} else {
										inspector.isPresented = true
									}
								}

							}
						)
						.glassEffect(.regular.interactive())
						.glassEffectUnion(id: "button1", namespace: controls)
					}
				}
				queueAddBadge
			}
			.background(WindowFocusReader { focusObserver.attach($0) })
			.onChange(of: inspector.queueAddCounter) { _, _ in
				triggerQueueBadge()
			}
		} else {
			// Fallback container for platforms prior to macOS 26 / iOS 26
			ZStack(alignment: .topTrailing) {
				HStack(spacing: 10) {
					Button {
						withAnimation(.spring(response: 0.45, dampingFraction: 0.8))
						{
							if inspector.isPresented {
								inspector.hide(resetContent: false)
							} else {
								inspector.isPresented = true
							}
						}
					} label: {
						ZStack {
							Image(
								systemName: inspector.isPresented
									? "chevron.right.square" : "chevron.left.square"
							)
							.font(.system(size: 16, weight: .regular))
							.foregroundStyle(
								GlassThemeTokens.textPrimary(for: glassState)
									.opacity(Double(iconOpacity))
							)
						}
						.frame(width: 40, height: 36)
						.contentShape(Capsule())
					}
					.buttonStyle(.plain)
					.background(backgroundShape)
					.clipShape(Capsule())
					.overlay(
						Capsule()
							.stroke(
								GlassThemeTokens.borderColor(for: glassState, role: .strong),
								lineWidth: 1
							)
					)
					.glassCompatShadow(context: glassState, elevation: .panel)
					.background(WindowFocusReader { focusObserver.attach($0) })
					.modifier(
						PressableOpacity(
							baseOpacity: baseOpacity,
							hoverOpacity: hoverOpacity,
							pressedOpacity: pressedOpacity,
							focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7
						)
					)
				}
				queueAddBadge
			}
			.onChange(of: inspector.queueAddCounter) { _, _ in
				triggerQueueBadge()
			}
		}
	}

	private var queueAddBadge: some View {
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
		return Group {
			if showQueueBadge {
				Text("+1")
					.font(.system(size: 12, weight: .bold))
					.foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(
						Capsule()
							.fill(Color.accentColor)
							.glassCompatShadow(context: glassState, elevation: .small)
					)
					.scaleEffect(badgeScale)
					.opacity(badgeOpacity)
					.offset(x: 4, y: badgeOffset)
					.allowsHitTesting(false)
			}
		}
	}

	private func triggerQueueBadge() {
		badgeTask?.cancel()
		showQueueBadge = true
		badgeScale = 0.6
		badgeOffset = 6
		badgeOpacity = 0
		withAnimation(.easeOut(duration: 0.16)) {
			badgeOpacity = 1
			badgeScale = 1.15
			badgeOffset = 2
		}
		withAnimation(.easeInOut(duration: 0.14).delay(0.16)) {
			badgeScale = 1.0
		}
		withAnimation(.easeIn(duration: 0.6).delay(0.25)) {
			badgeOpacity = 0
			badgeOffset = -16
		}
		badgeTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 900_000_000)
			showQueueBadge = false
		}
	}

	@ViewBuilder
	private var backgroundShape: some View {
		let shape = Capsule()
		if #available(macOS 26.0, iOS 26.0, *) {
			GlassEffectContainer {
				shape
					.fill(.clear)
					.glassEffect(.regular, in: shape)
			}
		} else {
			shape.fill(.ultraThinMaterial)
		}
	}

	@ViewBuilder
	private func glassIconButton(symbol: String, size: CGFloat) -> some View {
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
		let shape = Circle()
		Button(action: {}) {
			Image(systemName: symbol)
				.font(.system(size: 22, weight: .semibold))
				.symbolRenderingMode(.monochrome)
				.foregroundStyle(GlassThemeTokens.textPrimary(for: glassState).opacity(0.9))
				.shadow(
					color: GlassThemeTokens.textPrimary(for: glassState).opacity(0.35),
					radius: 1,
					x: 0,
					y: 0.5
				)
				.frame(width: size, height: size)
				.background(shape.fill(GlassThemeTokens.controlBackgroundBase(for: glassState).opacity(0.22)))
				.clipShape(shape)
				.overlay(
					shape.stroke(
						GlassThemeTokens.borderColor(for: glassState, role: .standard),
						lineWidth: 1
					)
				)
				.compositingGroup()
				.drawingGroup(opaque: false, colorMode: .linear)
		}
		.buttonStyle(.plain)
		.contentShape(shape)
	}
}


// Helper protocol used only to avoid compile errors if WindowFocusReader provides an attachable observer in your project.
// If you already have WindowFocusObserver/WindowFocusReader in scope, you can remove this and wire to your real observer.
private protocol WindowFocusObservableProxy {
	var isFocused: Bool { get }
}


#Preview("InspectorControl") {
	@Previewable @State var columnVisibility: NavigationSplitViewVisibility = .all
    let inspector = InspectorCoordinator()
    return InspectorControl(inspector: inspector, columnVisibility: $columnVisibility)
        .padding()
		.frame(width: 100, height: 100)
		.preferredColorScheme(.light)
		.background(
			// A background is needed to see the blur/reflection effect
			LinearGradient(
				gradient: Gradient(colors: [.blue, .purple]),
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()
		)
}
