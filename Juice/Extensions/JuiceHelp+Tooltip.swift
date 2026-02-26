import SwiftUI
#if os(macOS)
import AppKit
#endif

extension View {
	@ViewBuilder
	func juiceHelp(_ text: String) -> some View {
		self.help(text)
		#if os(macOS)
			.overlay {
				JuiceTooltipOverlay(text: text)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.allowsHitTesting(false)
			}
		#endif
	}

	@ViewBuilder
	func juiceFullValueHelp(
		fullValue: String,
		displayedValue: String? = nil
	) -> some View {
		let normalizedFull = fullValue.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		if normalizedFull.isEmpty {
			self
		} else if let displayedValue {
			let normalizedDisplayed = displayedValue.trimmingCharacters(
				in: .whitespacesAndNewlines
			)
			if normalizedDisplayed == normalizedFull {
				self
			} else {
				self.juiceHelp(normalizedFull)
			}
		} else {
			self.juiceHelp(normalizedFull)
		}
	}
}

#if os(macOS)
private struct JuiceTooltipOverlay: NSViewRepresentable {
	let text: String

	func makeNSView(context: Context) -> NSView {
		let view = NSView(frame: .zero)
		view.toolTip = text
		return view
	}

	func updateNSView(_ nsView: NSView, context: Context) {
		nsView.toolTip = text
	}
}
#endif
