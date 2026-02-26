//
//  Colors.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 27/1/2026.
//
import SwiftUI

extension Color {
    init(_ hex: String) {
        self.init(hex: hex)
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension LinearGradient {
	static var juice: LinearGradient {
		LinearGradient(
			stops: [
				.init(color: Color(hex: "#FCB900"), location: 0.0),
				.init(color: Color(hex: "#FC642D"), location: 0.3),
				.init(color: Color(hex: "#FF2E92"), location: 0.6),
				.init(color: Color(hex: "#004CFF"), location: 1.0)
			],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	static var juiceLeadingDuo: LinearGradient {
		LinearGradient(
			stops: [
				.init(color: Color(hex: "#FCB900"), location: 0.0),
				.init(color: Color(hex: "#FC642D"), location: 1.0)
			],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}

	static var navSelection: LinearGradient {
		LinearGradient(
			stops: [
				.init(color: Color(hex: "#E24A1C"), location: 0.0),
				.init(color: Color(hex: "#DC1A78"), location: 1.0)
			],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
	}
}

extension RadialGradient {
	static var navSelection: RadialGradient {
		RadialGradient(
			stops: [
				.init(color: Color(hex: "#E24A1C"), location: 0.0),
				.init(color: Color(hex: "#DC1A78"), location: 1.0)
			],
			center: .topLeading,
			startRadius: 2,
			endRadius: 26
		)
	}

	static var navSelectionWithJuiceAccent: RadialGradient {
		RadialGradient(
			stops: [
				.init(color: Color(hex: "#E24A1C"), location: 0.0),
				.init(color: Color(hex: "#DC1A78"), location: 0.6),
				.init(color: Color(hex: "#FF2E92"), location: 1.0)
			],
			center: .topLeading,
			startRadius: 2,
			endRadius: 26
		)
	}
}
