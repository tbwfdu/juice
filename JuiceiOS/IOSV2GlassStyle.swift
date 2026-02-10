import SwiftUI

enum IOSV2GlassStyle {
    static var windowGradient: LinearGradient {
        .juice
    }
}

extension View {
    func iosV2GlassPanel(context: GlassStateContext, cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background {
                Color.clear
                    .glassCompatSurface(
                        in: shape,
                        style: .regular,
                        context: context,
                        fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
                        fillOpacity: min(
                            1,
                            GlassThemeTokens.panelBaseTintOpacity(for: context)
                                + GlassThemeTokens.panelNeutralOverlayOpacity(for: context)
                        ),
                        surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: context)
                    )
            }
            .clipShape(shape)
            .glassCompatBorder(in: shape, context: context, role: .strong)
            .glassCompatShadow(context: context, elevation: .card)
    }

    func iosV2GlassRow(context: GlassStateContext, cornerRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background {
                Color.clear
                    .glassCompatSurface(
                        in: shape,
                        style: .regular,
                        context: context,
                        fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
                        fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: context),
                        surfaceOpacity: 1
                    )
            }
            .clipShape(shape)
            .glassCompatBorder(in: shape, context: context, role: .standard, lineWidth: 0.8)
            .glassCompatShadow(context: context, elevation: .small)
    }
}
