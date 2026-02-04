import SwiftUI

struct QueueActionSheet: View {
	let mode: ConfirmationActionMode
	let itemCount: Int
	let title: String
	let confirmTitle: String
	let cancelTitle: String
	let onConfirm: () -> Void
	let onCancel: () -> Void
	@StateObject private var focusObserver = WindowFocusObserver()

	init(
		mode: ConfirmationActionMode,
		itemCount: Int,
		title: String = "Ready to Proceed?",
		confirmTitle: String = "Confirm",
		cancelTitle: String = "Cancel",
		onConfirm: @escaping () -> Void,
		onCancel: @escaping () -> Void
	) {
		self.mode = mode
		self.itemCount = itemCount
		self.title = title
		self.confirmTitle = confirmTitle
		self.cancelTitle = cancelTitle
		self.onConfirm = onConfirm
		self.onCancel = onCancel
	}

	var body: some View {
		let glassBaseOpacity = focusObserver.isFocused ? 0.9 : 0.25
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		VStack(alignment: .leading, spacing: 16) {
			Text(title)
				.font(.system(size: 20, weight: .semibold))
				.foregroundStyle(.primary)
				.padding(.top, 4)

			VStack(alignment: .leading, spacing: 8) {
				messageText
					.font(.system(size: 14, weight: .regular))
				Text("Applications obtained using Juice are licensed to you by its owner. Juice and related services are not responsible for, nor does it grant any licenses to, third-party packages.")
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(.secondary)
			}

			HStack {
				Spacer()
				JuiceButtons.secondary(cancelTitle, action: onCancel)
				JuiceButtons.primary(confirmTitle, action: onConfirm)
			}
		}
		.padding(20)
		.frame(minWidth: 520)
		.background {
			if #available(macOS 26.0, iOS 26.0, *) {
				ZStack {
					shape.fill(Color.white.opacity(glassBaseOpacity))
					GlassEffectContainer {
						shape
							.fill(Color.white)
							.glassEffect(.regular, in: shape)
					}
				}
			} else {
				shape.fill(.ultraThinMaterial)
			}
		}
		.background(WindowFocusReader { focusObserver.attach($0) })
		.clipShape(shape)
		.overlay(shape.strokeBorder(.white.opacity(0.12)))
		.shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 4)
	}

	private var messageText: Text {
		let noun = itemCount == 1 ? "app" : "apps"
		return Text("You're about to \(Text(mode.verb).bold()) \(itemCount) \(noun) \(mode.destinationText)")
	}
}
