import SwiftUI

// Shared small modifiers reused by custom glass controls.
// Used by: CustomGlassButtons, InspectorControls, and fallback adapters.

/// Availability adapter for applying glass button styles with a pre-macOS 26 fallback.
struct ButtonStyleAvailabilityModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            return content.buttonStyle(.glass(.clear))
        } else {
            return content.buttonStyle(.plain)
        }
    }
}

/// Shared press/hover opacity response used by glass tool controls.
struct PressableOpacity: ViewModifier {
    let baseOpacity: Double
    let hoverOpacity: Double
    let pressedOpacity: Double
    let focusMultiplier: Double
    @State private var isHovered = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        let base = isPressed
            ? pressedOpacity
            : (isHovered ? hoverOpacity : baseOpacity)
        return content
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
