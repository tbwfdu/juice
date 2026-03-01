//
//  Settings.swift
//  Juice
//
//  Created by Pete Lindley on 27/1/2026.
//

import Foundation
import os
import SwiftUI
#if os(macOS)
	import AppKit
#endif

actor UEMService {
	enum GetAllAppsError: Error {
		case authenticationFailed
		case invalidBaseURL
		case invalidEndpointURL
		case transport(Error)
		case invalidResponse
		case httpStatus(Int)
		case malformedPayload
		case decoding(Error)
	}

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
		guard let authHeaders = await AuthService.instance.authorizationHeaders(
			for: activeEnvironment
		) else {
			return []
		}
		for (header, value) in authHeaders {
			request.setValue(value, forHTTPHeaderField: header)
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

	func getAllOrgGroups(environment: UemEnvironment) async -> [OrganizationGroup]? {
		guard let baseURL = URL(string: environment.uemUrl) else { return nil }
		guard
			let url = URL(
				string: "/API/system/groups/search",
				relativeTo: baseURL
			)
		else {
			return nil
		}

		guard let authHeaders = await AuthService.instance.authorizationHeaders(
			for: environment
		) else {
			return []
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		for (header, value) in authHeaders {
			request.setValue(value, forHTTPHeaderField: header)
		}
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			guard
				let json = try JSONSerialization.jsonObject(
					with: data,
					options: []
				) as? [String: Any]
			else {
				return []
			}

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
				"[\(self.logPrefix)][GetAllOrgGroupsForEnvironment] \(String(describing: error), privacy: .public)"
			)
			return []
		}
	}

	func getOrgGroupUuid(id: String? = nil) async -> String? {
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
		guard let authHeaders = await AuthService.instance.authorizationHeaders(
			for: activeEnvironment
		) else {
			return nil
		}
		for (header, value) in authHeaders {
			request.setValue(value, forHTTPHeaderField: header)
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

	func getOrgGroupUuid(environment: UemEnvironment, id: String) async -> String? {
		let orgGroupId = id.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !orgGroupId.isEmpty else { return nil }
		guard let baseURL = URL(string: environment.uemUrl) else { return nil }

		guard
			let url = URL(
				string: "/API/system/groups/\(orgGroupId)",
				relativeTo: baseURL
			)
		else {
			return nil
		}

		guard let authHeaders = await AuthService.instance.authorizationHeaders(
			for: environment
		) else {
			return nil
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		for (header, value) in authHeaders {
			request.setValue(value, forHTTPHeaderField: header)
		}
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			guard
				let json = try JSONSerialization.jsonObject(
					with: data,
					options: []
				) as? [String: Any]
			else {
				return nil
			}

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
					"[\(self.logPrefix)][GetOrgGroupUuidForEnvironment] OrgGroup Uuid: \(uuidString, privacy: .public)"
				)
			}

			return uuidString
		} catch {
			logger.error(
				"[\(self.logPrefix)][GetOrgGroupUuidForEnvironment] \(String(describing: error), privacy: .public)"
			)
			return nil
		}
	}

	func getActiveEnvironmentDetails() async -> ActiveEnvironmentDetails? {
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		return await getActiveEnvironmentDetails(environment: activeEnvironment)
	}

	func getActiveEnvironmentDetails(environment: UemEnvironment) async -> ActiveEnvironmentDetails? {
		let orgGroupId = environment.orgGroupId.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		guard !orgGroupId.isEmpty else {
			logger.error(
				"[\(self.logPrefix)][GetActiveEnvironmentDetails] Missing OrganizationGroupId on environment \(environment.friendlyName, privacy: .public)"
			)
			return nil
		}
		guard let baseURL = URL(string: environment.uemUrl) else {
			logger.error(
				"[\(self.logPrefix)][GetActiveEnvironmentDetails] Invalid UEM URL"
			)
			return nil
		}
		guard
			let url = URL(
				string: "/API/system/groups/\(orgGroupId)/children",
				relativeTo: baseURL
			)
		else {
			logger.error(
				"[\(self.logPrefix)][GetActiveEnvironmentDetails] Invalid details endpoint URL"
			)
			return nil
		}
		guard let authHeaders = await AuthService.instance.authorizationHeaders(
			for: environment
		) else {
			logger.error(
				"[\(self.logPrefix)][GetActiveEnvironmentDetails] Unable to obtain auth headers"
			)
			return nil
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		for (header, value) in authHeaders {
			request.setValue(value, forHTTPHeaderField: header)
		}
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let httpResponse = response as? HTTPURLResponse else {
				logger.error(
					"[\(self.logPrefix)][GetActiveEnvironmentDetails] Non-HTTP response"
				)
				return nil
			}
			guard (200...299).contains(httpResponse.statusCode) else {
				logger.error(
					"[\(self.logPrefix)][GetActiveEnvironmentDetails] HTTP \(httpResponse.statusCode, privacy: .public) for orgGroupId=\(orgGroupId, privacy: .public)"
				)
				return nil
			}

			let items = try JSONDecoder().decode(
				[OrganizationGroupChildrenResponseItem].self,
				from: data
			)
			guard !items.isEmpty else {
				logger.info(
					"[\(self.logPrefix)][GetActiveEnvironmentDetails] Empty children list for orgGroupId=\(orgGroupId, privacy: .public)"
				)
				return ActiveEnvironmentDetails(
					parentDeviceCount: nil,
					parentAdminCount: nil,
					childOrganizationGroupCount: 0,
					appCount: nil,
					parentGroupName: nil,
					parentGroupId: nil,
					parentGroupUuid: nil
				)
			}

			let parentResolution = resolveParentGroup(
				from: items,
				environment: environment
			)
			let parent = parentResolution.item
			let parentDeviceCount = parseCount(parent.devices)
			let parentAdminCount = parseCount(parent.admins)
			let childCount = parentResolution.foundInList
				? max(0, items.count - 1)
				: items.count

			logger.info(
				"[\(self.logPrefix)][GetActiveEnvironmentDetails] orgGroupId=\(orgGroupId, privacy: .public), parentMatch=\(parentResolution.strategy, privacy: .public), parentName=\(parent.name ?? "nil", privacy: .public), parentDevices=\(String(describing: parentDeviceCount), privacy: .public), parentAdmins=\(String(describing: parentAdminCount), privacy: .public), childCount=\(childCount, privacy: .public)"
			)

			return ActiveEnvironmentDetails(
				parentDeviceCount: parentDeviceCount,
				parentAdminCount: parentAdminCount,
				childOrganizationGroupCount: childCount,
				appCount: nil,
				parentGroupName: parent.name,
				parentGroupId: parent.groupId ?? parent.id?.value.map(String.init),
				parentGroupUuid: parent.uuid
			)
		} catch {
			logger.error(
				"[\(self.logPrefix)][GetActiveEnvironmentDetails] \(String(describing: error), privacy: .public)"
			)
			return nil
		}
	}

	func getOrgGroupBrandingConfig(
		environment: UemEnvironment,
		preferCached: Bool = true
	) async -> BrandingConfig? {
		let orgGroupUuid = environment.orgGroupUuid.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		if preferCached,
			let cached = loadCachedOrgGroupBrandingConfig(
				orgGroupUUID: orgGroupUuid
			)
		{
			return cached
		}

		do {
			logger.info("[\(self.logPrefix)][GetOrgGroupBrandingConfig] Getting Org Group Access Token")
			guard let authHeaders = await AuthService.instance.authorizationHeaders(
				for: environment
			) else {
				return nil
			}

			logger.info("[\(self.logPrefix)][GetOrgGroupBrandingConfig] Getting Org Group Branding")
			guard let baseURL = URL(string: environment.uemUrl) else {
				logger.error("[\(self.logPrefix)][GetOrgGroupBrandingConfig] Invalid UEM URL")
				return nil
			}
			guard
				let url = URL(
					string: "/API/system/groups/\(environment.orgGroupUuid)/branding",
					relativeTo: baseURL
				)
			else {
				logger.error("[\(self.logPrefix)][GetOrgGroupBrandingConfig] Invalid Branding URL")
				return nil
			}

			var request = URLRequest(url: url)
			request.httpMethod = "GET"
			for (header, value) in authHeaders {
				request.setValue(value, forHTTPHeaderField: header)
			}
			request.setValue("application/json", forHTTPHeaderField: "Accept")

			let (data, response) = try await URLSession.shared.data(for: request)
			guard let httpResponse = response as? HTTPURLResponse else {
				logger.error("[\(self.logPrefix)][GetOrgGroupBrandingConfig] Non-HTTP response")
				return nil
			}
				guard (200...299).contains(httpResponse.statusCode) else {
					logger.error(
						"[\(self.logPrefix)][GetOrgGroupBrandingConfig] HTTP \(httpResponse.statusCode, privacy: .public)"
					)
					return nil
				}

				if let rawJson = String(data: data, encoding: .utf8) {
					logger.info(
						"[\(self.logPrefix)][GetOrgGroupBrandingConfig] Raw response: \(rawJson, privacy: .public)"
					)
				}

				let decoded = try JSONDecoder().decode(BrandingConfig.self, from: data)
				logger.info(
					"[\(self.logPrefix)][GetOrgGroupBrandingConfig] Decoded config -> themeCssUrl: \(decoded.themeCssUrl ?? "nil", privacy: .public), primaryLogoUrl: \(decoded.primaryLogoUrl ?? "nil", privacy: .public), logoUrl: \(decoded.logoUrl ?? "nil", privacy: .public), logoAltText: \(decoded.logoAltText ?? "nil", privacy: .public)"
				)
				if let colors = decoded.brandingColor {
					logger.info(
						"[\(self.logPrefix)][GetOrgGroupBrandingConfig] Decoded colors -> headerColor: \(colors.headerColor ?? "nil", privacy: .public), headerFontColor: \(colors.headerFontColor ?? "nil", privacy: .public), navigationColor: \(colors.navigationColor ?? "nil", privacy: .public), navigationFontColor: \(colors.navigationFontColor ?? "nil", privacy: .public), highlightColor: \(colors.highlightColor ?? "nil", privacy: .public), highlightFontColor: \(colors.highlightFontColor ?? "nil", privacy: .public)"
					)
				}
				saveOrgGroupBrandingConfig(
					decoded,
					orgGroupUUID: orgGroupUuid
				)
				return decoded
			} catch {
			logger.error(
				"[\(self.logPrefix)][GetOrgGroupBrandingConfig] \(String(describing: error), privacy: .public)"
			)
			return nil
		}
	}

	private func parseCount(_ raw: String?) -> Int? {
		guard let raw else { return nil }
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		return Int(trimmed)
	}

	private func resolveParentGroup(
		from items: [OrganizationGroupChildrenResponseItem],
		environment: UemEnvironment
	) -> (item: OrganizationGroupChildrenResponseItem, foundInList: Bool, strategy: String) {
		let environmentGroupId = environment.orgGroupId.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let environmentGroupUuid = environment.orgGroupUuid.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let normalizedEnvGroupId = environmentGroupId.lowercased()
		let normalizedEnvGroupUuid = environmentGroupUuid.lowercased()

		if !normalizedEnvGroupId.isEmpty,
			let match = items.first(where: {
				($0.groupId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "")
					== normalizedEnvGroupId
			})
		{
			return (match, true, "groupId")
		}

		if !normalizedEnvGroupId.isEmpty,
			let match = items.first(where: {
				guard let value = $0.id?.value else { return false }
				return String(value) == environmentGroupId
			})
		{
			return (match, true, "numericId")
		}

		if !normalizedEnvGroupUuid.isEmpty,
			let match = items.first(where: {
				($0.uuid?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "")
					== normalizedEnvGroupUuid
			})
		{
			return (match, true, "uuid")
		}

		if let match = items.first(where: { $0.lgLevel == 0 }) {
			return (match, true, "lgLevelZero")
		}

		return (items[0], false, "firstItemFallback")
	}

		func downloadOrgGroupLogo(
		environment: UemEnvironment,
		brandingConfig: BrandingConfig
	) async {
		do {
			guard
				let logoPath = brandingConfig.logoUrl?
					.trimmingCharacters(in: .whitespacesAndNewlines),
				!logoPath.isEmpty
			else {
				logger.error("[\(self.logPrefix)][DownloadOrgGroupLogo] Missing logoUrl")
				return
			}
			guard let baseURL = URL(string: environment.uemUrl) else {
				logger.error("[\(self.logPrefix)][DownloadOrgGroupLogo] Invalid UEM URL")
				return
			}
			let cleanedLogoPath = logoPath.hasPrefix("/") ? String(logoPath.dropFirst()) : logoPath
			guard
				let url = URL(
					string: "/AirWatch/\(cleanedLogoPath)",
					relativeTo: baseURL
				)
			else {
				logger.error("[\(self.logPrefix)][DownloadOrgGroupLogo] Invalid logo URL")
				return
			}

			let (tempURL, response) = try await URLSession.shared.download(
				from: url
			)
			guard let httpResponse = response as? HTTPURLResponse else {
				logger.error("[\(self.logPrefix)][DownloadOrgGroupLogo] Non-HTTP response")
				return
			}
			guard (200...299).contains(httpResponse.statusCode) else {
				logger.error(
					"[\(self.logPrefix)][DownloadOrgGroupLogo] HTTP \(httpResponse.statusCode, privacy: .public)"
				)
				return
			}

			guard
				let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
				!contentType.isEmpty
			else {
				throw NSError(
					domain: "UEMService",
					code: -1,
					userInfo: [NSLocalizedDescriptionKey: "Content-Type header is missing - cannot determine file type."]
				)
			}

			_ = try contentTypeToExtension(contentType)

			let fullPath = try ensureBrandingDataDirectory()
				.appendingPathComponent("\(environment.orgGroupUuid).dat")
				if FileManager.default.fileExists(atPath: fullPath.path) {
					try FileManager.default.removeItem(at: fullPath)
				}
				try FileManager.default.moveItem(at: tempURL, to: fullPath)
				if !environment.orgGroupUuid.trimmingCharacters(
					in: .whitespacesAndNewlines
				).isEmpty {
					await MainActor.run {
						NotificationCenter.default.post(
							name: .orgGroupLogoDidUpdate,
							object: environment.orgGroupUuid
						)
					}
				}
			} catch {
				logger.error(
					"[\(self.logPrefix)][DownloadOrgGroupLogo] \(String(describing: error), privacy: .public)"
				)
			}
		}

	func refreshOrgGroupLogo(environment: UemEnvironment) async {
		let orgGroupUuid = environment.orgGroupUuid.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		guard !orgGroupUuid.isEmpty else { return }
		guard
			let brandingConfig = await getOrgGroupBrandingConfig(
				environment: environment,
				preferCached: true
			)
		else {
			return
		}
		guard let logoUrl = brandingConfig.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
			!logoUrl.isEmpty
		else {
			do {
				try removeOrgGroupLogoFile(orgGroupUUID: orgGroupUuid)
				await MainActor.run {
					NotificationCenter.default.post(
						name: .orgGroupLogoDidUpdate,
						object: orgGroupUuid
					)
				}
			} catch {
				logger.error(
					"[\(self.logPrefix)][RefreshOrgGroupLogo] \(String(describing: error), privacy: .public)"
				)
			}
			return
		}
		await downloadOrgGroupLogo(
			environment: environment,
			brandingConfig: brandingConfig
		)
	}

	#if os(macOS)
	func loadOrgGroupLogoSourceFromFile(orgGroupUUID: String) async -> NSImage? {
		do {
			let path = try ensureBrandingDataDirectory()
				.appendingPathComponent("\(orgGroupUUID).dat")
			guard FileManager.default.fileExists(atPath: path.path) else {
				return nil
			}
			return NSImage(contentsOf: path)
		} catch {
			logger.error(
				"[\(self.logPrefix)][LoadOrgGroupLogoSourceFromFile] \(String(describing: error), privacy: .public)"
			)
			return nil
		}
	}
	#endif

	private func contentTypeToExtension(_ contentType: String) throws -> String {
		let normalized = contentType
			.lowercased()
			.components(separatedBy: ";")
			.first?
			.trimmingCharacters(in: .whitespacesAndNewlines) ?? contentType

		switch normalized {
		case "image/png":
			return ".png"
		case "image/jpeg", "image/jpg":
			return ".jpg"
		case "image/gif":
			return ".gif"
		case "image/webp":
			return ".webp"
		case "image/svg+xml":
			return ".svg"
		case "image/bmp":
			return ".bmp"
		case "image/x-icon":
			return ".ico"
		default:
			throw NSError(
				domain: "UEMService",
				code: -2,
				userInfo: [NSLocalizedDescriptionKey: "Unsupported Content-Type: \(contentType)"]
			)
		}
	}

	private func ensureBrandingDataDirectory() throws -> URL {
		let appData = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		)[0]
		let fetchPath = appData
			.appendingPathComponent("Fetch")
			.appendingPathComponent("ApplicationData")
		try FileManager.default.createDirectory(
			at: fetchPath,
			withIntermediateDirectories: true
		)
		return fetchPath
	}

	private func ensureBrandingConfigDirectory() throws -> URL {
		let appData = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		)[0]
		let configPath = appData
			.appendingPathComponent("Fetch")
			.appendingPathComponent("BrandingConfigs")
		try FileManager.default.createDirectory(
			at: configPath,
			withIntermediateDirectories: true
		)
		return configPath
	}

	func loadCachedOrgGroupBrandingConfig(orgGroupUUID: String) -> BrandingConfig? {
		let key = orgGroupUUID.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return nil }

		do {
			let path = try ensureBrandingConfigDirectory()
				.appendingPathComponent("\(key).json")
			guard FileManager.default.fileExists(atPath: path.path) else {
				return nil
			}
			let data = try Data(contentsOf: path)
			return try JSONDecoder().decode(BrandingConfig.self, from: data)
		} catch {
			logger.error(
				"[\(self.logPrefix)][LoadCachedOrgGroupBrandingConfig] \(String(describing: error), privacy: .public)"
			)
			return nil
		}
	}

	private func saveOrgGroupBrandingConfig(
		_ config: BrandingConfig,
		orgGroupUUID: String
	) {
		let key = orgGroupUUID.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return }

		do {
			let path = try ensureBrandingConfigDirectory()
				.appendingPathComponent("\(key).json")
			let data = try JSONEncoder().encode(config)
			try data.write(to: path, options: .atomic)
		} catch {
			logger.error(
				"[\(self.logPrefix)][SaveOrgGroupBrandingConfig] \(String(describing: error), privacy: .public)"
			)
		}
	}

	private func removeOrgGroupLogoFile(orgGroupUUID: String) throws {
		let fullPath = try ensureBrandingDataDirectory()
			.appendingPathComponent("\(orgGroupUUID).dat")
		guard FileManager.default.fileExists(atPath: fullPath.path) else { return }
		try FileManager.default.removeItem(at: fullPath)
	}

	func clearOrgGroupLogoCache() {
		do {
			let cacheDirectory = try ensureBrandingDataDirectory()
			guard FileManager.default.fileExists(atPath: cacheDirectory.path) else {
				return
			}
			let contents = try FileManager.default.contentsOfDirectory(
				at: cacheDirectory,
				includingPropertiesForKeys: nil
			)
			for item in contents {
				guard item.pathExtension.lowercased() == "dat" else { continue }
				try FileManager.default.removeItem(at: item)
			}
			logger.info(
				"[\(self.logPrefix)][ClearOrgGroupLogoCache] Cleared logo cache directory"
			)
		} catch {
			logger.error(
				"[\(self.logPrefix)][ClearOrgGroupLogoCache] \(String(describing: error), privacy: .public)"
			)
		}
	}

	func getAllAppsResult(includeVersionChecks: Bool = true) async -> Result<
		[UemApplication], GetAllAppsError
	> {
		appLog(
			.info,
			LogCategory.uem,
			"Starting UEM app query",
			event: "uem.query.start",
			metadata: ["include_version_checks": String(includeVersionChecks)]
		)
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard let baseURL = URL(string: activeEnvironment.uemUrl)
		else { return .failure(.invalidBaseURL) }
		guard
			let url = URL(
				string: "/API/mam/apps/search?platform=AppleOsX",
				relativeTo: baseURL
			)
		else {
			return .failure(.invalidEndpointURL)
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		guard let authHeaders = await AuthService.instance.authorizationHeaders(
			for: activeEnvironment
		) else {
			appLog(.error, LogCategory.uem, "Authentication failed before app query", event: "uem.query.auth_failed")
			return .failure(.authenticationFailed)
		}
		for (header, value) in authHeaders {
			request.setValue(value, forHTTPHeaderField: header)
		}

		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let httpResponse = response as? HTTPURLResponse else {
				appLog(.error, LogCategory.uem, "Invalid HTTP response for app query", event: "uem.query.invalid_response")
				return .failure(.invalidResponse)
			}
			guard (200...299).contains(httpResponse.statusCode) else {
				appLog(
					.error,
					LogCategory.uem,
					"UEM app query returned non-success status",
					event: "uem.query.http_error",
					metadata: ["status": String(httpResponse.statusCode)]
				)
				return .failure(.httpStatus(httpResponse.statusCode))
			}

			// Parse top-level JSON as a dictionary
			guard
				let json = try JSONSerialization.jsonObject(
					with: data,
					options: []
				) as? [String: Any]
			else {
				return .failure(.malformedPayload)
			}

			guard let applications = json["Application"] else {
				return .failure(.malformedPayload)
			}

			let applicationsData: Data
			do {
				applicationsData = try JSONSerialization.data(
					withJSONObject: applications,
					options: []
				)
			} catch {
				return .failure(.malformedPayload)
			}
			let decoded: [UemApplication]
			do {
				decoded = try JSONDecoder().decode(
					[UemApplication].self,
					from: applicationsData
				)
			} catch {
				return .failure(.decoding(error))
			}
			if !includeVersionChecks { return .success(decoded) }
			let catalogApps = await loadedCatalogApps()

			let updatedApps: [UemApplication] = await withTaskGroup(
				of: (Int, UemApplication).self
			) { group in
				for (index, app) in decoded.enumerated() {
					group.addTask {
						let updated = await self.checkForNewerVersion(
							app,
							catalogApps: catalogApps
						)
						return (index, updated)
					}
				}
				var results = Array<UemApplication?>(repeating: nil, count: decoded.count)
				for await (index, updated) in group {
					results[index] = updated
				}

				return results.compactMap { $0 }
			}
			let reconciledApps = await reconcileMultipleUemVersions(updatedApps)
			appLog(
				.info,
				LogCategory.uem,
				"Completed UEM app query",
				event: "uem.query.success",
				metadata: [
					"app_count": String(reconciledApps.count),
					"include_version_checks": String(includeVersionChecks)
				]
			)
			return .success(reconciledApps)
		} catch {
			appLog(
				.error,
				LogCategory.uem,
				"UEM app query failed",
				event: "uem.query.failure",
				metadata: ["reason": error.localizedDescription]
			)
			logger.error(
				"[\(self.logPrefix)][GetAllApps] \(String(describing: error), privacy: .public)"
			)
			return .failure(.transport(error))
		}
	}

	func getAllApps(includeVersionChecks: Bool = true) async -> [UemApplication?] {
		switch await getAllAppsResult(includeVersionChecks: includeVersionChecks) {
		case .success(let apps):
			return apps.map { Optional($0) }
		case .failure:
			return []
		}
	}

	private func loadedCatalogApps() async -> [CaskApplication] {
		let currentCatalog: LocalCatalog = await MainActor.run {
			if let catalog {
				return catalog
			}
			let newCatalog = LocalCatalog()
			self.catalog = newCatalog
			return newCatalog
		}

		let isCatalogReady = await MainActor.run {
			currentCatalog.isLoaded && !currentCatalog.caskApps.isEmpty
		}
		if !isCatalogReady {
			await currentCatalog.loadLocalCatalog()
		}

		return await MainActor.run {
			currentCatalog.caskApps
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
	
	func checkForNewerVersion(
		_ uemApplication: UemApplication,
		catalogApps: [CaskApplication]? = nil
	) async -> UemApplication {
		let funcLogPrefix = "CheckForNewerVersion"
		var uemApp = uemApplication
		uemApp.hasLaterVersionInConsole = false

		do {
			let allApplications: [CaskApplication]
			if let catalogApps {
				allApplications = catalogApps
			} else {
				allApplications = await loadedCatalogApps()
			}
			if allApplications.isEmpty {
				appLog(
					.warning,
					LogCategory.uem,
					"Catalog is empty; skipping version comparison",
					event: "uem.version_check.catalog_empty",
					metadata: ["app_name": uemApp.applicationName]
				)
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
					appLog(
						.info,
						LogCategory.uem,
						"Catalog update available",
						event: "uem.version_check.update_available",
						metadata: ["app_name": uemApp.applicationName]
					)
				} else {
					uemApp.isLatest = true
				}

				logger.debug(
					"[\(funcLogPrefix)] No updates available for \(uemApp.applicationName, privacy: .public)"
				)
			} else {
				uemApp.wasMatched = false
				appLog(
					.debug,
					LogCategory.uem,
					"No suitable catalog match found",
					event: "uem.version_check.no_match",
					metadata: ["app_name": uemApp.applicationName]
				)
				logger.debug(
					"[\(funcLogPrefix)] No suitable match found for \(uemApp.applicationName, privacy: .public)"
				)
			}

			return uemApp
		} catch {
			appLog(
				.error,
				LogCategory.uem,
				"Version comparison failed",
				event: "uem.version_check.failure",
				metadata: [
					"app_name": uemApp.applicationName,
					"reason": error.localizedDescription
				]
			)
			logger.error(
				"[\(funcLogPrefix)] \(String(describing: error), privacy: .public)"
			)
			return uemApp
		}
	}

	private func reconcileMultipleUemVersions(
		_ apps: [UemApplication]
	) async -> [UemApplication] {
		guard apps.count > 1 else { return apps }
		var reconciled = apps
		var groupedIndexes: [String: [Int]] = [:]
		groupedIndexes.reserveCapacity(apps.count)

		for (index, app) in apps.enumerated() {
			let key = await updateGroupingKey(for: app)
			groupedIndexes[key, default: []].append(index)
		}

		for indexes in groupedIndexes.values where indexes.count > 1 {
			let matchedIndexes = indexes.filter { reconciled[$0].wasMatched == true }
			guard !matchedIndexes.isEmpty else { continue }

			let parsedCatalogVersions = matchedIndexes.compactMap { index in
				parsedCatalogVersion(from: reconciled[index])
			}
			guard let highestCatalogVersion = parsedCatalogVersions.max() else {
				continue
			}

			let parsedUemVersions: [(index: Int, version: ParsedVersion)] = indexes
				.compactMap { index in
					parsedUemVersion(from: reconciled[index]).map { (index, $0) }
				}
			guard let highestUemVersion = parsedUemVersions.map(\.version).max() else {
				continue
			}

			let highestVersionIndexes = Set(
				parsedUemVersions
					.filter { $0.version == highestUemVersion }
					.map(\.index)
			)
			let shouldShowUpdate = highestCatalogVersion > highestUemVersion

			for index in indexes {
				guard parsedUemVersion(from: reconciled[index]) != nil else { continue }
				let isHighestRow = highestVersionIndexes.contains(index)
				if isHighestRow {
					reconciled[index].hasLaterVersionInConsole = false
					reconciled[index].hasUpdate = shouldShowUpdate
					if !shouldShowUpdate {
						reconciled[index].isLatest = true
					}
				} else {
					reconciled[index].hasLaterVersionInConsole = true
					reconciled[index].hasUpdate = false
				}
			}
		}

		return reconciled
	}

	private func updateGroupingKey(for app: UemApplication) async -> String {
		let normalizedBundleId = normalizeForCompare(app.bundleId)
		let canonicalizedName = await AppNameComparer.canonicalize(
			app.applicationName
		)
		let normalizedName = await AppNameComparer.normalize(canonicalizedName)
		let fallbackName = normalizeForCompare(app.applicationName)
		let namePart = normalizedName.isEmpty ? fallbackName : normalizedName
		let bundlePart =
			normalizedBundleId.isEmpty ? "no-bundle" : normalizedBundleId
		return "\(bundlePart)|\(namePart)"
	}

	private func parsedCatalogVersion(from app: UemApplication) -> ParsedVersion? {
		tryGetVersion(app.updatedApplication?.version)
	}

	private func parsedUemVersion(from app: UemApplication) -> ParsedVersion? {
		tryGetVersion(app.appVersion) ?? tryGetVersion(app.actualFileVersion)
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

extension Notification.Name {
	static let orgGroupLogoDidUpdate = Notification.Name(
		"orgGroupLogoDidUpdate"
	)
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
