//
//  Settings.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 27/1/2026.
//

import Foundation
import os
import SwiftUI

actor UEMService {

	@MainActor private var catalog: LocalCatalog?
	@MainActor func setCatalog(_ catalog: LocalCatalog) { self.catalog = catalog }
	
	// Expose a Singleton-like instance here
	static let instance = UEMService()

	private init() {

	}

	let logPrefix = "UEMService"
	let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "Juice",
		category: "UEMService"
	)

	func getAllOrgGroups() async -> [OrganizationGroup]? {
		
        let token = await AuthService.instance.accessToken
        let isValid = (token?.isEmpty == false)
        if !isValid {
            _ = await AuthService.instance.authenticate()
        }

		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard let baseURL = URL(string: activeEnvironment.uemUrl)
		else { return nil }
		guard
			let url = URL(
				string: "/API/system/groups/search",
				relativeTo: baseURL
			)
		else {
			return nil
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"

		if let token = await AuthService.instance.accessToken {
			request.setValue(
				"Bearer \(token)",
				forHTTPHeaderField: "Authorization"
			)
		}

		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			// Parse top-level JSON as a dictionary
			guard
				let json = try JSONSerialization.jsonObject(
					with: data,
					options: []
				) as? [String: Any]
			else {
				return []
			}

			// Extract the `LocationGroups` payload and decode into Codable models.
			guard let groupsAny = json["LocationGroups"] else {
				return []
			}
			let groupsData = try JSONSerialization.data(
				withJSONObject: groupsAny,
				options: []
			)
			let decoded = try JSONDecoder().decode(
				[OrganizationGroup].self,
				from: groupsData
			)
			return decoded
		} catch {
			logger.error(
				"[\(self.logPrefix)][GetAllOrgGroups] \(String(describing: error), privacy: .public)"
			)
			return []
		}
	}

	func getOrgGroupUuid(id: String? = nil) async -> String? {
		let token = await AuthService.instance.accessToken
		let isValid = (token?.isEmpty == false)
		if !isValid {
			_ = await AuthService.instance.authenticate()
		}
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard let baseURL = URL(string: activeEnvironment.uemUrl)

		else { return nil }

		let orgGroupId =
			(id?.isEmpty == false)
			? id! : activeEnvironment.orgGroupId
		guard !orgGroupId.isEmpty else { return nil }

		guard
			let url = URL(
				string: "/API/system/groups/\(orgGroupId)",
				relativeTo: baseURL
			)
		else {
			return nil
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"

		if let token = await AuthService.instance.accessToken {
			request.setValue(
				"Bearer \(token)",
				forHTTPHeaderField: "Authorization"
			)
		}

		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			// Parse top-level JSON as a dictionary
			guard
				let json = try JSONSerialization.jsonObject(
					with: data,
					options: []
				) as? [String: Any]
			else {
				return nil
			}

			// Extract and coerce UUID to String if present
			let uuidValue = json["Uuid"]
			let uuidString: String?
			if let str = uuidValue as? String {
				uuidString = str
			} else if let num = uuidValue as? NSNumber {
				uuidString = num.stringValue
			} else if let intVal = uuidValue as? Int {
				uuidString = String(intVal)
			} else {
				uuidString = nil
			}

			if let uuidString {
				logger.info(
					"[\(self.logPrefix)] OrgGroup Uuid: \(uuidString, privacy: .public)"
				)
			}

			return uuidString

		} catch {
			logger.error(
				"[\(self.logPrefix)][GetOrgGroupUuid] \(String(describing: error), privacy: .public)"
			)
			return nil
		}
	}

	func getAllApps(includeVersionChecks: Bool = true) async -> [UemApplication?] {
		let token = await AuthService.instance.accessToken
		let isValid = (token?.isEmpty == false)
		if !isValid {
			_ = await AuthService.instance.authenticate()
		}
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard let baseURL = URL(string: activeEnvironment.uemUrl)
		else { return [] }
		guard
			let url = URL(
				string: "/API/mam/apps/search?platform=AppleOsX",
				relativeTo: baseURL
			)
		else {
			return []
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"

		if let token = await AuthService.instance.accessToken {
			request.setValue(
				"Bearer \(token)",
				forHTTPHeaderField: "Authorization"
			)
		}

		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, _) = try await URLSession.shared.data(for: request)

			// Parse top-level JSON as a dictionary
			guard
				let json = try JSONSerialization.jsonObject(
					with: data,
					options: []
				) as? [String: Any]
			else {
				return []
			}

			guard let applications = json["Application"] else {
				return []
			}
			
			let applicationsData = try JSONSerialization.data(
				withJSONObject: applications,
				options: []
			)
			let decoded = try JSONDecoder().decode(
				[UemApplication].self,
				from: applicationsData
			)
			if !includeVersionChecks { return decoded }

			let updatedApps: [UemApplication] = await withTaskGroup(
				of: (Int, UemApplication).self
			) { group in
				for (index, app) in decoded.enumerated() {
					group.addTask {
						let updated = await self.checkForNewerVersion(app)
						return (index, updated)
					}
				}

				var results = Array<UemApplication?>(repeating: nil, count: decoded.count)
				for await (index, updated) in group {
					results[index] = updated
				}

				return results.compactMap { $0 }
			}
			return updatedApps
		} catch {
			logger.error(
				"[\(self.logPrefix)][GetAllApps] \(String(describing: error), privacy: .public)"
			)
			return []
		}
	}

	func checkForExistingApp(
		_ uemApplications: [UemApplication],
		successfulDownload: SuccessfulDownload? = nil,
		importedApplication: ImportedApplication? = nil
	) -> Bool
	{
		var appName = ""
		var appFilename = ""
		var appVersion = ""
		var actualFileVersion = ""
		var bundleIdCandidates: [String] = []

		if let sd = successfulDownload {
			appName = sd.parsedMetadata?.name
				?? sd.parsedMetadata?.display_name
				?? ""
			appFilename = sd.fileName
			actualFileVersion = sd.parsedMetadata?.version
				?? sd.parsedMetadata?.installs?.first?.cfBundleShortVersionString
				?? sd.parsedMetadata?.installs?.first?.cfBundleVersion
				?? ""
			appVersion = buildUemAppVersion(from: actualFileVersion)
			if let cfBundleId = sd.parsedMetadata?.installs?.first?.cfBundleIdentifier,
			   !cfBundleId.isEmpty {
				bundleIdCandidates.append(cfBundleId)
			}
		}

		if let ia = importedApplication {
			appName = ia.parsedMetadata?.name
				?? ia.parsedMetadata?.display_name
				?? ""
			appFilename = ia.fileName
			actualFileVersion = ia.parsedMetadata?.version
				?? ia.parsedMetadata?.installs?.first?.cfBundleShortVersionString
				?? ia.parsedMetadata?.installs?.first?.cfBundleVersion
				?? ""
			appVersion = buildUemAppVersion(from: actualFileVersion)
			if let cfBundleId = ia.parsedMetadata?.installs?.first?.cfBundleIdentifier,
			   !cfBundleId.isEmpty {
				bundleIdCandidates.append(cfBundleId)
			}
		}

		let derivedBundleId = deriveUemBundleId(from: appName)
		if !derivedBundleId.isEmpty { bundleIdCandidates.append(derivedBundleId) }

		logger.info(
			"[\(self.logPrefix)] Checking if App Exists in UEM -> name: \(appName, privacy: .public), bundleId: \(bundleIdCandidates.joined(separator: "|"), privacy: .public), appVersion: \(appVersion, privacy: .public), actualFileVersion: \(actualFileVersion, privacy: .public), fileName: \(appFilename, privacy: .public)"
		)

		let match = uemApplications.contains(where: { app in
			let nameMatch = normalizeForCompare(app.applicationName) == normalizeForCompare(appName)
			let bundleMatch = bundleIdCandidates.contains { candidate in
				normalizeForCompare(candidate) == normalizeForCompare(app.bundleId)
			}
			let appVersionMatch = !appVersion.isEmpty
				&& normalizeVersion(app.appVersion) == normalizeVersion(appVersion)
			let actualVersionMatch = !actualFileVersion.isEmpty
				&& normalizeVersion(app.actualFileVersion) == normalizeVersion(actualFileVersion)
			let versionMatch = appVersionMatch || actualVersionMatch
			return nameMatch && bundleMatch && versionMatch
		})

		logger.debug(
			"[\(self.logPrefix)] Match Results -> matched: \(match)"
		)

		return match
	}

	private func normalizeForCompare(_ value: String) -> String {
		value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
	}

	private func normalizeVersion(_ value: String) -> String {
		value.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private func buildUemAppVersion(from actualFileVersion: String) -> String {
		let trimmed = actualFileVersion.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return "" }
		let parts = trimmed.split(separator: ".")
		if parts.count == 3 {
			let last = parts.last ?? ""
			if last == "0" { return trimmed }
			return "\(trimmed).0"
		}
		if parts.count < 3 {
			let needed = 3 - parts.count
			let padding = Array(repeating: "0", count: needed).joined(separator: ".")
			return "\(trimmed).\(padding)"
		}
		return trimmed
	}

	private func deriveUemBundleId(from appName: String) -> String {
		let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return "" }
		var result = ""
		var lastWasHyphen = false
		for scalar in trimmed.unicodeScalars {
			if CharacterSet.alphanumerics.contains(scalar) {
				result.unicodeScalars.append(scalar)
				lastWasHyphen = false
			} else if scalar == " " || scalar == "-" || scalar == "_" {
				if !lastWasHyphen {
					result.append("-")
					lastWasHyphen = true
				}
			} else {
				if !lastWasHyphen {
					result.append("-")
					lastWasHyphen = true
				}
			}
		}
		let normalized = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
		guard !normalized.isEmpty else { return "" }
		return "com.ws1.macos.\(normalized)"
	}
	
	func checkForNewerVersion(_ uemApplication: UemApplication) async -> UemApplication {
		let funcLogPrefix = "CheckForNewerVersion"
		var uemApp = uemApplication

		do {
			if await MainActor
				.run(resultType: Bool.self, body: { catalog == nil }) {
				let newCatalog: LocalCatalog = await MainActor.run { LocalCatalog() }
				await MainActor.run { self.catalog = newCatalog }
				await newCatalog.loadLocalCatalog()
			}

			let allApplications: [CaskApplication] = await MainActor.run { catalog?.caskApps ?? [] }
			if allApplications.isEmpty {
				logger.debug(
					"[\(funcLogPrefix)] Catalog is empty; skipping match for \(uemApp.applicationName, privacy: .public)"
				)
				return uemApp
			}

			var matchedApp: CaskApplication? = nil
			guard let aliasesURL = Bundle.main.url(forResource: "app_aliases", withExtension: "json") else {
				logger.error(
					"[\(funcLogPrefix)] app_aliases.json not found in bundle resources"
				)
				return uemApp
			}
			try await AppNameComparer.loadAliases(aliasesURL)

			for app in allApplications {
				guard let dbName = app.name.first else { continue }
				let score = await AppNameComparer.score(
					dbName,
					uemApp.applicationName
				)
				let isLikely = score >= 90
				if isLikely {
					logger.debug(
						"[\(funcLogPrefix)] Likely match: \(uemApp.applicationName, privacy: .public)(UEM) to \(dbName, privacy: .public)(DB)"
					)
					matchedApp = app
					uemApp.wasMatched = true
				}
			}

			if let matched = matchedApp {
				guard
					let matchedAppVersion = tryGetVersion(matched.version),
					let uemAppVersion = tryGetVersion(uemApp.appVersion)
				else {
					logger.debug(
						"[\(funcLogPrefix)] Unable to parse versions for \(uemApp.applicationName, privacy: .public)"
					)
					return uemApp
				}

				let isNewer = matchedAppVersion > uemAppVersion
				if isNewer {
					uemApp.updatedApplicationGuid = matched.guid
					uemApp.updatedApplication = matched
					uemApp.hasUpdate = true
				} else {
					uemApp.isLatest = true
				}

				logger.debug(
					"[\(funcLogPrefix)] No updates available for \(uemApp.applicationName, privacy: .public)"
				)
			} else {
				uemApp.wasMatched = false
				logger.debug(
					"[\(funcLogPrefix)] No suitable match found for \(uemApp.applicationName, privacy: .public)"
				)
			}

			return uemApp
		} catch {
			logger.error(
				"[\(funcLogPrefix)] \(String(describing: error), privacy: .public)"
			)
			return uemApp
		}
	}

	private func tryGetVersion(_ value: String?) -> ParsedVersion? {
		guard
			let value,
			!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		else {
			return nil
		}

		let trimmed = value.split(
			separator: ",",
			maxSplits: 1,
			omittingEmptySubsequences: true
		).first ?? Substring(value)
		let candidate = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)

		let parts = candidate.split(separator: ".")
		guard !parts.isEmpty else { return nil }

		var components: [Int] = []
		components.reserveCapacity(parts.count)
		for part in parts {
			guard let number = Int(part) else { return nil }
			components.append(number)
		}

		return ParsedVersion(components: components)
	}

}

private struct ParsedVersion: Comparable {
	let components: [Int]

	static func < (lhs: ParsedVersion, rhs: ParsedVersion) -> Bool {
		let maxCount = max(lhs.components.count, rhs.components.count)
		for index in 0..<maxCount {
			let left = index < lhs.components.count ? lhs.components[index] : 0
			let right = index < rhs.components.count ? rhs.components[index] : 0
			if left != right { return left < right }
		}
		return false
	}
}

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

private enum AppNameComparer {
    private static let store = AppNameAliasStore()

    static func loadAliases(_ url: URL) async throws {
        // Data(contentsOf:) is synchronous and may throw; perform it inside the actor method.
        try await store.loadAliases(from: url)
    }

    static func canonicalize(_ input: String) async -> String {
        await store.canonical(for: input)
    }

    static func normalize(_ input: String) async -> String {
        await store.normalize(input)
    }

    static func score(_ name1: String, _ name2: String) async -> Int {
        let canon1 = await canonicalize(name1)
        let canon2 = await canonicalize(name2)
        let norm1 = await normalize(canon1)
        let norm2 = await normalize(canon2)
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
