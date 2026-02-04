import SwiftUI

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
        Button(action: action) {
            buttonLabel
        }
        .background { glowBackground }
        .overlay(Color.primary.opacity(0.001))
        .modifier(ButtonStyleAvailabilityModifier())
		.controlSize(.large)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 5)
        .onHover { hovering in
            isHovered = hovering
        }
        .gesture(pressGesture)
	}
}

private struct ButtonStyleAvailabilityModifier: ViewModifier {
	func body(content: Content) -> some View {
		if #available(macOS 26.0, iOS 26.0, *) {
			return content.buttonStyle(.glass(.clear))
		} else {
			return content.buttonStyle(.plain)
		}
	}
}

private struct PressableOpacity: ViewModifier {
	let baseOpacity: Double
	let hoverOpacity: Double
	let pressedOpacity: Double
	let focusMultiplier: Double
	@State private var isHovered = false
	@State private var isPressed = false

	func body(content: Content) -> some View {
		let base =
			isPressed
			? pressedOpacity : (isHovered ? hoverOpacity : baseOpacity)
		return
			content
			.opacity(base * focusMultiplier)
			.onHover { hovering in
				isHovered = hovering
			}
			.gesture(
				DragGesture(minimumDistance: 0)
					.onChanged { _ in
						if !isPressed { isPressed = true }
					}
					.onEnded { _ in
						isPressed = false
					}
			)
	}
}

struct InspectorControl: View {
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

	var body: some View {
		let _: CGFloat = 40.0
		let iconOpacity: CGFloat = focusObserver.isFocused ? 0.9 : 0.3
		if #available(macOS 26.0, iOS 26.0, *) {
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
								(colorScheme == .light ? Color.black : Color.white)
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
							.stroke(Color.white.opacity(0.25), lineWidth: 1)
					)
					.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
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
		Group {
			if showQueueBadge {
				Text("+1")
					.font(.system(size: 12, weight: .bold))
					.foregroundStyle(Color.white)
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(
						Capsule()
							.fill(Color.accentColor)
							.shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
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
		let shape = Circle()
		Button(action: {}) {
			Image(systemName: symbol)
				.font(.system(size: 22, weight: .semibold))
				.symbolRenderingMode(.monochrome)
				.foregroundStyle(Color.black.opacity(0.9))
				.shadow(
					color: Color.white.opacity(0.35),
					radius: 1,
					x: 0,
					y: 0.5
				)
				.frame(width: size, height: size)
				.background(shape.fill(Color.white.opacity(0.22)))
				.clipShape(shape)
				.overlay(
					shape.stroke(Color.white.opacity(0.18), lineWidth: 1)
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
