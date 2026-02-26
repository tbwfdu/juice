//
//  ExpandableMenu.swift
//  Juice
//
//  Created by Pete Lindley on 2/2/2026.
//

import SwiftUI

@available(macOS 26.0, *)
struct CustomNavMenuGlass: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false
	@State private var isAllExpanded = false
	@State private var glassSpacing: CGFloat = 40
	@State private var buttonSpacing: CGFloat = 25
	@State private var expandTask: Task<Void, Never>?
	@Namespace private var namespace

	var body: some View {
		ZStack {
			GlassEffectContainer(spacing: glassSpacing) {
				VStack(spacing: buttonSpacing) {
					if isAllExpanded && isExpanded {
						Button(action: onPrimary) {
							Text(primaryTitle)
								.font(.system(size: 12, weight: .regular))
								.padding(.horizontal, 0)
								.padding(.vertical, 4)
						}
						.buttonStyle(.glassProminent)
						.controlSize(.large)
						.disabled(!isEnabled)
						.glassEffectID("glassPrimary", in: namespace)
					}
					if isExpanded {
						Button(action: onSecondary) {
							Text(secondaryTitle)
								.font(.system(size: 12, weight: .regular))
								.padding(.horizontal, 0)
								.padding(.vertical, 4)
						}
						.padding(1)
						.buttonStyle(.glass)
						.controlSize(.large)
						.disabled(!isEnabled)
						.glassEffectID("glassSecondary", in: namespace)
					}
				}
				.frame(width: 150, alignment: .trailing)

				HStack {
					Spacer()
					ZStack(alignment: .trailing) {
						SingleGlassButtonImageRound(
							image: "JuiceLogo",
							buttonDiameter: 10
						) {
							toggleExpanded()
						}
						.glassEffectID("glassToggle", in: namespace)
					}
					.frame(width: 40)
				}
				.frame(
					alignment: .init(
						horizontal: .trailing,
						vertical: .bottom
					)
				)
			}
		}
		.frame(maxWidth: 150, alignment: .trailing)
	}

	private func toggleExpanded() {
		if isExpanded {
			collapseExpanded()
		} else {
			expandActions()
		}
	}

	private func expandActions() {
		expandTask?.cancel()
		withAnimation(.bouncy) {
			isExpanded.toggle()
		}
		expandTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.1))
			withAnimation(.bouncy) {
				isAllExpanded.toggle()
			}
			try? await Task.sleep(for: .seconds(0.3))
			glassSpacing = 10
			buttonSpacing = 10
		}
	}

	private func collapseExpanded() {
		expandTask?.cancel()
		glassSpacing = 40
		buttonSpacing = 25
		withAnimation(.bouncy) {
			isAllExpanded = false
			isExpanded = false
		}
	}
}

struct CustomNavMenuAvailabilityAdapter: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	var body: some View {
		if #available(macOS 26.0, *) {
			CustomNavMenuGlass(
				primaryTitle: primaryTitle,
				secondaryTitle: secondaryTitle,
				isEnabled: isEnabled,
				onPrimary: onPrimary,
				onSecondary: onSecondary
			)
		} else {
			CustomNavMenuFallback(
				primaryTitle: primaryTitle,
				secondaryTitle: secondaryTitle,
				isEnabled: isEnabled,
				onPrimary: onPrimary,
				onSecondary: onSecondary
			)
		}
	}
}

struct CustomNavMenuFallback: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false

	var body: some View {
		HStack(spacing: 16) {
			if isExpanded {
				Button(primaryTitle) {
					guard isEnabled else { return }
					onPrimary()
				}
				.disabled(!isEnabled)
				Button(secondaryTitle) {
					guard isEnabled else { return }
					onSecondary()
				}
				.disabled(!isEnabled)
			}
			ZStack(alignment: .topTrailing) {
				Button {
					withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
					{
						isExpanded.toggle()
					}
				} label: {
					Image(systemName: isExpanded ? "xmark" : "plus")
						.frame(width: 44, height: 44)
				}
				.buttonStyle(.borderedProminent)
				.buttonBorderShape(.capsule)
			}
		}
		.padding(12)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(.ultraThinMaterial)
		)
	}
}


#Preview("ExpandingButtons") {
	struct PreviewHost: View {

		var body: some View {
			CustomNavMenuAvailabilityAdapter(
				primaryTitle: "Scan Folder",
				secondaryTitle: "Clear",
				isEnabled: true,
				onPrimary: {},
				onSecondary: {}
			)
			.frame(width: 500, height: 200, alignment: .leading)
			.preferredColorScheme(.light)
			.background(
				// A background is needed to see the blur/reflection effect
				LinearGradient(
					gradient: Gradient(colors: [.blue, .purple]),
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
		}

	}

	return PreviewHost()
}

