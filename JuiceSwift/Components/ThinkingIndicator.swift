//
//  ThinkingIndicator.swift
//  Juice
//
//  Created by Pete Lindley on 28/1/2026.
//

import SwiftUI

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
		.onAppear {
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
