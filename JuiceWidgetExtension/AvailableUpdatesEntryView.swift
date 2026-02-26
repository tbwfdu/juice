import SwiftUI
import WidgetKit

struct AvailableUpdatesEntryView: View {
	let entry: AvailableUpdatesEntry

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Spacer(minLength: 10)
			Text(
				entry.sharedState.activeEnvironmentFriendlyName ?? "Unknown OG"
			)
			.font(.system(size: 16).weight(.semibold))
			.lineLimit(1)

			//			Text(entry.sharedState.activeEnvironmentHost ?? "Unknown")
			//				.font(.system(size: 11, weight: .regular))
			//				.foregroundStyle(.secondary)
			//				.lineLimit(1)

			Rectangle()
				.frame(height: 2)
				.foregroundStyle(accentColor)
				.opacity(0.85)
				.padding(.bottom, 2)
			HStack(alignment: .firstTextBaseline, spacing: 4) {
				Image(systemName: "arrow.triangle.2.circlepath")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(accentColor)
					.frame(width: 14, alignment: .center)
					.padding(.leading, 2)
				VStack(alignment: .leading, spacing: 0) {
					Text("Available Updates")
						.font(.system(size: 10, weight: .medium))
						.foregroundStyle(.primary)
				}
			}

			HStack(alignment: .center) {
				Spacer(minLength: 0)
				VStack(spacing: 0) {
					Text(valueLine)
						.font(.system(size: 50, weight: .bold))
						.foregroundStyle(.primary)
						.lineLimit(1)
						.padding(0)

				}
				Spacer(minLength: 0)
			}
			VStack(alignment: .leading) {
				Text("Updated:")
					.font(.system(size: 10, weight: .regular))
					.foregroundStyle(.tertiary)
					.lineLimit(1)

				Text(
					entry.sharedState
						.lastUpdated
						.formatted(
							date: .abbreviated,
							time: .shortened
						)
				)
				.font(.system(size: 10, weight: .regular))
				.foregroundStyle(.tertiary)
				.lineLimit(1)
				Text(footerLine)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
		.padding(.bottom, 10)
		//.padding(.horizontal, 5)
		.containerBackground(.fill.tertiary, for: .widget)
		.widgetURL(URL(string: WidgetSharedState.updatesDeepLinkURLString))
	}

	private var accentColor: Color {
		Color.availableUpdatesFromHex("#FC642D") ?? .accentColor
	}

	private var primaryLine: String {
		switch entry.loadState {
		case .loaded:
			return "Available Updates"
		case .empty:
			return "No updates data"
		case .unavailable:
			return "Widget data unavailable"
		}
	}

	private var secondaryLine: String {
		switch entry.loadState {
		case .loaded:
			return "Workspace ONE apps"
		case .empty:
			return "Run a query in Juice"
		case .unavailable:
			return "Open Juice to refresh widget data"
		}
	}

	private var valueLine: String {
		switch entry.loadState {
		case .loaded:
			if let count = entry.sharedState.availableUpdatesCount {
				return String(count)
			}
			return "Not available"
		case .empty:
			return "0"
		case .unavailable:
			return "--"
		}
	}

	private var footerLine: String {
		switch entry.loadState {
		case .loaded:
			return "Tap to Update"
		case .empty:
			return "Open Juice and query updates"
		case .unavailable:
			return "Open Juice to refresh"
		}
	}
}

extension Color {
	fileprivate static func availableUpdatesFromHex(_ value: String?) -> Color?
	{
		guard var hex = value?.trimmingCharacters(in: .whitespacesAndNewlines),
			!hex.isEmpty
		else {
			return nil
		}
		if hex.hasPrefix("#") {
			hex.removeFirst()
		}
		guard hex.count == 6 || hex.count == 8 else { return nil }
		var rawValue: UInt64 = 0
		guard Scanner(string: hex).scanHexInt64(&rawValue) else { return nil }
		let red: Double
		let green: Double
		let blue: Double
		let alpha: Double
		if hex.count == 8 {
			red = Double((rawValue & 0xFF00_0000) >> 24) / 255.0
			green = Double((rawValue & 0x00FF_0000) >> 16) / 255.0
			blue = Double((rawValue & 0x0000_FF00) >> 8) / 255.0
			alpha = Double(rawValue & 0x0000_00FF) / 255.0
		} else {
			red = Double((rawValue & 0xFF0000) >> 16) / 255.0
			green = Double((rawValue & 0x00FF00) >> 8) / 255.0
			blue = Double(rawValue & 0x0000FF) / 255.0
			alpha = 1.0
		}
		return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
	}
}

#Preview("Available Updates (Small)") {
	AvailableUpdatesEntryView(
		entry: AvailableUpdatesEntry(
			date: .now,
			sharedState: WidgetSharedState(
				activeEnvironmentFriendlyName: "Production",
				activeEnvironmentOrgGroupName: "Global IT",
				activeEnvironmentHost: "prod.awmdm.com",
				activeEnvironmentDeviceCount: 1325,
				activeEnvironmentAppCount: 410,
				availableUpdatesCount: 27,
				activeEnvironmentAccentTintHex: "#FC642D",
				lastUpdated: .now
			),
			loadState: .loaded
		)
	)
	.frame(width: 164, height: 164)
}

#Preview("Available Updates (Empty)") {
	AvailableUpdatesEntryView(
		entry: AvailableUpdatesEntry(
			date: .now,
			sharedState: .empty,
			loadState: .empty
		)
	)
	.frame(width: 164, height: 164)
}
