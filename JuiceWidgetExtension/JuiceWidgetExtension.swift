import SwiftUI
import WidgetKit

@main
struct JuiceWidgetExtensionBundle: WidgetBundle {
	var body: some Widget {
		ActiveEnvironmentWidget()
		AvailableUpdatesWidget()
	}
}

struct ActiveEnvironmentWidget: Widget {
	let kind: String = WidgetSharedState.widgetKind

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: ActiveEnvironmentProvider()) { entry in
			ActiveEnvironmentEntryView(entry: entry)
		}
		.configurationDisplayName("Active Environment")
		.description("Shows the currently active Workspace ONE UEM environment.")
		.supportedFamilies([WidgetFamily.systemSmall, WidgetFamily.systemMedium])
	}
}

struct AvailableUpdatesWidget: Widget {
	let kind: String = WidgetSharedState.updatesWidgetKind

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: AvailableUpdatesProvider()) { entry in
			AvailableUpdatesEntryView(entry: entry)
		}
		.configurationDisplayName("Available Updates")
		.description("Shows how many app updates are currently available in Juice.")
		.supportedFamilies([WidgetFamily.systemSmall])
	}
}
