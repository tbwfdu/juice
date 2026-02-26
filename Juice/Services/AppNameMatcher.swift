import Foundation

private actor AppNameAliasStore {
	private var aliasMap: [String: String] = [:]
	private var isLoaded = false

	func canonical(for input: String) -> String {
		let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return "" }
		let lower = trimmed.lowercased()
		return aliasMap[lower] ?? lower
	}

	func normalize(_ input: String) -> String {
		let lowercased = input.lowercased()
		var scalars: [UnicodeScalar] = []
		scalars.reserveCapacity(lowercased.count)
		for scalar in lowercased.unicodeScalars {
			switch scalar.value {
			case 48...57, 97...122:
				scalars.append(scalar)
			default:
				continue
			}
		}
		return String(String.UnicodeScalarView(scalars))
	}

	func loadAliases(from url: URL) async throws {
		if isLoaded { return }
		let data = try Data(contentsOf: url)
		let decoded = try JSONDecoder().decode([String: String].self, from: data)
		var normalized: [String: String] = [:]
		normalized.reserveCapacity(decoded.count)
		for (key, value) in decoded {
			normalized[key.lowercased()] = value
		}
		aliasMap = normalized
		isLoaded = true
	}
}

enum AppNameMatcher {
	private static let store = AppNameAliasStore()

	static func loadAliases(_ url: URL) async throws {
		try await store.loadAliases(from: url)
	}

	static func score(_ name1: String, _ name2: String) async -> Int {
		let canon1 = await store.canonical(for: name1)
		let canon2 = await store.canonical(for: name2)
		let norm1 = await store.normalize(canon1)
		let norm2 = await store.normalize(canon2)
		return fuzzyRatio(norm1, norm2)
	}

	private static func fuzzyRatio(_ left: String, _ right: String) -> Int {
		let maxLength = max(left.count, right.count)
		guard maxLength > 0 else { return 100 }
		let distance = levenshteinDistance(left, right)
		let ratio = 1.0 - (Double(distance) / Double(maxLength))
		return Int((ratio * 100.0).rounded())
	}

	private static func levenshteinDistance(_ left: String, _ right: String) -> Int {
		let leftChars = Array(left)
		let rightChars = Array(right)
		let leftCount = leftChars.count
		let rightCount = rightChars.count

		if leftCount == 0 { return rightCount }
		if rightCount == 0 { return leftCount }

		var prev = Array(0...rightCount)
		var curr = Array(repeating: 0, count: rightCount + 1)

		for i in 1...leftCount {
			curr[0] = i
			for j in 1...rightCount {
				let cost = leftChars[i - 1] == rightChars[j - 1] ? 0 : 1
				let deletion = prev[j] + 1
				let insertion = curr[j - 1] + 1
				let substitution = prev[j - 1] + cost
				curr[j] = min(deletion, insertion, substitution)
			}
			prev = curr
		}

		return prev[rightCount]
	}
}
