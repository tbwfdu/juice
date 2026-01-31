import SwiftUI

// Common typography helpers
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
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }
}

// Common button helpers
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
                    // Use the same background approach but with a circular shape
                    if #available(macOS 26.0, iOS 26.0, *) {
                        GlassEffectContainer {
                            circle
                                .fill(Color.clear)
                                .glassEffect(.regular, in: circle)
                        }
                    } else {
                        circle.fill(.ultraThinMaterial)
                    }
                }
                .overlay {
                    // Tint overlay
                    circle
                        .fill(Color.white)
                        .opacity(configuration.isPressed ? 0.04 : (isHovered ? 0.03 : 0.015))
                        .opacity(isHovered ? 1.0 : 0.9)
                }
				.overlay {
					glassHighlightOverlay(shape: circle, isPressed: configuration.isPressed, usesColorGradient: usesColorGradient)
						.opacity(isHovered ? 1.0 : 0.85)
				}
                .overlay {
                    // Border overlay
                    let highlight = colorScheme == .dark ? 0.22 : 0.28
                    let topOpacity = configuration.isPressed ? highlight * 0.6 : (isHovered ? highlight * 0.9 : highlight)
                    ZStack {
                        circle.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(topOpacity),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                    }
                    .opacity(isHovered ? 1.0 : 0.85)
                }
                .shadow(color: shadowColor(isPressed: configuration.isPressed), radius: (isHovered ? 1.5 : 1), x: 0, y: (isHovered ? 0.8 : 0.5))
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
                    glassBackground(shape: shape)
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
    private func glassBackground(shape: RoundedRectangle) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            let glassStyle: Glass = kind == .clear ? .clear : .regular
            GlassEffectContainer {
                shape
                    .fill(Color.clear)
                    .glassEffect(glassStyle, in: shape)
            }
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }

    private func tintOverlay(shape: RoundedRectangle, isPressed: Bool) -> some View {
        let baseOpacity: CGFloat
        switch kind {
        case .primary:
            baseOpacity = isPressed ? 0.12 : (isHovered ? 0.10 : 0.08)
        case .secondary:
            baseOpacity = isPressed ? 0.06 : (isHovered ? 0.05 : 0.03)
        case .ghost, .icon, .clear:
            baseOpacity = isPressed ? 0.04 : (isHovered ? 0.03 : 0.015)
        }

        return shape
            .fill(Color.white)
            .opacity(baseOpacity)
    }

	@ViewBuilder
	private func glassHighlightOverlay<S: Shape>(
		shape: S,
		isPressed: Bool,
		usesColorGradient: Bool
	) -> some View {
		let whiteOpacity: CGFloat = isPressed ? 0.22 : (isHovered ? 0.18 : 0.14)
		let gradientOpacity: CGFloat = isPressed ? 0.18 : (isHovered ? 0.14 : 0.1)
		let allowColorGradient = usesColorGradient && isEnabled && isWindowActive
		ZStack {
			shape
				.fill(
					LinearGradient(
						colors: [
							Color.white.opacity(0.55),
							Color.white.opacity(0.2)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
				.opacity(whiteOpacity)
			if allowColorGradient {
				shape
					.fill(LinearGradient.juice)
					.opacity(gradientOpacity)
			}
			shape
				.fill(
					LinearGradient(
						colors: [
							Color.white.opacity(isPressed ? 0.42 : (isHovered ? 0.36 : 0.3)),
							Color.white.opacity(0.0)
						],
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.scaleEffect(x: 1, y: 0.68, anchor: .top)
			shape
				.stroke(Color.white.opacity(isPressed ? 0.5 : (isHovered ? 0.44 : 0.38)), lineWidth: 0.6)
				.opacity(0.9)
				.scaleEffect(x: 1, y: 0.22, anchor: .top)
		}
	}

	private var isWindowActive: Bool {
		#if os(macOS)
		return controlActiveState == .active
		#else
		return true
		#endif
	}

    @ViewBuilder
    private func borderOverlay(shape: RoundedRectangle, isPressed: Bool) -> some View {
        let highlight = colorScheme == .dark ? 0.22 : 0.28
        let topOpacity = isPressed ? highlight * 0.6 : (isHovered ? highlight * 0.9 : highlight)

        ZStack {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(topOpacity),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )

            if kind == .primary {
                let primaryOpacity = isPressed ? 0.35 : (isHovered ? 0.28 : 0.22)
                shape.strokeBorder(Color.white.opacity(primaryOpacity), lineWidth: 0.8)
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
        let base = colorScheme == .dark ? 0.28 : 0.12
        let hoverBoost: CGFloat = isHovered ? 0.12 : 0
        let opacity = isPressed ? base * 0.5 : min(base + hoverBoost, 0.24)
        return Color.black.opacity(opacity)
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
	@Environment(\.isEnabled) private var isEnabled
	#if os(macOS)
	@Environment(\.controlActiveState) private var controlActiveState
	#endif
	@State private var isHovered = false

	func body(content: Content) -> some View {
		content
			.overlay {
				let shape = Capsule(style: .continuous)
				let allowColorGradient = usesColorGradient && isEnabled && isWindowActive
				ZStack {
					shape
						.fill(
							LinearGradient(
								colors: [
									Color.white.opacity(0.4),
									Color.white.opacity(0.12)
								],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.opacity(isHovered ? 0.18 : 0.14)
					if allowColorGradient {
						shape
							.fill(LinearGradient.juice)
							.opacity(isHovered ? 0.14 : 0.1)
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

// A small layout helper for left column framing
extension View {
    func leftColumnFrame(maxWidth: CGFloat = 2000) -> some View {
        self.frame(minWidth: 0, maxWidth: maxWidth, alignment: .leading)
    }

	func glassPanelStyle(cornerRadius: CGFloat = 14) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		return self
			.background {
				if #available(macOS 26.0, iOS 26.0, *) {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
				} else {
					shape.fill(.ultraThinMaterial)
				}
			}
			.clipShape(shape)
			.overlay(shape.strokeBorder(.white.opacity(0.12)))
			.shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
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
