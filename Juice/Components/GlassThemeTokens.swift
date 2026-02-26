import SwiftUI

#if os(macOS)
import AppKit
#endif

// Semantic token + compatibility layer for glass styling across macOS 26 and pre-26.
// Used by: views/components that render panels, cards, controls, and overlays.

// MARK: - State Context

/// Shared rendering context for glass styling decisions.
struct GlassStateContext {
    let colorScheme: ColorScheme
    let isFocused: Bool
    let isEnabled: Bool
    let isHovered: Bool
    let isPressed: Bool

    init(
        colorScheme: ColorScheme,
        isFocused: Bool = true,
        isEnabled: Bool = true,
        isHovered: Bool = false,
        isPressed: Bool = false
    ) {
        self.colorScheme = colorScheme
        self.isFocused = isFocused
        self.isEnabled = isEnabled
        self.isHovered = isHovered
        self.isPressed = isPressed
    }
}

// MARK: - Semantic Types

/// Material style options for cross-version glass rendering.
enum GlassCompatSurfaceStyle {
    case regular
    case clear
}

/// Semantic border strength options for glass controls and panels.
enum GlassCompatBorderRole {
    case subtle
    case standard
    case strong
}

/// Semantic elevation options mapped to theme-safe shadows.
enum GlassCompatElevation {
    case none
    case small
    case card
    case panel
}

/// Semantic status accents (allowed to map to explicit status colors).
enum GlassStatusTone {
    case info
    case success
    case warning
    case error
    case neutral
}

/// Semantic overlay strengths for hover/press and neutral layering.
enum GlassOverlayRole {
    case subtle
    case standard
    case strong
    case hover
    case pressed
}

/// Centralized style tokens for glass surfaces, borders, and shadows.
enum GlassThemeTokens {
    static func controlBackgroundBase(for context: GlassStateContext) -> Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        context.colorScheme == .dark ? .black : .white
        #endif
    }

    static func windowBackgroundBase(for context: GlassStateContext) -> Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        context.colorScheme == .dark ? .black : .white
        #endif
    }

    static func panelSurfaceOpacity(for context: GlassStateContext) -> CGFloat {
        if context.isFocused {
            return context.colorScheme == .dark ? 0.90 : 0.88
        }
        return context.colorScheme == .dark ? 0.72 : 0.66
    }

    static func panelBaseTintOpacity(for context: GlassStateContext) -> CGFloat {
        if context.isFocused {
            return context.colorScheme == .dark ? 0.30 : 0.40
        }
        return context.colorScheme == .dark ? 0.20 : 0.28
    }

    static func panelNeutralOverlayOpacity(for context: GlassStateContext) -> CGFloat {
        if context.isFocused {
            return context.colorScheme == .dark ? 0.48 : 0.58
        }
        return context.colorScheme == .dark ? 0.28 : 0.36
    }

    static func overlayColor(
        for context: GlassStateContext,
        role: GlassOverlayRole
    ) -> Color {
        let baseOpacity: CGFloat
        switch role {
        case .subtle:
            baseOpacity = context.colorScheme == .dark ? 0.08 : 0.10
        case .standard:
            baseOpacity = context.colorScheme == .dark ? 0.14 : 0.16
        case .strong:
            baseOpacity = context.colorScheme == .dark ? 0.22 : 0.24
        case .hover:
            baseOpacity = context.colorScheme == .dark ? 0.18 : 0.20
        case .pressed:
            baseOpacity = context.colorScheme == .dark ? 0.24 : 0.28
        }
        let focusAdjusted = context.isFocused ? baseOpacity : max(0.06, baseOpacity - 0.05)
        return textPrimary(for: context).opacity(focusAdjusted)
    }

    static func borderColor(
        for context: GlassStateContext,
        role: GlassCompatBorderRole
    ) -> Color {
        let base: CGFloat
        switch role {
        case .subtle:
            base = context.colorScheme == .dark ? 0.14 : 0.11
        case .standard:
            base = context.colorScheme == .dark ? 0.18 : 0.14
        case .strong:
            base = context.colorScheme == .dark ? 0.24 : 0.20
        }
        let focusAdjusted = context.isFocused ? base : max(0.08, base - 0.05)
        return .white.opacity(focusAdjusted)
    }

    static func shadow(
        for context: GlassStateContext,
        elevation: GlassCompatElevation
    ) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        let opacityScale: CGFloat = context.isFocused ? 1.0 : 0.75
        switch elevation {
        case .none:
            return (.clear, 0, 0, 0)
        case .small:
            return (.black.opacity(0.08 * opacityScale), 2, 0, 1)
        case .card:
            return (.black.opacity(0.12 * opacityScale), 3, 0, 1.5)
        case .panel:
            return (.black.opacity(0.16 * opacityScale), 10, 0, 6)
        }
    }

    static func textPrimary(for context: GlassStateContext) -> Color {
        context.colorScheme == .dark ? .white : .black
    }

    static func textSecondary(for context: GlassStateContext) -> Color {
        context.colorScheme == .dark
            ? .white.opacity(0.72)
            : .black.opacity(0.72)
    }

    static func selectedChipFill(for context: GlassStateContext) -> Color {
        Color.accentColor.opacity(context.colorScheme == .dark ? 0.24 : 0.20)
    }

    static func selectedChipBorder(for context: GlassStateContext) -> Color {
        Color.accentColor.opacity(context.colorScheme == .dark ? 0.58 : 0.50)
    }

    static func navHoverRowFill(for context: GlassStateContext) -> Color {
        overlayColor(for: context, role: .hover)
    }

    static func unselectedChipFill(for context: GlassStateContext) -> Color {
        overlayColor(for: context, role: .subtle)
    }

    static func unselectedChipBorder(for context: GlassStateContext) -> Color {
        borderColor(for: context, role: .standard)
    }

    static func statusColor(_ tone: GlassStatusTone) -> Color {
        switch tone {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .neutral:
            return .gray
        }
    }

    static func statusTextColor(
        _ tone: GlassStatusTone,
        for context: GlassStateContext
    ) -> Color {
        switch tone {
        case .warning:
            return context.colorScheme == .dark ? .black : .white
        case .info, .success, .error, .neutral:
            return .white
        }
    }
}

private struct GlassCompatSurfaceModifier<S: Shape>: ViewModifier {
    let shape: S
    let style: GlassCompatSurfaceStyle
    let context: GlassStateContext
    let fillColor: Color
    let fillOpacity: CGFloat
    let surfaceOpacity: CGFloat

    func body(content: Content) -> some View {
        content.background {
            Group {
                if #available(macOS 26.0, iOS 26.0, *) {
                    ZStack {
                        GlassEffectContainer {
                            switch style {
                            case .regular:
                                shape.fill(Color.clear).glassEffect(.regular, in: shape)
                            case .clear:
                                shape.fill(Color.clear).glassEffect(.clear, in: shape)
                            }
                        }
                        shape.fill(fillColor).opacity(fillOpacity)
                    }
                    .opacity(surfaceOpacity)
                } else {
                    ZStack {
                        switch style {
                        case .regular:
                            shape.fill(.ultraThinMaterial)
                        case .clear:
                            shape.fill(.thinMaterial)
                        }
                        shape.fill(fillColor).opacity(fillOpacity * 0.9)
                    }
                    .opacity(surfaceOpacity)
                }
            }
        }
    }
}

private struct GlassCompatBorderModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let context: GlassStateContext
    let role: GlassCompatBorderRole
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            shape.strokeBorder(
                GlassThemeTokens.borderColor(for: context, role: role),
                lineWidth: lineWidth
            )
        }
    }
}

private struct GlassCompatShadowModifier: ViewModifier {
    let context: GlassStateContext
    let elevation: GlassCompatElevation

    func body(content: Content) -> some View {
        let shadow = GlassThemeTokens.shadow(for: context, elevation: elevation)
        return content.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}

extension View {
    /// Applies a theme-safe glass surface with pre-macOS 26 fallback.
    func glassCompatSurface<S: Shape>(
        in shape: S,
        style: GlassCompatSurfaceStyle = .regular,
        context: GlassStateContext,
        fillColor: Color,
        fillOpacity: CGFloat,
        surfaceOpacity: CGFloat
    ) -> some View {
        modifier(
            GlassCompatSurfaceModifier(
                shape: shape,
                style: style,
                context: context,
                fillColor: fillColor,
                fillOpacity: fillOpacity,
                surfaceOpacity: surfaceOpacity
            )
        )
    }

    /// Applies a theme-safe border for glass content.
    func glassCompatBorder<S: InsettableShape>(
        in shape: S,
        context: GlassStateContext,
        role: GlassCompatBorderRole = .standard,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(
            GlassCompatBorderModifier(
                shape: shape,
                context: context,
                role: role,
                lineWidth: lineWidth
            )
        )
    }

    /// Applies a semantic, focus-aware shadow for glass content.
    func glassCompatShadow(
        context: GlassStateContext,
        elevation: GlassCompatElevation
    ) -> some View {
        modifier(
            GlassCompatShadowModifier(
                context: context,
                elevation: elevation
            )
        )
    }
}
