import SwiftUI

// MARK: - Typography

struct JuiceTypography {
    static func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
    }

    static func smallCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }

    static func metaLabel(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
				.font(.body.weight(.semibold))
               
            Text(value)
				.font(.body)
				.foregroundStyle(.secondary)
        }
    }
}

// MARK: - Buttons

enum NativeActionButtonVariant {
	case primary
	case secondary
}

extension View {
	@ViewBuilder
	func nativeActionButtonStyle(
		_ variant: NativeActionButtonVariant,
		controlSize: ControlSize = .large
	) -> some View {
		if #available(macOS 26.0, iOS 26.0, *) {
			switch variant {
			case .primary:
				self
					.buttonStyle(.glass(.regular))
					.controlSize(controlSize)
					.buttonBorderShape(.automatic)
					.tint(.accentColor)
			case .secondary:
				self
					.buttonStyle(.glass(.clear))
					.controlSize(controlSize)
					.buttonBorderShape(.automatic)
			}
		} else {
			switch variant {
			case .primary:
				self
					.buttonStyle(.borderedProminent)
					.controlSize(controlSize)
			case .secondary:
				self
					.buttonStyle(.bordered)
					.controlSize(controlSize)
			}
		}
	}
}

struct JuiceButtons {
    @MainActor static func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Group {
            if #available(macOS 26.0, iOS 26.0, *) {
                Button(action: action) {
                    Text(title)
                }
                .buttonStyle(.glass(.regular))
				.glassPopHighlight()
                .controlSize(.extraLarge)
                .buttonBorderShape(.automatic)
				.tint(.accentColor)
            } else {
                Button(action: action) {
                    Text(title)
                }
                .buttonStyle(.juiceGlass(.primary))
                .controlSize(.extraLarge)
            }
        }
    }

	@MainActor static func secondary(
		_ title: String,
		usesColorGradient: Bool = true,
		action: @escaping () -> Void
	) -> some View {
        Group {
            if #available(macOS 26.0, iOS 26.0, *) {
                Button(action: action) {
                    Text(title)
                }
                .buttonStyle(.glass(.regular))
				.glassPopHighlight(usesColorGradient: usesColorGradient)
                .controlSize(.extraLarge)
                .buttonBorderShape(.automatic)
            } else {
                Button(action: action) {
                    Text(title)
                }
                .buttonStyle(.juiceGlass(.secondary, usesColorGradient: usesColorGradient))
                .controlSize(.extraLarge)
            }
        }
    }

	@MainActor static func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.juiceGlass(.ghost))
            .controlSize(.large)
    }

    @MainActor static func clear(_ title: String, action: @escaping () -> Void) -> some View {
        Group {
            if #available(macOS 26.0, iOS 26.0, *) {
                Button(action: action) {
                    Text(title)
                }
                .buttonStyle(.glass(.clear))
				.glassPopHighlight()
                .controlSize(.large)
                .buttonBorderShape(.automatic)
            } else {
                Button(action: action) {
                    Text(title)
                }
                .buttonStyle(.juiceGlass(.clear))
                .controlSize(.large)
            }
        }
    }
	
	@MainActor static func smlRoundClear(_ icon: String? = nil, title: String? = nil, action: @escaping () -> Void) -> some View {
		Group {
			if #available(macOS 26.0, iOS 26.0, *) {
				Button(action: action) {
					if let icon = icon {
						if (icon == "arrow.up.left.and.arrow.down.right"){
							Image(systemName: icon)
								.rotationEffect(Angle(degrees: 90))
						}
						else {
							Image(systemName: icon)
						}
					} else if let title = title {
						Text(title)
					}
				}
				.buttonStyle(.juiceGlass(.icon))
				.controlSize(.mini)
				.buttonBorderShape(.circle)
				.padding(4)
				.frame(width: 24, height: 24)
				.clipShape(Circle())
				.contentShape(Circle())
			} else {
				Button(action: action) {
					if let icon = icon {
						Image(systemName: icon)
					} else if let title = title {
						Text(title)
					}
				}
				.buttonStyle(.juiceGlass(.icon))
				.controlSize(.mini)
				.buttonBorderShape(.circle)
				.padding(4)
				.frame(width: 24, height: 24)
				.clipShape(Circle())
				.contentShape(Circle())
			}
		}
	}
}

enum JuiceGlassButtonKind {
    case primary
    case secondary
    case ghost
    case icon
    case clear
}

// MARK: - Custom Button Style

struct JuiceGlassButtonStyle: ButtonStyle {
    let kind: JuiceGlassButtonKind
	let usesColorGradient: Bool

    func makeBody(configuration: Configuration) -> some View {
        JuiceGlassButtonBody(configuration: configuration, kind: kind, usesColorGradient: usesColorGradient)
    }

}

private struct JuiceGlassButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: JuiceGlassButtonKind
	let usesColorGradient: Bool

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
	#if os(macOS)
	@Environment(\.controlActiveState) private var controlActiveState
	#endif
    @State private var isHovered = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var isWindowActive: Bool {
        #if os(macOS)
        return controlActiveState == .active
        #else
        return true
        #endif
    }

    private func state(isPressed: Bool) -> GlassStateContext {
        GlassStateContext(
            colorScheme: colorScheme,
            isFocused: isWindowActive,
            isEnabled: isEnabled,
            isHovered: isHovered,
            isPressed: isPressed
        )
    }

    var body: some View {
        if kind == .icon {
            let circle = Circle()
            configuration.label
                .font(.system(.callout, weight: .regular))
				.foregroundStyle(
					.secondary.opacity(configuration.isPressed ? 0.3 : 1)
				)
                .padding(4)
                .contentShape(circle)
                .background {
                    let context = state(isPressed: configuration.isPressed)
                    Color.clear
                        .glassCompatSurface(
                            in: circle,
                            style: .regular,
                            context: context,
                            fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
                            fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: context),
                            surfaceOpacity: 1
                        )
                }
                .overlay {
                    // Tint overlay
//                    circle
//                        .fill(Color.white)
//                        .opacity(configuration.isPressed ? 0.04 : (isHovered ? 0.03 : 0.015))
//                        .opacity(isHovered ? 1.0 : 0.9)
                }
//				.overlay {
//					glassHighlightOverlay(shape: circle, isPressed: configuration.isPressed, usesColorGradient: usesColorGradient)
//						.opacity(isHovered ? 1.0 : 0.85)
//				}
//                .overlay {
//                    // Border overlay
//                    let highlight = colorScheme == .dark ? 0.22 : 0.28
//                    let topOpacity = configuration.isPressed ? highlight * 0.6 : (isHovered ? highlight * 0.9 : highlight)
//                    ZStack {
//                        circle.strokeBorder(
//                            LinearGradient(
//                                colors: [
//                                    Color.white.opacity(topOpacity),
//                                    Color.white.opacity(0.08)
//                                ],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            ),
//                            lineWidth: 0.8
//                        )
//                    }
//                    .opacity(isHovered ? 1.0 : 0.85)
//                }
                .shadow(
                    color: shadowColor(isPressed: configuration.isPressed),
                    radius: (isHovered ? 1.5 : 1),
                    x: 0,
                    y: (isHovered ? 0.8 : 0.5)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHovered = hovering
                    }
                }
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        } else {
            configuration.label
                .font(.system(.callout, weight: .regular))
                .foregroundStyle(foregroundStyle)
                .padding(paddingInsets)
                .contentShape(shape)
                .background {
                    glassBackground(
                        shape: shape,
                        isPressed: configuration.isPressed
                    )
                }
                .overlay {
                    tintOverlay(shape: shape, isPressed: configuration.isPressed)
                        .opacity(isHovered ? 1.0 : 0.9)
                }
                .overlay {
					glassHighlightOverlay(shape: shape, isPressed: configuration.isPressed, usesColorGradient: usesColorGradient)
						.opacity(isHovered ? 1.0 : 0.85)
				}
                .overlay {
                    borderOverlay(shape: shape, isPressed: configuration.isPressed)
                        .opacity(isHovered ? 1.0 : 0.85)
                }
                .shadow(color: shadowColor(isPressed: configuration.isPressed), radius: shadowRadius, x: 0, y: shadowYOffset)
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHovered = hovering
                    }
                }
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }

    private var cornerRadius: CGFloat {
        if kind == .icon {
            switch controlSize {
            case .mini:
                return 7
            case .small:
                return 8
            case .regular:
                return 9
            case .large:
                return 11
            case .extraLarge:
                return 12
            @unknown default:
                return 9
            }
        }

        // Oversized radius makes the shape pill-like regardless of height.
        return 999
    }

    private var paddingInsets: EdgeInsets {
        switch kind {
        case .icon:
            return EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 6)
        default:
            switch controlSize {
            case .mini:
                return EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8)
            case .small:
                return EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
            case .regular:
                return EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
            case .large:
                return EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
            case .extraLarge:
                return EdgeInsets(top: 11, leading: 18, bottom: 11, trailing: 18)
            @unknown default:
                return EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
            }
        }
    }

    private var foregroundStyle: Color {
        switch kind {
        case .ghost, .clear:
            return Color.primary.opacity(0.9)
        default:
            return Color.primary
        }
    }

    @ViewBuilder
    private func glassBackground(shape: RoundedRectangle, isPressed: Bool) -> some View {
        let context = state(isPressed: isPressed)
        let surfaceStyle: GlassCompatSurfaceStyle = kind == .clear ? .clear : .regular
        Color.clear
            .glassCompatSurface(
                in: shape,
                style: surfaceStyle,
                context: context,
                fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
                fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: context),
                surfaceOpacity: 1
            )
    }

    private func tintOverlay(shape: RoundedRectangle, isPressed: Bool) -> some View {
        let context = state(isPressed: isPressed)
        let role: GlassOverlayRole
        switch kind {
        case .primary:
            role = isPressed ? .pressed : (isHovered ? .hover : .standard)
        case .secondary:
            role = isPressed ? .hover : (isHovered ? .standard : .subtle)
        case .ghost, .icon, .clear:
            role = isPressed ? .standard : (isHovered ? .subtle : .subtle)
        }
        return shape
            .fill(GlassThemeTokens.overlayColor(for: context, role: role))
    }

	@ViewBuilder
	private func glassHighlightOverlay<S: Shape>(
		shape: S,
		isPressed: Bool,
		usesColorGradient: Bool
	) -> some View {
		let context = state(isPressed: isPressed)
		let strongOverlay = GlassThemeTokens.overlayColor(for: context, role: .strong)
		let standardOverlay = GlassThemeTokens.overlayColor(for: context, role: .standard)
		let subtleOverlay = GlassThemeTokens.overlayColor(for: context, role: .subtle)
		let gradientOpacity: CGFloat = isPressed ? 0.16 : (isHovered ? 0.12 : 0.08)
		let allowColorGradient = usesColorGradient && isEnabled && isWindowActive
		ZStack {
			shape
				.fill(
					LinearGradient(
						colors: [
							strongOverlay,
							standardOverlay
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
			if allowColorGradient {
				shape
					.fill(LinearGradient.juice)
					.opacity(gradientOpacity)
			}
			shape
				.fill(
					LinearGradient(
						colors: [
							strongOverlay,
							subtleOverlay.opacity(0)
						],
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.scaleEffect(x: 1, y: 0.68, anchor: .top)
			shape
				.stroke(
					GlassThemeTokens.borderColor(
						for: context,
						role: isPressed ? .strong : .standard
					),
					lineWidth: 0.6
				)
				.opacity(0.9)
				.scaleEffect(x: 1, y: 0.22, anchor: .top)
		}
	}

    @ViewBuilder
    private func borderOverlay(shape: RoundedRectangle, isPressed: Bool) -> some View {
        let context = state(isPressed: isPressed)
        ZStack {
            shape.strokeBorder(
                GlassThemeTokens.borderColor(for: context, role: .standard),
                lineWidth: 0.8
            )

            if kind == .primary {
                shape.strokeBorder(
                    GlassThemeTokens.borderColor(for: context, role: .strong),
                    lineWidth: 0.8
                )
            }
        }
    }

    private var shadowRadius: CGFloat {
        switch kind {
        case .ghost, .icon, .clear:
            return isHovered ? 1.5 : 1
        default:
            return isHovered ? 2.5 : 2
        }
    }

    private var shadowYOffset: CGFloat {
        switch kind {
        case .ghost, .icon, .clear:
            return isHovered ? 0.8 : 0.5
        default:
            return isHovered ? 1.2 : 1
        }
    }

    private func shadowColor(isPressed: Bool) -> Color {
        let context = state(isPressed: isPressed)
        let elevation: GlassCompatElevation = (kind == .ghost || kind == .icon || kind == .clear) ? .small : .card
        return GlassThemeTokens.shadow(for: context, elevation: elevation).color
    }
}

extension ButtonStyle where Self == JuiceGlassButtonStyle {
    static func juiceGlass(
		_ kind: JuiceGlassButtonKind = .secondary,
		usesColorGradient: Bool = true
	) -> JuiceGlassButtonStyle {
        JuiceGlassButtonStyle(kind: kind, usesColorGradient: usesColorGradient)
    }
}

private struct GlassPopHighlightModifier: ViewModifier {
	let usesColorGradient: Bool
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.isEnabled) private var isEnabled
	#if os(macOS)
	@Environment(\.controlActiveState) private var controlActiveState
	#endif
	@State private var isHovered = false

	func body(content: Content) -> some View {
		let context = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: isWindowActive,
			isEnabled: isEnabled,
			isHovered: isHovered
		)
		let strongOverlay = GlassThemeTokens.overlayColor(for: context, role: .strong)
		let standardOverlay = GlassThemeTokens.overlayColor(for: context, role: .standard)
		content
			.overlay {
				let shape = Capsule(style: .continuous)
				let allowColorGradient = usesColorGradient && isEnabled && isWindowActive
				ZStack {
					shape
						.fill(
							LinearGradient(
								colors: [
									strongOverlay,
									standardOverlay
								],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
					if allowColorGradient {
						shape
							.fill(LinearGradient.juice)
							.opacity(isHovered ? 0.12 : 0.08)
					}
				}
			}
			.onHover { hovering in
				withAnimation(.easeOut(duration: 0.12)) {
					isHovered = hovering
				}
			}
	}

	private var isWindowActive: Bool {
		#if os(macOS)
		return controlActiveState == .active
		#else
		return true
		#endif
	}
}

extension View {
	func glassPopHighlight(usesColorGradient: Bool = true) -> some View {
		modifier(GlassPopHighlightModifier(usesColorGradient: usesColorGradient))
	}
}

// MARK: - Shared Layout Modifiers

private struct GlassPanelStyleModifier: ViewModifier {
	let cornerRadius: CGFloat
	@Environment(\.colorScheme) private var colorScheme
	#if os(macOS)
	@Environment(\.controlActiveState) private var controlActiveState
	#endif

	private var isWindowActive: Bool {
		#if os(macOS)
		return controlActiveState == .active
		#else
		return true
		#endif
	}

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		let context = GlassStateContext(colorScheme: colorScheme, isFocused: isWindowActive)
		content
			.glassCompatSurface(
				in: shape,
				style: .regular,
				context: context,
				fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
				fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: context),
				surfaceOpacity: 1
			)
			.glassCompatBorder(in: shape, context: context, role: .standard)
			.glassCompatShadow(context: context, elevation: .card)
			.clipShape(shape)
	}
}

extension View {
    func leftColumnFrame(maxWidth: CGFloat = 2000) -> some View {
        self.frame(minWidth: 0, maxWidth: maxWidth, alignment: .leading)
    }

	func glassPanelStyle(cornerRadius: CGFloat = 14) -> some View {
		modifier(GlassPanelStyleModifier(cornerRadius: cornerRadius))
	}
}


#Preview("JuiceButtons Variants") {
    VStack(spacing: 16) {
        JuiceButtons.primary("Primary") { }
        JuiceButtons.secondary("Secondary") { }
        JuiceButtons.link("Link") { }
        JuiceButtons.clear("Clear") { }
        JuiceButtons.smlRoundClear("arrow.up.left.and.arrow.down.right") { }
        JuiceButtons.smlRoundClear(title: "A") { }
    }
    .padding()
}
