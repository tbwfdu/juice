//
//  Pill.swift
//  Juice
//
//  Created by Pete Lindley on 29/1/2026.
//

import SwiftUI

public struct Pill: View {
    private let value: String
    private let color: Color?

    public init(_ value: String, color: Color? = nil) {
        self.value = value
        self.color = color
    }

    public var body: some View {
        let shape = Capsule(style: .continuous)
        Text(value)
            .foregroundStyle(color ?? .accentColor).opacity(0.6)
            .font(.system(.footnote, weight: .semibold))
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background {
                if #available(macOS 26.0, iOS 26.0, *) {
                    shape
                        .fill(color ?? .accentColor).opacity(0.1)
                        .glassEffect(.regular, in: shape)
                } else {
                    shape
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            }
    }
}

#Preview("Pill") {
    VStack(spacing: 8) {
        Pill("Update", color: .green)
        Pill("Inactive", color: .orange)
        Pill("Smart Groups: 5", color: .blue)
        Pill("Default Color")
    }
    .padding()
}
