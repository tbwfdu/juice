import SwiftUI
import WidgetKit

struct ActiveEnvironmentEntryView: View {
	@Environment(\.widgetFamily) private var family
	let entry: ActiveEnvironmentEntry

	var body: some View {
		VStack(alignment: .leading, spacing: family == .systemMedium ? 1 : 0) {
			Text(primaryLine)
				.font(
					family == .systemMedium
						? .headline.weight(.semibold)
						: .subheadline.weight(.semibold)
				)
				.lineLimit(1)
			Text(entry.sharedState.activeEnvironmentHost ?? "Unavailable")
				.font(
					.system(size: 11, weight: .regular)
				)
				.foregroundStyle(.secondary)
				.lineLimit(1)

			Rectangle()
				.frame(height: 2)
				.foregroundStyle(accentColor)
				.opacity(0.85)
				.padding(.vertical, 2)

			contentRows

			Spacer(minLength: 0)

			Text(lastUpdatedLine)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.padding(10)
		.containerBackground(.fill.tertiary, for: .widget)
	}

	@ViewBuilder
	private var contentRows: some View {
		switch entry.loadState {
		case .loaded:
			if family == .systemMedium {

				HStack(alignment: .top, spacing: 10) {
					VStack(alignment: .leading, spacing: 6) {
						metadataRow(
							icon: "list.bullet.rectangle",
							label: "Org Group Name",
							value: entry.sharedState
								.activeEnvironmentOrgGroupName
								?? "Not available"
						)
					}
					VStack(alignment: .leading, spacing: 6) {
						metadataRow(
							icon: "desktopcomputer.and.macbook",
							label: "macOS Devices",
							value: countValue(
								entry.sharedState.activeEnvironmentDeviceCount
							)
						)
					}
					VStack(alignment: .leading, spacing: 6) {
						metadataRow(
							icon: "shippingbox",
							label: "macOS Apps",
							value: countValue(
								entry.sharedState.activeEnvironmentAppCount
							)
						)
					}
				}
			} else {
				VStack(alignment: .leading, spacing: 6) {
					metadataRow(
						icon: "desktopcomputer.and.macbook",
						label: "macOS Devices",
						value: countValue(
							entry.sharedState.activeEnvironmentDeviceCount
						)
					)
					metadataRow(
						icon: "shippingbox",
						label: "macOS Apps",
						value: countValue(
							entry.sharedState.activeEnvironmentAppCount
						)
					)
				}
			}
		case .empty:
			metadataRow(
				icon: "exclamationmark.circle",
				label: "Status",
				value: "No active environment selected"
			)
		case .unavailable:
			metadataRow(
				icon: "xmark.octagon",
				label: "Status",
				value: "Shared widget data is unavailable"
			)
		}
	}

	private func metadataRow(icon: String, label: String, value: String)
		-> some View
	{
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			Image(systemName: icon)
				.font(.system(size: 11, weight: .medium))
				.foregroundStyle(accentColor)
				.frame(width: 14, alignment: .center)
			VStack(alignment: .leading, spacing: 0) {
				Text(label)
					.font(.system(size: 9, weight: .semibold))
					.foregroundStyle(.primary)
				Text(value)
					.font(.system(size: 10, weight: .regular))
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
			}
		}
	}

	private var lastUpdatedLine: String {
		switch entry.loadState {
		case .loaded:
			return "Updated from Juice settings"
		case .empty:
			return "Open Juice to choose an environment"
		case .unavailable:
			return "Open Juice to refresh widget data"
		}
	}

	private var primaryLine: String {
		switch entry.loadState {
		case .loaded:
			return entry.sharedState.activeEnvironmentFriendlyName
				?? "Active environment"
		case .empty:
			return "No active environment"
		case .unavailable:
			return "Widget data unavailable"
		}
	}

	private var accentColor: Color {
		Color.fromHex("#FC642D") ?? .accentColor
	}

	private func countValue(_ value: Int?) -> String {
		guard let value else { return "Not available" }
		return String(value)
	}
}

extension Color {
	fileprivate static func fromHex(_ value: String?) -> Color? {
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

#Preview("Active Env (Small)") {
	ActiveEnvironmentEntryView(
		entry: ActiveEnvironmentEntry(
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

#Preview("Active Env (Medium)") {
	ActiveEnvironmentEntryView(
		entry: ActiveEnvironmentEntry(
			date: .now,
			sharedState: WidgetSharedState(
				activeEnvironmentFriendlyName: "Staging Environment",
				activeEnvironmentOrgGroupName: "Development",
				activeEnvironmentHost: "uat.awmdm.com",
				activeEnvironmentDeviceCount: 42,
				activeEnvironmentAppCount: 156,
				availableUpdatesCount: 5,
				activeEnvironmentAccentTintHex: "#007AFF",
				lastUpdated: .now
			),
			loadState: .loaded
		)
	)
	.frame(width: 345, height: 164)
	//.previewContext(WidgetPreviewContext(family: .systemMedium))
}

#Preview("Active Env (Empty)") {
	ActiveEnvironmentEntryView(
		entry: ActiveEnvironmentEntry(
			date: .now,
			sharedState: .empty,
			loadState: .empty
		)
	)
	.frame(width: 164, height: 164)
}
