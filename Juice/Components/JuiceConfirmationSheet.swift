import SwiftUI

struct JuiceConfirmationSheet: View {
	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var focusObserver = WindowFocusObserver()

	let title: String
	let message: String
	let secondaryNote: String?
	let confirmTitle: String
	let cancelTitle: String
	let isDestructive: Bool
	let minWidth: CGFloat
	let onConfirm: () -> Void
	let onCancel: () -> Void

	init(
		title: String,
		message: String,
		secondaryNote: String? = nil,
		confirmTitle: String = "Confirm",
		cancelTitle: String = "Cancel",
		isDestructive: Bool = false,
		minWidth: CGFloat = 520,
		onConfirm: @escaping () -> Void,
		onCancel: @escaping () -> Void
	) {
		self.title = title
		self.message = message
		self.secondaryNote = secondaryNote
		self.confirmTitle = confirmTitle
		self.cancelTitle = cancelTitle
		self.isDestructive = isDestructive
		self.minWidth = minWidth
		self.onConfirm = onConfirm
		self.onCancel = onCancel
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)

		VStack(alignment: .leading, spacing: 16) {
			Text(title)
				.font(.system(size: 20, weight: .semibold))
				.foregroundStyle(.primary)
				.padding(.top, 4)

			VStack(alignment: .leading, spacing: 8) {
				Text(message)
					.font(.system(size: 14, weight: .regular))
				if let secondaryNote, !secondaryNote.isEmpty {
					Text(secondaryNote)
						.font(.system(size: 12, weight: .medium))
						.foregroundStyle(.secondary)
				}
			}

			HStack {
				Spacer()
				Button(cancelTitle, action: onCancel)
					.nativeActionButtonStyle(.secondary, controlSize: .large)
				Button(confirmTitle, action: onConfirm)
					.juiceGradientGlassProminentButtonStyle(controlSize: .large)
					.accessibilityHint(
						isDestructive ? "This action cannot be undone." : ""
					)
			}
		}
		.padding(20)
		.frame(minWidth: minWidth)
		.background {
			Color.clear
				.glassCompatSurface(
					in: shape,
					style: .regular,
					context: glassState,
					fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
					fillOpacity: min(
						1,
						GlassThemeTokens.panelBaseTintOpacity(for: glassState)
							+ GlassThemeTokens.panelNeutralOverlayOpacity(for: glassState)
					),
					surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: glassState)
				)
		}
		.background(WindowFocusReader { focusObserver.attach($0) })
		.clipShape(shape)
		.glassCompatBorder(in: shape, context: glassState, role: .standard)
		.glassCompatShadow(context: glassState, elevation: .panel)
	}
}
