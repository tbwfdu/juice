import SwiftUI

@available(macOS 26.0, *)
private struct GlassToolButton: View {
	let icon: String
	let iconOpacity: CGFloat
	let baseOpacity: Double
	let hoverOpacity: Double
	let pressedOpacity: Double
	let focusMultiplier: Double
	let size: String?
	let image: String?
	let buttonDiameter: CGFloat?
	let action: () -> Void
	@State private var isHovered = false
	@State private var isPressed = false
	@State private var wigglePhase = false
	@State private var wiggleTask: Task<Void, Never>?

    init(
        icon: String,
        iconOpacity: CGFloat,
        baseOpacity: Double,
        hoverOpacity: Double,
        pressedOpacity: Double,
        focusMultiplier: Double,
        action: @escaping () -> Void,
        size: String? = nil,
		image: String? = nil,
		buttonDiameter: CGFloat? = nil
    ) {
        self.icon = icon
        self.iconOpacity = iconOpacity
        self.baseOpacity = baseOpacity
        self.hoverOpacity = hoverOpacity
        self.pressedOpacity = pressedOpacity
        self.focusMultiplier = focusMultiplier
        self.action = action
        self.size = size
		self.image = image
		self.buttonDiameter = buttonDiameter
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
		return ZStack {
			if let imageName = image, !imageName.isEmpty {
				let wiggleAngle: Double = isPressed ? (wigglePhase ? 4 : -4) : 0
				let imageWidth: CGFloat = buttonDiameter.map { $0 * 0.8 } ?? 30
				let imageHeight: CGFloat = buttonDiameter.map { $0 * 1.25 } ?? 45
				let imageOffsetY: CGFloat = buttonDiameter.map { -0.06 * $0 } ?? -2
				let imagePadding: CGFloat = buttonDiameter.map { $0 * 0.28 } ?? 10
				let diameter: CGFloat = buttonDiameter ?? 0
				Image(imageName)
					.resizable()
					.scaledToFit()
					.frame(width: imageWidth, height: imageHeight)
					.offset(x: 0, y: imageOffsetY)
					.rotationEffect(.degrees(wiggleAngle), anchor: .center)
					.opacity(1)
					.animation(.easeInOut(duration: 0.12), value: isHovered)
					.padding(imagePadding)
					.frame(width: diameter, height: diameter)

			} else {
				Image(systemName: icon)
					.font(size == "small" ? .system(size: 11, weight: .regular) : .system(size: 16, weight: .regular))
					.foregroundStyle(
						Color(.labelColor.withAlphaComponent(iconOpacity))
					)
					.opacity(currentOpacity)
					.animation(.easeInOut(duration: 0.12), value: isHovered)
			}
        }
    }

	@ViewBuilder
	private var sizedLabel: some View {
		if let buttonDiameter, let imageName = image, !imageName.isEmpty {
			ZStack {
				Circle().fill(Color.clear)
				buttonLabel
			}
			.frame(width: buttonDiameter, height: buttonDiameter)
			.contentShape(Circle())
		} else {
			buttonLabel
				.frame(width: size == "small" ? 4 : 5, height: size == "small" ? 18 : 18)
		}
	}

	var body: some View {
		if let imageName = image, !imageName.isEmpty {
			Button(action: action) {
				sizedLabel
			}
			.background { glowBackground }
			.overlay(Color.primary.opacity(0.001))
			.modifier(ButtonStyleAvailabilityModifier())
			.controlSize(.extraLarge)
			.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
			.onHover { hovering in
				isHovered = hovering
			}
			.gesture(pressGesture)
			.onChange(of: isPressed) { _, pressed in
				if pressed {
					startWiggle()
				} else {
					stopWiggle()
				}
			}
		}
		else {
			Button(action: action) {
				sizedLabel
			}
			.background { glowBackground }
			.overlay(Color.primary.opacity(0.001))
			.modifier(ButtonStyleAvailabilityModifier())
			.controlSize(size == "small" ? .large : .extraLarge)
			.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
			.onHover { hovering in
				isHovered = hovering
			}
			.gesture(pressGesture)
			.onChange(of: isPressed) { _, pressed in
				if pressed {
					startWiggle()
				} else {
					stopWiggle()
				}
			}
		}
	}

	private func startWiggle() {
		wiggleTask?.cancel()
		wiggleTask = Task {
			while !Task.isCancelled {
				await MainActor.run {
					withAnimation(.linear(duration: 0.07)) {
						wigglePhase.toggle()
					}
				}
				try? await Task.sleep(nanoseconds: 70_000_000)
			}
		}
	}

	private func stopWiggle() {
		wiggleTask?.cancel()
		wiggleTask = nil
		withAnimation(.easeOut(duration: 0.08)) {
			wigglePhase = false
		}
	}
}

@available(macOS 26.0, *)
private struct GlassButtonForImage: View {
	let iconOpacity: CGFloat
	let baseOpacity: Double
	let hoverOpacity: Double
	let pressedOpacity: Double
	let focusMultiplier: Double
	let size: String?
	let image: String?
	let buttonDiameter: CGFloat?
	let action: () -> Void
	@State private var isHovered = false
	@State private var isPressed = false
	@State private var wigglePhase = false
	@State private var wiggleTask: Task<Void, Never>?

	init(
		iconOpacity: CGFloat,
		baseOpacity: Double,
		hoverOpacity: Double,
		pressedOpacity: Double,
		focusMultiplier: Double,
		action: @escaping () -> Void,
		size: String? = nil,
		image: String? = nil,
		buttonDiameter: CGFloat? = nil
	) {
		self.iconOpacity = iconOpacity
		self.baseOpacity = baseOpacity
		self.hoverOpacity = hoverOpacity
		self.pressedOpacity = pressedOpacity
		self.focusMultiplier = focusMultiplier
		self.action = action
		self.size = size
		self.image = image
		self.buttonDiameter = buttonDiameter
	}

	private var currentOpacity: Double {
		let base =
			isPressed
			? pressedOpacity : (isHovered ? hoverOpacity : baseOpacity)
		return base * focusMultiplier
	}
	
	private var imageHoverOpacity: Double {
		let hoverOpacity: Double = 1
		let unHoveredOpacity: Double = 0.7
		let base =
			isPressed
			? 1 : (isHovered ? hoverOpacity : unHoveredOpacity)
		return base
	}
	
	private var imageHoverSaturation: Double {
		let hovered: Double = 1
		let unHovered: Double = 0.8
		let base =
			isPressed
			? 1 : (isHovered ? hovered : unHovered)
		return base
	}
	
	private var imageHoverBrightness: Double {
		let hovered: Double = 0
		let unHovered: Double = -0.1
		let base =
			isPressed
			? 0 : (isHovered ? hovered : unHovered)
		return base
	}
	
	private var imageHoverGrayscale: Double {
		let hovered: Double = 0
		let unHovered: Double = 0.99
		let base =
			isPressed
			? 0 : (isHovered ? hovered : unHovered)
		return base
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
		return ZStack {
			if let imageName = image, !imageName.isEmpty {
				let wiggleAngle: Double = isPressed ? (wigglePhase ? 4 : -4) : 0
				let _: CGFloat = buttonDiameter.map { $0 * 0.8 } ?? 30
				let _: CGFloat = buttonDiameter.map { $0 * 1.25 } ?? 45
				let imageOffsetY: CGFloat = buttonDiameter.map { -0.06 * $0 } ?? +10
				let _: CGFloat = buttonDiameter.map { $0 * 0.28 } ?? 0
				let _: CGFloat = buttonDiameter ?? 0
				Image(imageName)
					.resizable()
					.scaledToFit()
					.frame(width: 42, height: 42)
					.offset(x: 0, y: imageOffsetY)
					.rotationEffect(.degrees(wiggleAngle), anchor: .center)
					.animation(.easeInOut(duration: 0.12), value: isHovered)
					.padding(.bottom, 3)
					.grayscale(imageHoverGrayscale)
					//.saturation(imageHoverSaturation)
					//.brightness(imageHoverBrightness)
					
			}
		}
	}

	@ViewBuilder
	private var sizedLabel: some View {
		if let imageName = image, !imageName.isEmpty {
			ZStack {
				Circle().fill(Color.clear)
				buttonLabel
			}
			.frame(width: 8, height: 22)
			.padding(-1)
			.contentShape(Circle())
		} else {
			buttonLabel
				.frame(width: size == "small" ? 4 : 5, height: size == "small" ? 18 : 18)
		}
	}

	var body: some View {
		if let imageName = image, !imageName.isEmpty {
			Button(action: action) {
				sizedLabel
			}
			.background { glowBackground }
			.overlay(Color.primary.opacity(0.001))
			.modifier(ButtonStyleAvailabilityModifier())
			.controlSize(.large)
			.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
			.onHover { hovering in
				isHovered = hovering
			}
			.gesture(pressGesture)
			.onChange(of: isPressed) { _, pressed in
				if pressed {
					startWiggle()
				} else {
					stopWiggle()
				}
			}
		}
		else {
			Button(action: action) {
				sizedLabel
			}
			.background { glowBackground }
			.overlay(Color.primary.opacity(0.001))
			.modifier(ButtonStyleAvailabilityModifier())
			.controlSize(size == "small" ? .large : .extraLarge)
			.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
			.onHover { hovering in
				isHovered = hovering
			}
			.gesture(pressGesture)
			.onChange(of: isPressed) { _, pressed in
				if pressed {
					startWiggle()
				} else {
					stopWiggle()
				}
			}
		}
	}

	private func startWiggle() {
		wiggleTask?.cancel()
		wiggleTask = Task {
			while !Task.isCancelled {
				await MainActor.run {
					withAnimation(.linear(duration: 0.07)) {
						wigglePhase.toggle()
					}
				}
				try? await Task.sleep(nanoseconds: 70_000_000)
			}
		}
	}

	private func stopWiggle() {
		wiggleTask?.cancel()
		wiggleTask = nil
		withAnimation(.easeOut(duration: 0.08)) {
			wigglePhase = false
		}
	}
}

@available(macOS 26.0, *)
private struct GlassTextButton: View {
	@Environment(\.colorScheme) private var colorScheme
	let title: String
	let titleOpacity: CGFloat
	let baseOpacity: Double
	let hoverOpacity: Double
	let pressedOpacity: Double
	let focusMultiplier: Double
	let isSelected: Bool
	let action: () -> Void
	@State private var isHovered = false
	@State private var isPressed = false
	
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
                        startRadius: 1,
                        endRadius: 80
                    )
                )
                .blur(radius: 10)
        }
        if isPressed {
            let glowColor: Color = .primary
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 1,
                        endRadius: 80
                    )
                )
                .blur(radius: 10)
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
        return HStack {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(
                    AnyShapeStyle(
                        isSelected
						? AnyShapeStyle(colorScheme == .light ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                        : AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.6))
                    )
                )
                .opacity(isSelected ? 1.0 : (0.5 * currentOpacity))
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .frame(width: 60, height: 40)
        .padding(.horizontal, 1)
        .padding(.vertical, -10)
    }

	var body: some View {
        Button(action: action) {
            buttonLabel
        }
        //.buttonStyle(isSelected ? .glass(.clear) : .glass(.regular))
        .tint(isSelected ? .accentColor : nil)
        .padding(-4)
        .background { glowBackground }
        .overlay(Color.primary.opacity(0.001))
        .modifier(ButtonStyleAvailabilityModifier())
        .controlSize(.extraLarge)
        .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
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

struct SingleGlassButton: View {
	// Allow reuse of the glass-styled tool button without external dependencies
	let icon: String
	let action: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	// Local state and constants so this view doesn't rely on InspectorControl's properties
	@State private var isFocusedWindow = true
	private let baseOpacity: Double = 0.85
	private let hoverOpacity: Double = 0.6
	private let pressedOpacity: Double = 0.5

	var body: some View {
		// Fallback to a constant focus if WindowFocusReader isn't available
		let iconOpacity: CGFloat = isFocusedWindow ? 0.9 : 0.3
		Group {
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer(spacing: 0) {
					GlassToolButton(
						icon: icon,
						iconOpacity: iconOpacity,
						baseOpacity: baseOpacity,
						hoverOpacity: hoverOpacity,
						pressedOpacity: pressedOpacity,
						focusMultiplier: isFocusedWindow ? 1.0 : 0.7,
						action: action
					)
				}
				.background(
					WindowFocusReader { window in
						// If WindowFocusReader exists in your project, attach and read focus here.
						// We only toggle a simple boolean to drive opacity locally.
						if let observer = window as? WindowFocusObservableProxy
						{
							// If you don't have this type, this block is harmless and won't execute.
							self.isFocusedWindow = observer.isFocused
						} else {
							// Default to true; adjust if you add a proper focus observer.
							self.isFocusedWindow = true
						}
					}
				)
			} else {
				// Simple, plain-style button for older platforms
				Button(action: action) {
					Image(systemName: icon)
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(
							(colorScheme == .light ? Color.black : Color.white)
								.opacity(Double(iconOpacity))
						)
						.frame(width: 40, height: 36)
						.contentShape(Capsule())
				}
				.buttonStyle(.plain)
				.background(
					Capsule().fill(.ultraThinMaterial)
				)
				.clipShape(Capsule())
				.overlay(
					Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
				)
				.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
			}
		}
	}
}

struct SingleGlassButtonImage: View {
	let image: String
	let action: () -> Void

	var body: some View {
		SingleGlassButtonImageRound(
			image: image,
			buttonDiameter: 36,
			action: action
		)
	}
}

struct SingleGlassButtonImageRound: View {
	// Allow reuse of the glass-styled tool button without external dependencies
	let image: String
	let buttonDiameter: CGFloat
	let action: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	// Local state and constants so this view doesn't rely on InspectorControl's properties
	@State private var isFocusedWindow = true
	@State private var isPressed = false
	@State private var wigglePhase = false
	@State private var wiggleTask: Task<Void, Never>?
	private let baseOpacity: Double = 0.85
	private let hoverOpacity: Double = 0.6
	private let pressedOpacity: Double = 0.5

	var body: some View {
		// Fallback to a constant focus if WindowFocusReader isn't available
		let iconOpacity: CGFloat = isFocusedWindow ? 0.9 : 0.3
		let wiggleAngle: Double = isPressed ? (wigglePhase ? 4 : -4) : 0
		let imageWidth: CGFloat = buttonDiameter * 0.8
		let imageHeight: CGFloat = buttonDiameter * 2
		let pressGesture = DragGesture(minimumDistance: 0)
			.onChanged { _ in
				if !isPressed {
					isPressed = true
					startWiggle()
				}
			}
			.onEnded { _ in
				isPressed = false
				stopWiggle()
			}
		Group {
			//let isSmall: Bool = !image.isEmpty
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer(spacing: 0) {
					GlassButtonForImage(
						iconOpacity: iconOpacity,
						baseOpacity: baseOpacity,
						hoverOpacity: hoverOpacity,
						pressedOpacity: pressedOpacity,
						focusMultiplier: isFocusedWindow ? 1.0 : 0.7,
						action: action,
						//size: isSmall ? "small" : "",
						image: image, // pass asset name (e.g., "JuiceLogo")
						buttonDiameter: buttonDiameter
					)
					.glassEffect(.regular)
				}
				
				//.glassEffect(.regular)
				.background(
					WindowFocusReader { window in
						// If WindowFocusReader exists in your project, attach and read focus here.
						// We only toggle a simple boolean to drive opacity locally.
						if let observer = window as? WindowFocusObservableProxy
						{
							// If you don't have this type, this block is harmless and won't execute.
							self.isFocusedWindow = observer.isFocused
						} else {
							// Default to true; adjust if you add a proper focus observer.
							self.isFocusedWindow = true
						}
					}
				)
			} else {
				// Simple, plain-style button for older platforms
				Button(action: action) {
					ZStack {
						Circle().fill(.ultraThinMaterial)
						Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
						Image(image)
							.resizable()
							.scaledToFit()
							.frame(width: imageWidth, height: imageHeight)
							.rotationEffect(.degrees(wiggleAngle), anchor: .center)
							.foregroundStyle(
								(colorScheme == .light ? Color.black : Color.white)
									.opacity(Double(iconOpacity))
							)
					}
					.frame(width: buttonDiameter, height: buttonDiameter)
					.contentShape(Circle())
				}
				.buttonStyle(.plain)
				.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
				.simultaneousGesture(pressGesture)
			}
		}
	}

	private func startWiggle() {
		wiggleTask?.cancel()
		wiggleTask = Task {
			while !Task.isCancelled {
				await MainActor.run {
					withAnimation(.linear(duration: 0.07)) {
						wigglePhase.toggle()
					}
				}
				try? await Task.sleep(nanoseconds: 70_000_000)
			}
		}
	}

	private func stopWiggle() {
		wiggleTask?.cancel()
		wiggleTask = nil
		withAnimation(.easeOut(duration: 0.08)) {
			wigglePhase = false
		}
	}
}

struct SingleGlassButtonSml: View {
	// Allow reuse of the glass-styled tool button without external dependencies
	let icon: String
	let action: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	// Local state and constants so this view doesn't rely on InspectorControl's properties
	@State private var isFocusedWindow = true
	private let baseOpacity: Double = 0.85
	private let hoverOpacity: Double = 0.6
	private let pressedOpacity: Double = 0.5

	var body: some View {
		// Fallback to a constant focus if WindowFocusReader isn't available
		let iconOpacity: CGFloat = isFocusedWindow ? 0.9 : 0.3
		Group {
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer(spacing: 0) {
					GlassToolButton(
						icon: icon,
						iconOpacity: iconOpacity,
						baseOpacity: baseOpacity,
						hoverOpacity: hoverOpacity,
						pressedOpacity: pressedOpacity,
						focusMultiplier: isFocusedWindow ? 1.0 : 0.7,
						action: action,
						size: "small"
					)
				}
				.background(
					WindowFocusReader { window in
						// If WindowFocusReader exists in your project, attach and read focus here.
						// We only toggle a simple boolean to drive opacity locally.
						if let observer = window as? WindowFocusObservableProxy
						{
							// If you don't have this type, this block is harmless and won't execute.
							self.isFocusedWindow = observer.isFocused
						} else {
							// Default to true; adjust if you add a proper focus observer.
							self.isFocusedWindow = true
						}
					}
				)
			} else {
				// Simple, plain-style button for older platforms
				Button(action: action) {
					Image(systemName: icon)
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(
							(colorScheme == .light ? Color.black : Color.white)
								.opacity(Double(iconOpacity))
						)
						.frame(width: 40, height: 36)
						.contentShape(Capsule())
				}
				.buttonStyle(.plain)
				.background(
					Capsule().fill(.ultraThinMaterial)
				)
				.clipShape(Capsule())
				.overlay(
					Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
				)
				.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
			}
		}
	}
}

struct GlassTabControl: View {
	@Environment(\.colorScheme) private var colorScheme
	let isQueueSelected: Bool
	let onSelectQueue: () -> Void
	let isResultsSelected: Bool
	let onSelectResults: () -> Void
	@StateObject private var focusObserver = WindowFocusObserver()
	private let baseOpacity: Double = 0.85
	private let hoverOpacity: Double = 0.6
	private let pressedOpacity: Double = 0.5

	@Namespace var controls

	var body: some View {
		let _: CGFloat = 40.0
		let iconOpacity: CGFloat = focusObserver.isFocused ? 0.9 : 0.3
		if #available(macOS 26.0, iOS 26.0, *) {
			GlassEffectContainer(spacing: 20) {
				HStack(spacing: 35) {
					//BUTTON1
					GlassTextButton(
						title: "Queue",
						titleOpacity: iconOpacity,
						baseOpacity: baseOpacity,
						hoverOpacity: hoverOpacity,
						pressedOpacity: pressedOpacity,
						focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7,
						isSelected: isQueueSelected,
						action: {
							withAnimation(
								.spring(response: 0.45, dampingFraction: 0.8)
							) {
								onSelectQueue()
							}

						}
					)
					.glassEffectUnion(id: "button1", namespace: controls)
					//BUTTON 2
					GlassTextButton(
						title: "Results",
						titleOpacity: iconOpacity,
						baseOpacity: baseOpacity,
						hoverOpacity: hoverOpacity,
						pressedOpacity: pressedOpacity,
						focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7,
						isSelected: isResultsSelected,
						action: {
							withAnimation(
								.spring(response: 0.45, dampingFraction: 0.8)
							) {
								onSelectResults()
							}

						}
					)
					.offset(x: -20.0, y: 0.0)
					.glassEffectUnion(id: "button2", namespace: controls)
				}
				.padding(.trailing, -30)
			}
			.background(WindowFocusReader { focusObserver.attach($0) })
		} else {
			// Fallback container for platforms prior to macOS 26 / iOS 26
			HStack(spacing: 10) {
				Button {
					withAnimation(.spring(response: 0.45, dampingFraction: 0.8))
					{
						
					}
				} label: {
					ZStack {
						Image(
							systemName: "info.circle"
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


//Joined buttons!
//struct InspectorControl: View {
//	@ObservedObject var inspector: InspectorCoordinator
//	@Binding var columnVisibility: NavigationSplitViewVisibility
//	@StateObject private var focusObserver = WindowFocusObserver()
//	private let baseOpacity: Double = 0.85
//	private let hoverOpacity: Double = 0.6
//	private let pressedOpacity: Double = 0.5
//
//	@Namespace var controls
//
//	var body: some View {
//		let _: CGFloat = 40.0
//		let iconOpacity: CGFloat = focusObserver.isFocused ? 0.9 : 0.3
//		if #available(macOS 26.0, iOS 26.0, *) {
//			GlassEffectContainer(spacing: 30) {
//				HStack(spacing: 35) {
//					//BUTTON1
//					GlassToolButton(
//						icon: inspector.isPresented
//							? "chevron.right.square" : "chevron.left.square",
//						iconOpacity: iconOpacity,
//						baseOpacity: baseOpacity,
//						hoverOpacity: hoverOpacity,
//						pressedOpacity: pressedOpacity,
//						focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7,
//						action: {
//							withAnimation(
//								.spring(response: 0.45, dampingFraction: 0.8)
//							) {
//								if inspector.isPresented {
//									inspector.hide(resetContent: false)
//								} else {
//									inspector.isPresented = true
//								}
//							}
//
//						}
//					)
//					.glassEffectUnion(id: "button1", namespace: controls)
//					//BUTTON 2
//					GlassToolButton(
//						icon: "scribble.variable",
//						iconOpacity: iconOpacity,
//						baseOpacity: baseOpacity,
//						hoverOpacity: hoverOpacity,
//						pressedOpacity: pressedOpacity,
//						focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7,
//						action: {
//							withAnimation(
//								.spring(response: 0.45, dampingFraction: 0.8)
//							) {
//								if inspector.isPresented {
//									inspector.hide(resetContent: false)
//								} else {
//									inspector.isPresented = true
//								}
//							}
//						}
//					)
//					.offset(x: -30.0, y: 0.0)
//					.glassEffectUnion(id: "button2", namespace: controls)
//					//BUTTON 3
//					GlassToolButton(
//						icon: "scribble.variable",
//						iconOpacity: iconOpacity,
//						baseOpacity: baseOpacity,
//						hoverOpacity: hoverOpacity,
//						pressedOpacity: pressedOpacity,
//						focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7,
//						action: {
//							withAnimation(
//								.spring(response: 0.45, dampingFraction: 0.8)
//							) {
//								if inspector.isPresented {
//									inspector.hide(resetContent: false)
//								} else {
//									inspector.isPresented = true
//								}
//							}
//						}
//					)
//					.offset(x: -60.0, y: 0.0)
//					.glassEffectUnion(id: "button3", namespace: controls)
//				}
//			}
//			.background(WindowFocusReader { focusObserver.attach($0) })
//		} else {
//			// Fallback container for platforms prior to macOS 26 / iOS 26
//			HStack(spacing: 10) {
//				Button {
//					withAnimation(.spring(response: 0.45, dampingFraction: 0.8))
//					{
//						if inspector.isPresented {
//							inspector.hide(resetContent: false)
//						} else {
//							inspector.isPresented = true
//						}
//					}
//				} label: {
//					ZStack {
//						Image(
//							systemName: inspector.isPresented
//								? "chevron.right.square" : "chevron.left.square"
//						)
//						.font(.system(size: 16, weight: .regular))
//						.foregroundStyle(
//							Color(.labelColor.withAlphaComponent(iconOpacity))
//						)
//					}
//					.frame(width: 40, height: 36)
//					.contentShape(Capsule())
//				}
//				.buttonStyle(.plain)
//				.background(backgroundShape)
//				.clipShape(Capsule())
//				.overlay(
//					Capsule()
//						.stroke(Color.white.opacity(0.25), lineWidth: 1)
//				)
//				.shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 5)
//				.background(WindowFocusReader { focusObserver.attach($0) })
//				.modifier(
//					PressableOpacity(
//						baseOpacity: baseOpacity,
//						hoverOpacity: hoverOpacity,
//						pressedOpacity: pressedOpacity,
//						focusMultiplier: focusObserver.isFocused ? 1.0 : 0.7
//					)
//				)
//			}
//		}
//	}
//
//	@ViewBuilder
//	private var backgroundShape: some View {
//		let shape = Capsule()
//		if #available(macOS 26.0, iOS 26.0, *) {
//			GlassEffectContainer {
//				shape
//					.fill(.clear)
//					.glassEffect(.regular, in: shape)
//			}
//		} else {
//			shape.fill(.ultraThinMaterial)
//		}
//	}
//
//	@ViewBuilder
//	private func glassIconButton(symbol: String, size: CGFloat) -> some View {
//		let shape = Circle()
//		Button(action: {}) {
//			Image(systemName: symbol)
//				.font(.system(size: 22, weight: .semibold))
//				.symbolRenderingMode(.monochrome)
//				.foregroundStyle(Color.black.opacity(0.9))
//				.shadow(
//					color: Color.white.opacity(0.35),
//					radius: 1,
//					x: 0,
//					y: 0.5
//				)
//				.frame(width: size, height: size)
//				.background(shape.fill(Color.white.opacity(0.22)))
//				.clipShape(shape)
//				.overlay(
//					shape.stroke(Color.white.opacity(0.18), lineWidth: 1)
//				)
//				.compositingGroup()
//				.drawingGroup(opaque: false, colorMode: .linear)
//		}
//		.buttonStyle(.plain)
//		.contentShape(shape)
//	}
//}

// Helper protocol used only to avoid compile errors if WindowFocusReader provides an attachable observer in your project.
// If you already have WindowFocusObserver/WindowFocusReader in scope, you can remove this and wire to your real observer.
private protocol WindowFocusObservableProxy {
	var isFocused: Bool { get }
}

#Preview("GlassTabControl") {
	struct PreviewHost: View {
		@State private var isQueue = true
		@State private var columnVisibility: NavigationSplitViewVisibility =
			.all
		@StateObject private var inspector = InspectorCoordinator()

		var body: some View {
			ZStack {
				Color.gray.opacity(0.15).ignoresSafeArea()
				VStack {
//					InspectorControl(
//						inspector: inspector,
//						columnVisibility: $columnVisibility
//					)
//					.padding(20)
//					.frame(maxWidth: .infinity, maxHeight: .infinity)
//					SingleGlassButton(icon: "chevron.right.square") {}
					GlassTabControl(
						isQueueSelected: isQueue,
						onSelectQueue: { isQueue = true },
						isResultsSelected: !isQueue,
						onSelectResults: { isQueue = false }
					)
				}
			}
			.frame(width: 600, height: 200)
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

	}

	return PreviewHost()
}

#Preview("Small") {
	struct PreviewHost: View {
		@State private var isQueue = true
		@State private var columnVisibility: NavigationSplitViewVisibility =
			.all
		@StateObject private var inspector = InspectorCoordinator()

		var body: some View {
			ZStack {
				Color.gray.opacity(0.15).ignoresSafeArea()
				VStack {
					SingleGlassButtonSml(
						icon: "trash",
						action: {})
					SingleGlassButtonImageRound(
						image: "JuiceLogo",
						buttonDiameter: 10,
						action: {})
				}
			}
			.frame(width: 600, height: 200)
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

	}

	return PreviewHost()
}
