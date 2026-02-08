import SwiftUI

@MainActor
final class RemoteFileSizeLoader: ObservableObject {
	@Published var isLoading = false
	@Published var sizeText: String?
	@Published var isUnavailable = false

	private var currentUrl: String?
	private var task: Task<Void, Never>?

	func load(urlString: String?) {
		task?.cancel()
		currentUrl = urlString

		guard let urlString, !urlString.isEmpty else {
			isLoading = false
			sizeText = nil
			isUnavailable = true
			return
		}

		task = Task {
			if let cached = await RemoteFileSizeService.cachedSizeText(for: urlString) {
				guard currentUrl == urlString else { return }
				isLoading = false
				sizeText = cached
				isUnavailable = false
				return
			}

			guard currentUrl == urlString else { return }
			isLoading = true
			sizeText = nil
			isUnavailable = false

			let resolved = await RemoteFileSizeService.sizeText(for: urlString)
			guard currentUrl == urlString else { return }
			isLoading = false
			if let resolved {
				sizeText = resolved
				isUnavailable = false
			} else {
				sizeText = nil
				isUnavailable = true
			}
		}
	}
}

struct RemoteFileSizeValueView: View {
	let urlString: String?
	let font: Font

	@StateObject private var loader = RemoteFileSizeLoader()

	init(urlString: String?, font: Font = .callout.weight(.medium)) {
		self.urlString = urlString
		self.font = font
	}

	var body: some View {
		HStack(spacing: 6) {
			if loader.isLoading {
				ProgressView()
					.controlSize(.mini)
			} else if let sizeText = loader.sizeText {
				Text(sizeText)
					.font(font)
					.foregroundStyle(.primary)
			} else if loader.isUnavailable {
				Text("Unknown")
					.font(font)
					.foregroundStyle(.secondary)
			}
		}
		.onAppear { loader.load(urlString: urlString) }
		.onChange(of: urlString) { _, newValue in
			loader.load(urlString: newValue)
		}
	}
}

struct RemoteFileSizeInlineView: View {
	let urlString: String?
	let label: String
	let labelFont: Font
	let valueFont: Font

	@StateObject private var loader = RemoteFileSizeLoader()

	init(
		urlString: String?,
		label: String = "Size",
		labelFont: Font = .system(size: 10, weight: .bold),
		valueFont: Font = .system(size: 11, weight: .medium)
	) {
		self.urlString = urlString
		self.label = label
		self.labelFont = labelFont
		self.valueFont = valueFont
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(label)
				.font(labelFont)
				.foregroundStyle(.secondary)
			Group {
				if loader.isLoading {
					ProgressView()
						.controlSize(.mini)
				} else if let sizeText = loader.sizeText {
					Text(sizeText)
				} else if loader.isUnavailable {
					Text("Unknown")
				} else {
					Text(" ")
				}
			}
			.font(valueFont)
			.foregroundStyle(loader.isUnavailable ? .secondary : .primary)
			.frame(height: 16, alignment: .leading)
		}
		.onAppear { loader.load(urlString: urlString) }
		.onChange(of: urlString) { _, newValue in
			loader.load(urlString: newValue)
		}
	}
}

struct RemoteFileSizeInlineHorizontalView: View {
	let urlString: String?
	let label: String
	let labelFont: Font
	let valueFont: Font

	@StateObject private var loader = RemoteFileSizeLoader()

	init(
		urlString: String?,
		label: String = "Size",
		labelFont: Font = .system(size: 10, weight: .bold),
		valueFont: Font = .system(size: 11, weight: .medium)
	) {
		self.urlString = urlString
		self.label = label
		self.labelFont = labelFont
		self.valueFont = valueFont
	}

	var body: some View {
		HStack(alignment: .center, spacing: 4) {
			Text(label)
				.font(labelFont)
				.foregroundStyle(.secondary)
			Group {
				if loader.isLoading {
					ProgressView()
						.controlSize(.mini)
				} else if let sizeText = loader.sizeText {
					Text(sizeText)
				} else if loader.isUnavailable {
					Text("Unknown")
				} else {
					Text(" ")
				}
			}
			.font(valueFont)
			.foregroundStyle(loader.isUnavailable ? .secondary : .primary)
			.frame(height: 16, alignment: .leading)
		}
		.onAppear { loader.load(urlString: urlString) }
		.onChange(of: urlString) { _, newValue in
			loader.load(urlString: newValue)
		}
	}
}
