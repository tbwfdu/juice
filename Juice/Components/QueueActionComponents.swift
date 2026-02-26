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
	let mode: ConfirmationActionMode
	let itemCount: Int
	let title: String
	let confirmTitle: String
	let cancelTitle: String
	let onConfirm: () -> Void
	let onCancel: () -> Void

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
		JuiceConfirmationSheet(
			title: title,
			message: messageText,
			secondaryNote: "Applications obtained using Juice are licensed to you by its owner. Juice and related services are not responsible for, nor does it grant any licenses to, third-party packages.",
			confirmTitle: confirmTitle,
			cancelTitle: cancelTitle,
			onConfirm: onConfirm,
			onCancel: onCancel
		)
	}

	private var messageText: String {
		let noun = itemCount == 1 ? "app" : "apps"
		return "You're about to \(mode.verb) \(itemCount) \(noun) \(mode.destinationText)"
	}
}
