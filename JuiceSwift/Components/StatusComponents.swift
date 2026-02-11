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
    private let value: String
    private let color: Color?

    public init(_ value: String, color: Color? = nil) {
        self.value = value
        self.color = color
    }

	    public var body: some View {
	        let shape = Capsule(style: .continuous)
			let tone = color ?? .accentColor
	        Text(value)
            .foregroundStyle(tone).opacity(0.8)
            .font(.system(.footnote, weight: .semibold))
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background {
					shape.fill(tone.opacity(0.16))
	            }
	            .overlay {
	                shape.strokeBorder(tone.opacity(0.22), lineWidth: 0.8)
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

	@State private var startTime = Date.timeIntervalSinceReferenceDate

	init(phrases: [String], iconName: String = "sparkles") {
		self.phrases = phrases
		self.iconName = iconName
	}

	var body: some View {
		TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
			let elapsed = context.date.timeIntervalSinceReferenceDate - startTime
			let phraseDuration: TimeInterval = 2.0
			let phraseProgress = (elapsed.truncatingRemainder(dividingBy: phraseDuration))
				/ phraseDuration
			let phrase = phrase(at: elapsed, phraseDuration: phraseDuration)
			let pulse = pulseValue(elapsed: elapsed, duration: 0.7)
			let bounce = phraseBounce(phraseProgress: phraseProgress)

			HStack(spacing: 10) {
				Image(systemName: iconName)
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(iconGradient)
					.scaleEffect(0.95 + (0.15 * pulse))
					.opacity(1.0 - (0.15 * pulse))

				HStack(spacing: 0) {
					ForEach(Array(phrase.enumerated()), id: \.offset) { index, letter in
						animatedLetter(
							index: index,
							letter: letter,
							elapsed: elapsed,
							bounce: bounce
						)
					}
				}
			}
		}
		.onAppearUnlessPreview {
			startTime = Date.timeIntervalSinceReferenceDate
		}
	}

	private func phrase(at elapsed: TimeInterval, phraseDuration: TimeInterval) -> String {
		guard !phrases.isEmpty else { return "Thinking" }
		let index = Int(elapsed / phraseDuration) % phrases.count
		return phrases[index]
	}

	private var iconGradient: LinearGradient {
		LinearGradient.juice
	}

	private func pulseValue(elapsed: TimeInterval, duration: TimeInterval) -> Double {
		let phase = (elapsed / duration) * (.pi * 2)
		return (sin(phase) + 1) * 0.5
	}

	private func phraseBounce(phraseProgress: Double) -> Double {
		let peak: Double = 0.08
		let width: Double = 0.13
		let distance = abs(phraseProgress - peak)
		let normalized = max(0.0, 1.0 - (distance / width))
		return normalized * normalized
	}

	private func animatedLetter(
		index: Int,
		letter: Character,
		elapsed: TimeInterval,
		bounce: Double
	) -> some View {
		let stagger = Double(index) * 0.03
		let letterPulse = pulseValue(elapsed: elapsed - stagger, duration: 0.6)
		let scale = (1.0 + (0.12 * letterPulse)) * (1 + (0.12 * bounce))
		let offset = (-1.0 * letterPulse) + (-4.0 * bounce)
		let opacity = 0.8 - (0.45 * letterPulse)

		return Text(String(letter))
			.font(.system(size: 13, weight: .medium))
			.foregroundStyle(.primary)
			.hueRotation(.degrees(220 * letterPulse))
			.opacity(opacity)
			.scaleEffect(scale, anchor: .bottom)
			.offset(y: offset)
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
