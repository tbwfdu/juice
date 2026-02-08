//
//  Pill.swift
//  Juice
//
//  Created by Pete Lindley on 29/1/2026.
//

import SwiftUI

// Consolidated reusable status/badge/stat display primitives.
// Used by: detail cards, queue rows, and dashboard-like sections.

public struct Pill: View {
	@Environment(\.colorScheme) private var colorScheme
    private let value: String
    private let color: Color?

    public init(_ value: String, color: Color? = nil) {
        self.value = value
        self.color = color
    }

    public var body: some View {
        let shape = Capsule(style: .continuous)
		let context = GlassStateContext(colorScheme: colorScheme, isFocused: true)
		let tone = color ?? .accentColor
        Text(value)
            .foregroundStyle(tone).opacity(0.8)
            .font(.system(.footnote, weight: .semibold))
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background {
				Color.clear
					.glassCompatSurface(
						in: shape,
						style: .regular,
						context: context,
						fillColor: tone,
						fillOpacity: 0.2,
						surfaceOpacity: 1
					)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
							tone.opacity(0.35),
							tone.opacity(0.12),
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
//
//  InfoBadgeView.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 25/1/2026.
//
struct InfoBadge: View {
	@Environment(\.colorScheme) private var colorScheme
    let count: Int

    var body: some View {
		let context = GlassStateContext(colorScheme: colorScheme, isFocused: true)
        Text("\(count)")
            .font(.system(size: 11, weight: .bold))
			.foregroundStyle(GlassThemeTokens.statusTextColor(.error, for: context))
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
			.background(Capsule().fill(GlassThemeTokens.statusColor(.error)))
    }
}
//
//  StatCard.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 25/1/2026.
//
struct StatCard: View {
	@Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
		let context = GlassStateContext(colorScheme: colorScheme, isFocused: true)

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
			content
				.padding(16)
				.glassCompatSurface(
					in: shape,
					style: .regular,
					context: context,
					fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
					fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: context),
					surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: context)
				)
				.glassCompatBorder(in: shape, context: context, role: .strong, lineWidth: 0.8)
				.glassCompatShadow(context: context, elevation: .panel)
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
	.background(Color.clear)
}
//
//  ThinkingIndicator.swift
//  Juice
//
//  Created by Pete Lindley on 28/1/2026.
//
struct ThinkingIndicator: View {
	let phrases: [String]
	let iconName: String

	@State private var phase = false
	@State private var phraseIndex = 0
	@State private var phraseTask: Task<Void, Never>?
	@State private var bounceTask: Task<Void, Never>?
	@State private var bounceAmount: CGFloat = 0

	init(phrases: [String], iconName: String = "sparkles") {
		self.phrases = phrases
		self.iconName = iconName
	}

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: iconName)
				.font(.system(size: 16, weight: .semibold))
				.foregroundStyle(iconGradient)
				.scaleEffect(phase ? 1.1 : 0.95)
				.opacity(phase ? 0.85 : 1)
				.animation(
					.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
					value: phase
				)

			HStack(spacing: 0) {
				ForEach(Array(currentPhrase.enumerated()), id: \.offset) { index, letter in
					Text(String(letter))
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(.primary)
						.hueRotation(.degrees(phase ? 220 : 0))
						.opacity(phase ? 0.35 : 0.8)
						.scaleEffect(
							(phase ? 1.12 : 1) * (1 + 0.12 * bounceAmount),
							anchor: .bottom
						)
						.offset(y: (phase ? -1 : 0) + (-4 * bounceAmount))
						.animation(
							.easeInOut(duration: 0.6)
								.repeatForever(autoreverses: true)
								.delay(Double(index) * 0.03),
							value: phase
						)
						.animation(
							.interpolatingSpring(stiffness: 160, damping: 16)
								.delay(Double(index) * 0.05),
							value: bounceAmount
						)
				}
			}
		}
		.onAppearUnlessPreview {
			phase.toggle()
			triggerBounce()
			startPhraseCycle()
		}
		.onDisappear {
			phraseTask?.cancel()
			phraseTask = nil
			bounceTask?.cancel()
			bounceTask = nil
		}
	}

	private var currentPhrase: String {
		guard !phrases.isEmpty else { return "Thinking" }
		return phrases[phraseIndex % phrases.count]
	}

	private var iconGradient: LinearGradient {
//		LinearGradient(
//			colors: [
//				Color.blue.opacity(0.55),
//				Color.indigo.opacity(0.55)
//			],
//			startPoint: .topLeading,
//			endPoint: .bottomTrailing
//		)
		LinearGradient.juice
	}

	private func startPhraseCycle() {
		phraseTask?.cancel()
		guard phrases.count > 1 else { return }
		phraseTask = Task { @MainActor in
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 2_000_000_000)
				withAnimation(.easeInOut(duration: 0.25)) {
					phraseIndex = (phraseIndex + 1) % phrases.count
				}
				triggerBounce()
			}
		}
	}

	private func triggerBounce() {
		bounceTask?.cancel()
		bounceTask = Task { @MainActor in
			withAnimation(.easeInOut(duration: 0.2)) {
				bounceAmount = 1
			}
			try? await Task.sleep(nanoseconds: 220_000_000)
			withAnimation(.easeInOut(duration: 0.3)) {
				bounceAmount = 0
			}
		}
	}
}

#Preview {
	ThinkingIndicator(
		phrases: ["Thinking", "Weighing", "Evaluating"],
		iconName: "sparkles"
	)
	.frame(width: 300, height: 100)
	.padding()
}
