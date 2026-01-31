//
//  PanelCard.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 25/1/2026.
//
import SwiftUI

struct ElevatedPanel<Content: View>: View {
	enum Style {
		case solid
		case glass
	}

    let content: Content
	let style: Style
	let glassOpacity: CGFloat
	let glassBaseOpacity: CGFloat

    init(style: Style = .solid, glassOpacity: CGFloat = 1, glassBaseOpacity: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.content = content()
		self.style = style
		self.glassOpacity = glassOpacity
		self.glassBaseOpacity = glassBaseOpacity
		}

    var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		let base = VStack(alignment: .leading, spacing: 12) {
			content
		}
		.padding(16)
		.background {
			switch style {
			case .solid:
				shape
					.fill(Color.white)
					.shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
			case .glass:
				if #available(macOS 26.0, iOS 26.0, *) {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
					.overlay {
						shape
							.fill(Color.white.opacity(glassBaseOpacity))
							.opacity(glassOpacity)
					}
				} else {
					shape.fill(.ultraThinMaterial)
						.opacity(glassOpacity)
				}
			}
		}

		if style == .glass {
			base
				.clipShape(shape)
				.overlay {
					shape.strokeBorder(.white.opacity(0.12))
				}
				.shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
		} else {
			base
		}
    }
}
