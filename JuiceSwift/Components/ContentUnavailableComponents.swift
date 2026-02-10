import SwiftUI

// Shared ContentUnavailableView components.
// Use this file to define reusable empty/error/loading placeholders.

struct EmptyStateContentUnavailableView: View {
	let title: String
	let systemImage: String
	let description: String?

	var body: some View {
		ContentUnavailableView {
			Label(title, systemImage: systemImage)
				.font(.system(size: 17, weight: .regular))
		} description: {
			if let description, !description.isEmpty {
				Text(description)
			}
		}
	}
}

struct NoResultsContentUnavailableView: View {
	let query: String?

	private var titleText: String {
		"No Results"
	}

	private var descriptionText: String {
		if let query, !query.isEmpty {
			return "No matches found for \"\(query)\"."
		}
		return "Try a different search term."
	}

	var body: some View {
		ContentUnavailableView.search(text: query ?? "")
			.overlay(alignment: .bottom) {
				Text(descriptionText)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.padding(.bottom, 20)
			}
	}
}

struct NetworkErrorContentUnavailableView: View {
	let title: String
	let message: String
	let retryTitle: String
	let onRetry: () -> Void

	init(
		title: String = "Couldn’t Load Content",
		message: String = "Check your connection and try again.",
		retryTitle: String = "Retry",
		onRetry: @escaping () -> Void
	) {
		self.title = title
		self.message = message
		self.retryTitle = retryTitle
		self.onRetry = onRetry
	}

	var body: some View {
		ContentUnavailableView {
			Label(title, systemImage: "wifi.exclamationmark")
				.font(.system(size: 17, weight: .regular))
		} description: {
			Text(message)
		} actions: {
			Button(retryTitle, action: onRetry)
		}
	}
}

struct EmptyQueueContentUnavailableView: View {
	let title: String
	let message: String

	init(
		title: String = "Queue Is Empty",
		message: String = "Add apps to the queue to get started."
	) {
		self.title = title
		self.message = message
	}

	var body: some View {
		ContentUnavailableView {
			Label {
				Text(title)
			} icon: {
				ZStack {
					Image(systemName: "apple.meditate")
						.font(.system(size: 24, weight: .regular))
				}
				.symbolRenderingMode(.multicolor)
			}
			.font(.system(size: 17, weight: .regular))
		} description: {
			Text(message)
				.font(.system(size: 12, weight: .regular))
		}.opacity(0.7)
	}
}

struct AllUpToDateContentUnavailableView: View {
	let title: String
	let message: String

	init(
		title: String = "Up to Date",
		message: String = "No updates available"
	) {
		self.title = title
		self.message = message
	}

	var body: some View {
		ContentUnavailableView {
			Label {
				Text(title)
			} icon: {
				ZStack {
					Image(systemName: "checkmark.circle")
						.font(.system(size: 24, weight: .regular))
				}
				.symbolRenderingMode(.hierarchical)
			}
			.font(.system(size: 17, weight: .regular))
		} description: {
			Text(message)
				.font(.system(size: 12, weight: .regular))
		}.opacity(0.7)
	}
}

#Preview("Empty State") {
	EmptyStateContentUnavailableView(
		title: "Nothing Here Yet",
		systemImage: "tray",
		description: "Add items to get started."
	)
	.frame(maxWidth: .infinity, maxHeight: .infinity)
	.padding(24)
}

#Preview("No Results") {
	NoResultsContentUnavailableView(query: "slack")
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding(24)
}

#Preview("Network Error") {
	NetworkErrorContentUnavailableView(
		title: "Couldn’t Reach Server",
		message: "Please check your network settings and try again.",
		retryTitle: "Try Again",
		onRetry: {}
	)
	.frame(maxWidth: .infinity, maxHeight: .infinity)
	.padding(24)
}

#Preview("Empty Queue") {
	EmptyQueueContentUnavailableView()
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding(24)
}

#Preview("All Up To Date") {
	AllUpToDateContentUnavailableView()
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding(24)
}
