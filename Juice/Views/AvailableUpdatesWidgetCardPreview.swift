import SwiftUI
import WidgetKit

#Preview("Available Updates (Small)") {
	VStack {
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
		.padding(.horizontal, 10)
		.padding(.vertical, 5)
		.frame(width: 170, height: 170).border(Color.black)
		
	}.frame(width: 300, height: 300)
		
}

#Preview("Available Updates (Empty)") {
	VStack {
		AvailableUpdatesEntryView(
			entry: AvailableUpdatesEntry(
				date: .now,
				sharedState: .empty,
				loadState: .empty
			)
		)
		.frame(width: 170, height: 170).border(Color.black)
	}
	.frame(width: 300, height: 300)
	.padding(10)
}
