import Foundation
import Security

struct WidgetSharedState: Codable {
	static let appGroupIdentifier = "ZV33P8H324.group.com.tbwfdu.juice"
	static let appGroupEntitlementKey = "com.apple.security.application-groups"
	static let activeEnvironmentCardKey = "juice.widget.activeEnvironmentCard"
	static let activeEnvironmentCardFilename = "juice.widget.activeEnvironmentCard.json"
	static let widgetKind = "com.tbwfdu.juice.widget.activeEnvironment"
	static let updatesWidgetKind = "com.tbwfdu.juice.widget.availableUpdates"
	static let deepLinkURLString = "juice://settings/environments"
	static let updatesDeepLinkURLString = "juice://updates"

	var activeEnvironmentFriendlyName: String?
	var activeEnvironmentOrgGroupName: String?
	var activeEnvironmentHost: String?
	var activeEnvironmentDeviceCount: Int?
	var activeEnvironmentAppCount: Int?
	var availableUpdatesCount: Int?
	var activeEnvironmentAccentTintHex: String?
	var lastUpdated: Date

	static var empty: WidgetSharedState {
		WidgetSharedState(
			activeEnvironmentFriendlyName: nil,
			activeEnvironmentOrgGroupName: nil,
			activeEnvironmentHost: nil,
			activeEnvironmentDeviceCount: nil,
			activeEnvironmentAppCount: nil,
			availableUpdatesCount: nil,
			activeEnvironmentAccentTintHex: nil,
			lastUpdated: Date()
		)
	}

	static var candidateAppGroupIdentifiers: [String] {
		var identifiers = [appGroupIdentifier]
		
		// 1. Try to find actually entitled groups at runtime
		if let entitledGroups = entitledAppGroups() {
			for group in entitledGroups {
				if !identifiers.contains(group) {
					identifiers.append(group)
				}
			}
		}

		// 2. Fallback: if we didn't find any prefixed ones, but we have a team ID in the main bundle ID or similar
		// On macOS, the group identifier in the code often MUST be prefixed with the Team ID.
		// We'll try to find any prefixed version of our known group ID.
		// However, it's safer to just rely on what we found in entitlements.
		
		return identifiers
	}

	static func entitledAppGroups() -> [String]? {
		guard let task = SecTaskCreateFromSelf(nil) else { return nil }
		guard
			let value = SecTaskCopyValueForEntitlement(
				task,
				appGroupEntitlementKey as CFString,
				nil
			)
		else {
			return nil
		}
		return value as? [String]
	}

	static func hasRequiredAppGroupEntitlement() -> Bool {
		guard let groups = entitledAppGroups() else { return false }
		return groups.contains(where: { $0.caseInsensitiveCompare(appGroupIdentifier) == .orderedSame })
			|| groups.contains(where: { $0.hasSuffix(".\(appGroupIdentifier)") })
	}
}
