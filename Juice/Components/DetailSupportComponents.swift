import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// Consolidated shared support views/loaders for detail cards and list rows.
// Used by: DetailCardComponents, DetailListItemComponents, DetailContentComponents.

struct ImportAppIconView: View {
	let item: ImportedApplication

	var body: some View {
		#if os(macOS)
		if let image = resolvedIcon() {
			Image(nsImage: image)
				.resizable()
				.scaledToFit()
		} else {
			IconByFiletype(applicationFileName: item.fullFilePath)
		}
		#else
		IconByFiletype(applicationFileName: item.fullFilePath)
		#endif
	}

	#if os(macOS)
	private func resolvedIcon() -> NSImage? {
		if let selected = item.selectedIcon {
			return selected
		}
		if let first = item.availableIcons.first {
			return first
		}
		return nil
	}
	#endif
}

struct LocalFileSizeInlineView: View {
	let filePath: String
	let cachedBytes: Int64?
	let label: String
	let labelFont: Font
	let valueFont: Font

	var body: some View {
		HStack(spacing: 4) {
			Text(label)
				.font(labelFont)
				.foregroundStyle(.secondary)
			LocalFileSizeValueView(
				filePath: filePath,
				cachedBytes: cachedBytes,
				font: valueFont
			)
		}
	}
}

struct LocalFileSizeValueView: View {
	let filePath: String
	let cachedBytes: Int64?
	let font: Font
	@State private var sizeText: String = "—"
	@State private var loadTask: Task<Void, Never>?
	@State private var activeRequestKey: String = ""

	var body: some View {
		Text(sizeText)
			.font(font)
			.foregroundStyle(.secondary)
			.onAppearUnlessPreview {
				updateSize()
			}
			.onChange(of: filePath) { _, _ in
				updateSize()
			}
			.onChange(of: cachedBytes) { _, _ in
				updateSize()
			}
			.onDisappear {
				loadTask?.cancel()
				loadTask = nil
			}
	}

	private func updateSize() {
		loadTask?.cancel()
		loadTask = nil
		let requestKey = "\(filePath)|\(cachedBytes.map(String.init) ?? "nil")"
		activeRequestKey = requestKey
		if let cachedBytes {
			sizeText = formatBytes(cachedBytes)
			return
		}
		guard !filePath.isEmpty else {
			sizeText = "—"
			return
		}
		sizeText = "—"
		loadTask = Task {
			let size = await ImportScanService.computeFileSizeBytes(forPath: filePath)
			guard !Task.isCancelled else { return }
			if let size {
				guard requestKey == activeRequestKey else { return }
				sizeText = formatBytes(size)
			} else {
				guard requestKey == activeRequestKey else { return }
				sizeText = "—"
			}
		}
	}

	private func formatBytes(_ bytes: Int64) -> String {
		let units = ["B", "KB", "MB", "GB", "TB"]
		var value = Double(bytes)
		var index = 0
		while value >= 1024 && index < units.count - 1 {
			value /= 1024
			index += 1
		}
		return String(format: "%.2f %@", value, units[index])
	}
}

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
				Text("")
					.font(font)
					.foregroundStyle(.secondary)
			}
		}
		.onAppearUnlessPreview { loader.load(urlString: urlString) }
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
		VStack(alignment: .trailing, spacing: 0) {
			Text(label)
				.font(labelFont)
				.foregroundStyle(.secondary)
				.padding(.top, 4)
				.padding(.bottom, 0)
			Group {
				if loader.isLoading {
					ProgressView()
						.controlSize(.mini)
				} else if let sizeText = loader.sizeText {
					Text(sizeText)
				} else if loader.isUnavailable {
					Text(" ")
				} else {
					Text("1234mb")
				}
			}
			.font(valueFont)
			.foregroundStyle(loader.isUnavailable ? .secondary : .primary)
			.frame(height: 16, alignment: .trailing)
		}
		.onAppearUnlessPreview { loader.load(urlString: urlString) }
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
				.foregroundStyle(.primary)
			Group {
				if loader.isLoading {
					ProgressView()
						.controlSize(.mini)
				} else if let sizeText = loader.sizeText {
					Text(sizeText)
				} else if loader.isUnavailable {
					Text(" ")
				} else {
					Text(" ")
				}
			}
			.font(valueFont)
			.foregroundStyle(loader.isUnavailable ? .secondary : .primary)
			.frame(height: 16, alignment: .leading)
		}
		.onAppearUnlessPreview { loader.load(urlString: urlString) }
		.onChange(of: urlString) { _, newValue in
			loader.load(urlString: newValue)
		}
	}
}
