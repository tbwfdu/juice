import Foundation
import WidgetKit

struct ActiveEnvironmentEntry: TimelineEntry {
	enum LoadState {
		case loaded
		case empty
		case unavailable
	}

	let date: Date
	let sharedState: WidgetSharedState
	let loadState: LoadState
}

struct ActiveEnvironmentProvider: TimelineProvider {
	func placeholder(in context: Context) -> ActiveEnvironmentEntry {
		ActiveEnvironmentEntry(
			date: Date(),
			sharedState: WidgetSharedState(
				activeEnvironmentFriendlyName: "Production",
				activeEnvironmentOrgGroupName: "Prod OG",
				activeEnvironmentHost: "prod.awmdm.com",
				activeEnvironmentDeviceCount: 1200,
				activeEnvironmentAppCount: 340,
				availableUpdatesCount: 27,
				activeEnvironmentAccentTintHex: "#007CBB",
				lastUpdated: Date()
			),
			loadState: .loaded
		)
	}

	func getSnapshot(in context: Context, completion: @escaping (ActiveEnvironmentEntry) -> Void) {
		completion(loadEntry())
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveEnvironmentEntry>) -> Void) {
		let entry = loadEntry()
		let refreshDate = Date().addingTimeInterval(15 * 60)
		completion(Timeline(entries: [entry], policy: .after(refreshDate)))
	}

	private func loadEntry() -> ActiveEnvironmentEntry {
		var sawReadFailure = false
		var sawDecodeFailure = false
		let fileURLs = candidateFileURLs()
		for fileURL in fileURLs {
			let data: Data
			do {
				data = try Data(contentsOf: fileURL)
			} catch {
				sawReadFailure = true
				continue
			}
			guard !data.isEmpty else { continue }

			guard let decoded = try? JSONDecoder().decode(WidgetSharedState.self, from: data) else {
				sawDecodeFailure = true
				continue
			}

			let isEmpty = (decoded.activeEnvironmentFriendlyName?.isEmpty != false)
			if isEmpty {
				continue
			}
			return ActiveEnvironmentEntry(
				date: Date(),
				sharedState: decoded,
				loadState: .loaded
			)
		}

		if fileURLs.isEmpty {
			return ActiveEnvironmentEntry(
				date: Date(),
				sharedState: .empty,
				loadState: .unavailable
			)
		}

		return ActiveEnvironmentEntry(
			date: Date(),
			sharedState: .empty,
			loadState: (sawReadFailure || sawDecodeFailure) ? .unavailable : .empty
		)
	}

	private func candidateFileURLs() -> [URL] {
		var urls: [URL] = []
		for identifier in WidgetSharedState.candidateAppGroupIdentifiers {
			if let containerURL = FileManager.default.containerURL(
				forSecurityApplicationGroupIdentifier: identifier
			) {
				urls.append(
					containerURL.appendingPathComponent(
						WidgetSharedState.activeEnvironmentCardFilename,
						isDirectory: false
					)
				)
			}
		}
		return urls
	}
}
