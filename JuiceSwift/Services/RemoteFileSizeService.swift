import Foundation

actor RemoteFileSizeCache {
	static let shared = RemoteFileSizeCache()
	private var values: [String: String] = [:]

	func get(_ key: String) -> String? {
		values[key]
	}

	func set(_ key: String, value: String) {
		values[key] = value
	}
}

struct RemoteFileSizeService {
	static func cachedSizeText(for urlString: String) async -> String? {
		await RemoteFileSizeCache.shared.get(urlString)
	}

	static func sizeText(for urlString: String) async -> String? {
		guard !urlString.isEmpty else { return nil }
		if let cached = await RemoteFileSizeCache.shared.get(urlString) {
			return cached
		}
		guard let sizeBytes = await fetchRemoteFileSize(urlString: urlString) else {
			return nil
		}
		let label = formatBytes(sizeBytes)
		await RemoteFileSizeCache.shared.set(urlString, value: label)
		return label
	}

	private static func fetchRemoteFileSize(urlString: String) async -> Int64? {
		guard let url = URL(string: urlString) else { return nil }

		var headRequest = URLRequest(url: url)
		headRequest.httpMethod = "HEAD"
		headRequest.timeoutInterval = 15
		if let size = try? await contentLength(for: headRequest) {
			return size
		}

		var rangeRequest = URLRequest(url: url)
		rangeRequest.httpMethod = "GET"
		rangeRequest.timeoutInterval = 15
		rangeRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")
		return try? await contentLength(for: rangeRequest)
	}

	private static func contentLength(for request: URLRequest) async throws -> Int64? {
		let (_, response) = try await URLSession.shared.data(for: request)
		guard let http = response as? HTTPURLResponse else { return nil }
		if let lengthHeader = http.value(forHTTPHeaderField: "Content-Length"),
		   let length = Int64(lengthHeader) {
			return length
		}
		if let contentRange = http.value(forHTTPHeaderField: "Content-Range") {
			return parseContentRange(contentRange)
		}
		return nil
	}

	private static func parseContentRange(_ value: String) -> Int64? {
		// Example: "bytes 0-0/123456"
		guard let slashIndex = value.lastIndex(of: "/") else { return nil }
		let sizePart = value[value.index(after: slashIndex)...]
		return Int64(sizePart)
	}

	private static func formatBytes(_ bytes: Int64) -> String {
		guard bytes > 0 else { return "0 B" }
		let units: [String] = ["B", "KB", "MB", "GB"]
		let base = 1024.0
		let exponent = min(Int(log(Double(bytes)) / log(base)), units.count - 1)
		let value = Double(bytes) / pow(base, Double(exponent))
		return String(format: "%.1f %@", value, units[exponent])
	}
}
