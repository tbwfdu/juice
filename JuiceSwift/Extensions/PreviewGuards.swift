import SwiftUI

extension ProcessInfo {
	static var isRunningForPreviews: Bool {
		ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
	}
}

extension View {
	func onAppearUnlessPreview(perform action: @escaping () -> Void) -> some View {
		onAppear {
			guard !ProcessInfo.isRunningForPreviews else { return }
			action()
		}
	}
}
