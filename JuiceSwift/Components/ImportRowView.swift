//
//  ImportRowView.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 25/1/2026.
//
import SwiftUI

struct ImportRowView: View {
    let item: ImportItem

    var body: some View {
		let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(item.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Text(item.size)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
		.overlay {
			shape.strokeBorder(.white.opacity(0.12))
		}
		.shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 0.3)
    }
}
