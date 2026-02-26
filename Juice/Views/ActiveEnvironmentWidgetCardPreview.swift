import SwiftUI
import WidgetKit

#Preview("Widget Card (Medium)") {
	ActiveEnvironmentEntryView(
		entry: ActiveEnvironmentEntry(
			date: .now,
			sharedState: WidgetSharedState(
				activeEnvironmentFriendlyName: "UAT",
				activeEnvironmentOrgGroupName: "Dropbear Labs (UAT)",
				activeEnvironmentHost: "as1831.awmdm.com",
				activeEnvironmentDeviceCount: 248,
				activeEnvironmentAppCount: 72,
				availableUpdatesCount: 13,
				activeEnvironmentAccentTintHex: "#007CBB",
				lastUpdated: .now
			),
			loadState: .loaded
		)
	)
	.frame(width: 344, height: 164)
	
}

#Preview("Widget Card (Small)") {
	ActiveEnvironmentEntryView(
		entry: ActiveEnvironmentEntry(
			date: .now,
			sharedState: WidgetSharedState(
				activeEnvironmentFriendlyName: "Production",
				activeEnvironmentOrgGroupName: "Global IT",
				activeEnvironmentHost: "prod.awmdm.com",
				activeEnvironmentDeviceCount: 1325,
				activeEnvironmentAppCount: 410,
				availableUpdatesCount: 44,
				activeEnvironmentAccentTintHex: "#007CBB",
				lastUpdated: .now
			),
			loadState: .loaded
		)
	)
	.frame(width: 164, height: 164)
	
}
