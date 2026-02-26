import SwiftUI
#if os(macOS)
	import AppKit
#endif

@MainActor
final class JuiceStyleConfig: ObservableObject {
	static let defaultTintHex = "#FC642D"
	static let defaultAccentHex = "#FC642D"
	static let defaultAccentColor = Color(
		.displayP3,
		red: 252 / 255,
		green: 100 / 255,
		blue: 45 / 255
	)
	static let shared = JuiceStyleConfig()

	@Published var prominentButtonTintHex: String

	var prominentButtonTintColor: Color {
		Color(hex: prominentButtonTintHex)
	}

	private init() {
		self.prominentButtonTintHex = Self.defaultTintHex
	}

	func applyProminentTint(hex: String?) {
		let sanitized = Self.sanitizedHex(hex) ?? Self.defaultTintHex
		if prominentButtonTintHex != sanitized {
			prominentButtonTintHex = sanitized
		}
	}

	static func sanitizedHex(_ value: String?) -> String? {
		guard let value else { return nil }
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
		guard hex.count == 6, Int(hex, radix: 16) != nil else { return nil }
		return "#\(hex.uppercased())"
	}

	static func spectrumColor(at position: Double) -> Color {
		let stops: [Color] = [
			Color(hex: "#FCB900"),
			Color(hex: "#FC642D"),
			Color(hex: "#FF2E92"),
			Color(hex: "#004CFF"),
		]
		let clamped = min(max(position, 0), 1)
		let segmentCount = max(stops.count - 1, 1)
		let scaled = clamped * Double(segmentCount)
		let lower = min(Int(floor(scaled)), segmentCount - 1)
		let upper = min(lower + 1, segmentCount)
		let localT = scaled - Double(lower)
		return interpolateColor(from: stops[lower], to: stops[upper], t: localT)
	}

	static func spectrumPosition(forHex hex: String?) -> Double {
		guard let sanitized = sanitizedHex(hex),
			let target = rgbComponents(from: Color(hex: sanitized))
		else {
			return 1.0 / 3.0
		}

		var bestT = 1.0 / 3.0
		var bestDistance = Double.greatestFiniteMagnitude
		for step in 0...300 {
			let t = Double(step) / 300.0
			guard let sample = rgbComponents(from: spectrumColor(at: t)) else {
				continue
			}
			let dr = sample.r - target.r
			let dg = sample.g - target.g
			let db = sample.b - target.b
			let distance = dr * dr + dg * dg + db * db
			if distance < bestDistance {
				bestDistance = distance
				bestT = t
			}
		}
		return bestT
	}

	static func hexString(from color: Color) -> String? {
		#if os(macOS)
			let nsColor = NSColor(color).usingColorSpace(.deviceRGB)
			guard let rgb = nsColor else { return nil }
			let red = Int(round(rgb.redComponent * 255))
			let green = Int(round(rgb.greenComponent * 255))
			let blue = Int(round(rgb.blueComponent * 255))
			return String(format: "#%02X%02X%02X", red, green, blue)
		#else
			return nil
		#endif
	}

	private struct RGB {
		let r: Double
		let g: Double
		let b: Double
	}

	private static func interpolateColor(from: Color, to: Color, t: Double) -> Color {
		guard let start = rgbComponents(from: from), let end = rgbComponents(from: to)
		else {
			return from
		}
		let clamped = min(max(t, 0), 1)
		return Color(
			.sRGB,
			red: start.r + (end.r - start.r) * clamped,
			green: start.g + (end.g - start.g) * clamped,
			blue: start.b + (end.b - start.b) * clamped,
			opacity: 1
		)
	}

	private static func rgbComponents(from color: Color) -> RGB? {
		#if os(macOS)
			guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else {
				return nil
			}
			return RGB(
				r: Double(rgb.redComponent),
				g: Double(rgb.greenComponent),
				b: Double(rgb.blueComponent)
			)
		#else
			return nil
		#endif
	}
}
