//
//  StatCard.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 25/1/2026.
//
import SwiftUI


struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        let content = VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
            if(value == "0"){
                ProgressView()
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 90,
                    )
            }
            else {
                Text(value)
                    .font(.system(size: 72, weight: .semibold, design: .default))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }

        return Group {
            if #available(macOS 26.0, iOS 26.0, *) {
                GlassEffectContainer {
                    content
                        .padding(16)
                        .glassEffect(.regular, in: shape)
                }
                .clipShape(shape)
                .overlay(
                    shape.stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 10)
            } else {
                content
                    .padding(16)
                    .background(
                        shape
                            .fill(.ultraThinMaterial)
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(shape)
                            )
                            .overlay(
                                shape.stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 10)
            }
        }
        .frame(width: 240)
    }
}
#Preview("StatCard Preview") {
	HStack(spacing: 20) {
        StatCard(title: "Apps", value: "128")
        StatCard(title: "Recipes", value: "0")
    }
    .padding()
	.background(
		RoundedRectangle(cornerRadius: 14, style: .continuous)
			.fill(Color.white)
			.shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
	)
}
