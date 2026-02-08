import SwiftUI

// Consolidated queue confirmation actions/sheets.
// Used by: SearchView, UpdatesView, ImportView.

enum ConfirmationActionMode {
	case upload
	case download
	case uploadOnly

	var verb: String {
		switch self {
		case .upload, .uploadOnly: return "upload"
		case .download: return "download"
		}
	}

	var destinationText: String {
		switch self {
		case .upload, .uploadOnly: return "to Workspace ONE."
		case .download: return "to your local device."
		}
	}
}

struct QueueActionSheet: View {
	@Environment(\.colorScheme) private var colorScheme
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
				messageText
					.font(.system(size: 14, weight: .regular))
				Text("Applications obtained using Juice are licensed to you by its owner. Juice and related services are not responsible for, nor does it grant any licenses to, third-party packages.")
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(.secondary)
			}

				HStack {
					Spacer()
					Button(cancelTitle, action: onCancel)
						.nativeActionButtonStyle(.secondary, controlSize: .large)
					Button(confirmTitle, action: onConfirm)
						.nativeActionButtonStyle(.primary, controlSize: .large)
				}
			}
		.padding(20)
		.frame(minWidth: 520)
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

	private var messageText: Text {
		let noun = itemCount == 1 ? "app" : "apps"
		return Text("You're about to \(Text(mode.verb).bold()) \(itemCount) \(noun) \(mode.destinationText)")
	}
}
