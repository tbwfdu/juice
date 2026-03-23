import Foundation
#if canImport(WidgetKit)
	import WidgetKit
#endif

struct SettingsStore {
	private static let widgetDefaultAccentTintHex = "#FC642D"
	static let defaultAppsEndpoint = "https://juice.omnissafoundry.com/db/apps.json"
	static let defaultRecipesEndpoint = "https://juice.omnissafoundry.com/db/recipes.json"
	static let defaultVersionEndpoint = "https://juice.omnissafoundry.com/version"

	struct SettingsState: Codable {
		var activeEnvironmentUuid: String?
		var uemEnvironments: [UemEnvironment]
		var eulaAccepted: Bool
		var databaseAppsEndpoint: String?
		var databaseRecipesEndpoint: String?
		var databaseServerUrl: String?
		var databaseVersionEndpoint: String?
		var databaseDownloadEndpoint: String?
		var storagePath: String?
		var prominentButtonTintHex: String?
		var useActiveEnvironmentBrandingTint: Bool
		var activeEnvironmentDeviceCount: Int?
		var activeEnvironmentAppCount: Int?
		var availableUpdatesCount: Int?
		var sparkleAutoCheckEnabled: Bool
		var sparkleCheckIntervalHours: Int
		var sparkleAutoDownloadEnabled: Bool

		init(
			activeEnvironmentUuid: String? = nil,
			uemEnvironments: [UemEnvironment] = [],
			eulaAccepted: Bool = false,
			databaseAppsEndpoint: String? = nil,
			databaseRecipesEndpoint: String? = nil,
			databaseServerUrl: String? = nil,
			databaseVersionEndpoint: String? = nil,
			databaseDownloadEndpoint: String? = nil,
			storagePath: String? = nil,
			prominentButtonTintHex: String? = nil,
			useActiveEnvironmentBrandingTint: Bool = false,
			activeEnvironmentDeviceCount: Int? = nil,
			activeEnvironmentAppCount: Int? = nil,
			availableUpdatesCount: Int? = nil,
			sparkleAutoCheckEnabled: Bool = true,
			sparkleCheckIntervalHours: Int = 24,
			sparkleAutoDownloadEnabled: Bool = false
		) {
			self.activeEnvironmentUuid = activeEnvironmentUuid
			self.uemEnvironments = uemEnvironments
			self.eulaAccepted = eulaAccepted
			self.databaseAppsEndpoint = databaseAppsEndpoint
			self.databaseRecipesEndpoint = databaseRecipesEndpoint
			self.databaseServerUrl = databaseServerUrl
			self.databaseVersionEndpoint = databaseVersionEndpoint
			self.databaseDownloadEndpoint = databaseDownloadEndpoint
			self.storagePath = storagePath
			self.prominentButtonTintHex = prominentButtonTintHex
			self.useActiveEnvironmentBrandingTint = useActiveEnvironmentBrandingTint
			self.activeEnvironmentDeviceCount = activeEnvironmentDeviceCount
			self.activeEnvironmentAppCount = activeEnvironmentAppCount
			self.availableUpdatesCount = availableUpdatesCount
			self.sparkleAutoCheckEnabled = sparkleAutoCheckEnabled
			self.sparkleCheckIntervalHours = sparkleCheckIntervalHours
			self.sparkleAutoDownloadEnabled = sparkleAutoDownloadEnabled
		}
	}

	private enum Keys {
		static let prefix = "juice.settings."
		static let environments = prefix + "uemEnvironments"
		static let activeEnvironmentUuid = prefix + "activeEnvironmentUuid"
		static let eulaAccepted = prefix + "eulaAccepted"
		static let databaseAppsEndpoint = prefix + "databaseAppsEndpoint"
		static let databaseRecipesEndpoint = prefix + "databaseRecipesEndpoint"
		static let databaseServerUrl = prefix + "databaseServerUrl"
		static let databaseVersionEndpoint = prefix + "databaseVersionEndpoint"
		static let databaseDownloadEndpoint = prefix + "databaseDownloadEndpoint"
		static let storagePath = prefix + "storagePath"
		static let prominentButtonTintHex = prefix + "prominentButtonTintHex"
		static let useActiveEnvironmentBrandingTint = prefix + "useActiveEnvironmentBrandingTint"
		static let activeEnvironmentDeviceCount = prefix + "activeEnvironmentDeviceCount"
		static let activeEnvironmentAppCount = prefix + "activeEnvironmentAppCount"
		static let availableUpdatesCount = prefix + "availableUpdatesCount"
		static let sparkleAutoCheckEnabled = prefix + "sparkleAutoCheckEnabled"
		static let sparkleCheckIntervalHours = prefix + "sparkleCheckIntervalHours"
		static let sparkleAutoDownloadEnabled = prefix + "sparkleAutoDownloadEnabled"
		static let didImportLegacy = prefix + "didImportLegacy"
	}

	private let defaults: UserDefaults
	private let keychain: KeychainStore

	init(
		defaults: UserDefaults = .standard,
		keychain: KeychainStore = .shared
	) {
		self.defaults = defaults
		self.keychain = keychain
	}

	func load() -> SettingsState {
		do {
			return try loadThrowing()
		} catch {
			appLog(
				.error,
				"SettingsStore",
				"Keychain-backed settings load failed: \(error.localizedDescription)"
			)
			return normalizedState(
				SettingsState(
					activeEnvironmentUuid: defaults.string(forKey: Keys.activeEnvironmentUuid),
					uemEnvironments: loadFallbackEnvironmentsWithoutSecrets(),
					eulaAccepted: resolvedEulaAccepted(
						storedValue: defaults.object(forKey: Keys.eulaAccepted) as? Bool,
						hasPersistedEnvironments: !loadEnvironmentsFromDefaults().isEmpty
					),
					databaseAppsEndpoint: defaults.string(forKey: Keys.databaseAppsEndpoint),
					databaseRecipesEndpoint: defaults.string(forKey: Keys.databaseRecipesEndpoint),
					databaseServerUrl: defaults.string(forKey: Keys.databaseServerUrl),
					databaseVersionEndpoint: defaults.string(forKey: Keys.databaseVersionEndpoint),
					databaseDownloadEndpoint: defaults.string(forKey: Keys.databaseDownloadEndpoint),
					storagePath: defaults.string(forKey: Keys.storagePath),
					prominentButtonTintHex: defaults.string(forKey: Keys.prominentButtonTintHex),
					useActiveEnvironmentBrandingTint: defaults.bool(forKey: Keys.useActiveEnvironmentBrandingTint),
					activeEnvironmentDeviceCount: defaults.object(forKey: Keys.activeEnvironmentDeviceCount) as? Int,
					activeEnvironmentAppCount: defaults.object(forKey: Keys.activeEnvironmentAppCount) as? Int,
					availableUpdatesCount: defaults.object(forKey: Keys.availableUpdatesCount) as? Int,
					sparkleAutoCheckEnabled: defaults.object(forKey: Keys.sparkleAutoCheckEnabled) as? Bool ?? true,
					sparkleCheckIntervalHours: defaults.object(forKey: Keys.sparkleCheckIntervalHours) as? Int ?? 24,
					sparkleAutoDownloadEnabled: defaults.object(forKey: Keys.sparkleAutoDownloadEnabled) as? Bool ?? false
				)
			)
		}
	}

	func loadThrowing() throws -> SettingsState {
		let environments = try loadEnvironmentsHydratingSecrets()
		let state = normalizedState(
			SettingsState(
			activeEnvironmentUuid: defaults.string(forKey: Keys.activeEnvironmentUuid),
			uemEnvironments: environments,
			eulaAccepted: resolvedEulaAccepted(
				storedValue: defaults.object(forKey: Keys.eulaAccepted) as? Bool,
				hasPersistedEnvironments: !environments.isEmpty
			),
			databaseAppsEndpoint: defaults.string(forKey: Keys.databaseAppsEndpoint),
			databaseRecipesEndpoint: defaults.string(forKey: Keys.databaseRecipesEndpoint),
			databaseServerUrl: defaults.string(forKey: Keys.databaseServerUrl),
			databaseVersionEndpoint: defaults.string(forKey: Keys.databaseVersionEndpoint),
			databaseDownloadEndpoint: defaults.string(forKey: Keys.databaseDownloadEndpoint),
			storagePath: defaults.string(forKey: Keys.storagePath),
			prominentButtonTintHex: defaults.string(forKey: Keys.prominentButtonTintHex),
			useActiveEnvironmentBrandingTint: defaults.bool(forKey: Keys.useActiveEnvironmentBrandingTint),
			activeEnvironmentDeviceCount: defaults.object(forKey: Keys.activeEnvironmentDeviceCount) as? Int,
			activeEnvironmentAppCount: defaults.object(forKey: Keys.activeEnvironmentAppCount) as? Int,
			availableUpdatesCount: defaults.object(forKey: Keys.availableUpdatesCount) as? Int,
			sparkleAutoCheckEnabled: defaults.object(forKey: Keys.sparkleAutoCheckEnabled) as? Bool ?? true,
			sparkleCheckIntervalHours: defaults.object(forKey: Keys.sparkleCheckIntervalHours) as? Int ?? 24,
			sparkleAutoDownloadEnabled: defaults.object(forKey: Keys.sparkleAutoDownloadEnabled) as? Bool ?? false
			)
		)
		return state
	}

	func save(_ state: SettingsState) throws {
		let previousEnvironments = loadEnvironmentsFromDefaults()
		let (sanitizedEnvironments, retainedSecretRefs) = try persistSecretsAndSanitize(
			state.uemEnvironments
		)
		try deleteRemovedSecrets(
			previousEnvironments: previousEnvironments,
			retainedSecretRefs: retainedSecretRefs
		)
		let data = try JSONEncoder().encode(sanitizedEnvironments)
		defaults.set(data, forKey: Keys.environments)
		defaults.set(state.activeEnvironmentUuid, forKey: Keys.activeEnvironmentUuid)
		defaults.set(state.eulaAccepted, forKey: Keys.eulaAccepted)
		defaults.set(state.databaseAppsEndpoint, forKey: Keys.databaseAppsEndpoint)
		defaults.set(state.databaseRecipesEndpoint, forKey: Keys.databaseRecipesEndpoint)
		defaults.set(state.databaseServerUrl, forKey: Keys.databaseServerUrl)
		defaults.set(state.databaseVersionEndpoint, forKey: Keys.databaseVersionEndpoint)
		defaults.set(state.databaseDownloadEndpoint, forKey: Keys.databaseDownloadEndpoint)
		defaults.set(state.storagePath, forKey: Keys.storagePath)
		defaults.set(state.prominentButtonTintHex, forKey: Keys.prominentButtonTintHex)
		defaults.set(
			state.useActiveEnvironmentBrandingTint,
			forKey: Keys.useActiveEnvironmentBrandingTint
		)
		defaults.set(state.activeEnvironmentDeviceCount, forKey: Keys.activeEnvironmentDeviceCount)
		defaults.set(state.activeEnvironmentAppCount, forKey: Keys.activeEnvironmentAppCount)
		defaults.set(state.availableUpdatesCount, forKey: Keys.availableUpdatesCount)
		defaults.set(state.sparkleAutoCheckEnabled, forKey: Keys.sparkleAutoCheckEnabled)
		defaults.set(state.sparkleCheckIntervalHours, forKey: Keys.sparkleCheckIntervalHours)
		defaults.set(state.sparkleAutoDownloadEnabled, forKey: Keys.sparkleAutoDownloadEnabled)
		var hydratedState = state
		hydratedState.uemEnvironments = try hydrateSecrets(in: sanitizedEnvironments)
		publishWidgetSharedState(from: hydratedState)
	}

		func reset() {
			let previousEnvironments = loadEnvironmentsFromDefaults()
			for environment in previousEnvironments {
				guard let secretRef = normalizedSecretRef(environment.secretRef) else {
					continue
				}
				do {
					try keychain.deleteEnvironmentClientSecret(secretRef: secretRef)
					try keychain.deleteEnvironmentBasicPassword(secretRef: secretRef)
					try keychain.deleteEnvironmentApiKey(secretRef: secretRef)
				} catch {
					appLog(
						.error,
						"SettingsStore",
					"Failed to delete keychain secret during reset for ref \(secretRef): \(error.localizedDescription)"
				)
			}
		}
		defaults.removeObject(forKey: Keys.environments)
		defaults.removeObject(forKey: Keys.activeEnvironmentUuid)
		defaults.removeObject(forKey: Keys.eulaAccepted)
		defaults.removeObject(forKey: Keys.databaseAppsEndpoint)
		defaults.removeObject(forKey: Keys.databaseRecipesEndpoint)
		defaults.removeObject(forKey: Keys.databaseServerUrl)
		defaults.removeObject(forKey: Keys.databaseVersionEndpoint)
		defaults.removeObject(forKey: Keys.databaseDownloadEndpoint)
		defaults.removeObject(forKey: Keys.storagePath)
		defaults.removeObject(forKey: Keys.prominentButtonTintHex)
		defaults.removeObject(forKey: Keys.useActiveEnvironmentBrandingTint)
		defaults.removeObject(forKey: Keys.activeEnvironmentDeviceCount)
		defaults.removeObject(forKey: Keys.activeEnvironmentAppCount)
		defaults.removeObject(forKey: Keys.availableUpdatesCount)
		defaults.removeObject(forKey: Keys.sparkleAutoCheckEnabled)
		defaults.removeObject(forKey: Keys.sparkleCheckIntervalHours)
		defaults.removeObject(forKey: Keys.sparkleAutoDownloadEnabled)
		defaults.removeObject(forKey: Keys.didImportLegacy)
		publishWidgetSharedState(from: SettingsState())
	}

	func syncWidgetFromStoredState() {
		publishWidgetSharedState(from: load())
	}

	func migrateEnvironmentSecretsIfNeeded() throws {
		_ = try loadEnvironmentsHydratingSecrets()
	}

	func importLegacyIfNeeded(from url: URL) -> SettingsState? {
		guard defaults.data(forKey: Keys.environments) == nil else { return nil }
		guard defaults.bool(forKey: Keys.didImportLegacy) == false else { return nil }
		return importLegacy(from: url)
	}

	func importLegacy(from url: URL) -> SettingsState? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		guard let data = try? Data(contentsOf: url) else { return nil }
		guard let decoded = try? JSONDecoder().decode(FileContents.self, from: data) else { return nil }

		let state = normalizedState(
			SettingsState(
			activeEnvironmentUuid: decoded.activeEnvironmentUuid,
			uemEnvironments: decoded.uemEnvironments ?? [],
			eulaAccepted: boolFromLegacyString(decoded.eulaAccepted)
				?? !(decoded.uemEnvironments ?? []).isEmpty,
			databaseAppsEndpoint: decoded.databaseAppsEndpoint,
			databaseRecipesEndpoint: decoded.databaseRecipesEndpoint,
			databaseServerUrl: decoded.databaseServerUrl,
			databaseVersionEndpoint: decoded.databaseVersionEndpoint,
			databaseDownloadEndpoint: decoded.databaseDownloadEndpoint,
			storagePath: decoded.storagePath,
			prominentButtonTintHex: decoded.prominentButtonTintHex,
				useActiveEnvironmentBrandingTint: decoded.useActiveEnvironmentBrandingTint ?? false,
				activeEnvironmentDeviceCount: nil,
				activeEnvironmentAppCount: nil,
				availableUpdatesCount: nil,
				sparkleAutoCheckEnabled: true,
				sparkleCheckIntervalHours: 24,
				sparkleAutoDownloadEnabled: false
				)
			)

		do {
			try save(state)
		} catch {
			appLog(
				.error,
				"SettingsStore",
				"Legacy import save failed: \(error.localizedDescription)"
			)
			return nil
		}
		defaults.set(true, forKey: Keys.didImportLegacy)
		return state
	}

	private func normalizedState(_ state: SettingsState) -> SettingsState {
		var normalized = state
		let legacyServer = state.databaseServerUrl?.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let legacyDownload = state.databaseDownloadEndpoint?.trimmingCharacters(
			in: .whitespacesAndNewlines
		)

		if normalized.databaseAppsEndpoint?.isEmpty ?? true {
			if let legacyDownload,
				!legacyDownload.isEmpty,
				legacyDownload.hasSuffix("/apps.json")
			{
				normalized.databaseAppsEndpoint = legacyDownload
			} else if let legacyServer, !legacyServer.isEmpty {
				normalized.databaseAppsEndpoint = legacyServer + "/db/apps.json"
			} else {
				normalized.databaseAppsEndpoint = Self.defaultAppsEndpoint
			}
		}

		if normalized.databaseRecipesEndpoint?.isEmpty ?? true {
			if let legacyServer, !legacyServer.isEmpty {
				normalized.databaseRecipesEndpoint = legacyServer + "/db/recipes.json"
			} else {
				normalized.databaseRecipesEndpoint = Self.defaultRecipesEndpoint
			}
		}

		if normalized.databaseVersionEndpoint?.isEmpty ?? true {
			if let legacyServer, !legacyServer.isEmpty {
				normalized.databaseVersionEndpoint = legacyServer + "/version"
			} else {
				normalized.databaseVersionEndpoint = Self.defaultVersionEndpoint
			}
		}

		normalized.sparkleCheckIntervalHours = AppUpdaterService.normalizedIntervalHours(
			normalized.sparkleCheckIntervalHours
		)

		return normalized
	}

	private func resolvedEulaAccepted(
		storedValue: Bool?,
		hasPersistedEnvironments: Bool
	) -> Bool {
		if let storedValue {
			return storedValue
		}
		// Backward-compatible default: existing configured installs are treated as accepted.
		return hasPersistedEnvironments
	}

	private func boolFromLegacyString(_ value: String?) -> Bool? {
		guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
			!raw.isEmpty
		else {
			return nil
		}
		if raw == "true" || raw == "1" || raw == "yes" {
			return true
		}
		if raw == "false" || raw == "0" || raw == "no" {
			return false
		}
		return nil
	}

	private func loadEnvironmentsFromDefaults() -> [UemEnvironment] {
		guard let data = defaults.data(forKey: Keys.environments) else { return [] }
		guard let decoded = try? JSONDecoder().decode([UemEnvironment].self, from: data) else {
			return []
		}
		return decoded
	}

	private func loadEnvironmentsHydratingSecrets() throws -> [UemEnvironment] {
		let rawEnvironments = loadEnvironmentsFromDefaults()
		guard !rawEnvironments.isEmpty else { return [] }

		var hydratedEnvironments: [UemEnvironment] = []
		var scrubbedEnvironments: [UemEnvironment] = []
		var shouldPersistScrubbed = false

		for environment in rawEnvironments {
			let (resolvedEnvironment, didGenerateSecretRef) = resolvedSecretRef(
				for: environment
			)
			var hydratedEnvironment = resolvedEnvironment
			let secretRef = resolvedEnvironment.secretRef

			if didGenerateSecretRef {
				shouldPersistScrubbed = true
			}

			if let legacySecret = normalizedValue(resolvedEnvironment.clientSecret) {
				try keychain.setEnvironmentClientSecret(
					legacySecret,
					secretRef: secretRef
				)
				shouldPersistScrubbed = true
			}

			if let legacyBasicPassword = normalizedValue(
				resolvedEnvironment.basicPassword
			) {
				try keychain.setEnvironmentBasicPassword(
					legacyBasicPassword,
					secretRef: secretRef
				)
				shouldPersistScrubbed = true
			}

			if let legacyApiKey = normalizedValue(resolvedEnvironment.apiKey) {
				try keychain.setEnvironmentApiKey(
					legacyApiKey,
					secretRef: secretRef
				)
				shouldPersistScrubbed = true
			}

			let keychainSecret =
				try keychain.getEnvironmentClientSecret(secretRef: secretRef) ?? ""
			let keychainBasicPassword =
				try keychain.getEnvironmentBasicPassword(secretRef: secretRef)
				?? ""
			let keychainApiKey =
				try keychain.getEnvironmentApiKey(secretRef: secretRef) ?? ""
			hydratedEnvironment.clientSecret = keychainSecret
			hydratedEnvironment.basicPassword = keychainBasicPassword
			hydratedEnvironment.apiKey = keychainApiKey
			hydratedEnvironments.append(hydratedEnvironment)

			var scrubbed = resolvedEnvironment
			if !scrubbed.clientSecret.isEmpty {
				scrubbed.clientSecret = ""
				shouldPersistScrubbed = true
			}
			if !scrubbed.basicPassword.isEmpty {
				scrubbed.basicPassword = ""
				shouldPersistScrubbed = true
			}
			if !scrubbed.apiKey.isEmpty {
				scrubbed.apiKey = ""
				shouldPersistScrubbed = true
			}
			scrubbedEnvironments.append(scrubbed)
		}

		if shouldPersistScrubbed {
			try persistEnvironmentsToDefaults(scrubbedEnvironments)
		}

		return hydratedEnvironments
	}

	private func loadFallbackEnvironmentsWithoutSecrets() -> [UemEnvironment] {
		loadEnvironmentsFromDefaults().map { environment in
			let (resolved, _) = resolvedSecretRef(for: environment)
			var fallback = resolved
			fallback.clientSecret = ""
			fallback.basicPassword = ""
			fallback.apiKey = ""
			return fallback
		}
	}

	private func persistSecretsAndSanitize(
		_ environments: [UemEnvironment]
	) throws -> ([UemEnvironment], Set<String>) {
		var sanitized: [UemEnvironment] = []
		var retainedSecretRefs: Set<String> = []

		for environment in environments {
			var resolved = environment
			if normalizedSecretRef(resolved.secretRef) == nil {
				resolved.secretRef = UUID().uuidString
			}
			let secretRef = resolved.secretRef
			retainedSecretRefs.insert(secretRef)

			if let secret = normalizedValue(resolved.clientSecret) {
				try keychain.setEnvironmentClientSecret(secret, secretRef: secretRef)
			} else {
				try keychain.deleteEnvironmentClientSecret(secretRef: secretRef)
			}

			if let basicPassword = normalizedValue(resolved.basicPassword) {
				try keychain.setEnvironmentBasicPassword(
					basicPassword,
					secretRef: secretRef
				)
			} else {
				try keychain.deleteEnvironmentBasicPassword(secretRef: secretRef)
			}

			if let apiKey = normalizedValue(resolved.apiKey) {
				try keychain.setEnvironmentApiKey(apiKey, secretRef: secretRef)
			} else {
				try keychain.deleteEnvironmentApiKey(secretRef: secretRef)
			}

			resolved.clientSecret = ""
			resolved.basicPassword = ""
			resolved.apiKey = ""
			sanitized.append(resolved)
		}

		return (sanitized, retainedSecretRefs)
	}

	private func deleteRemovedSecrets(
		previousEnvironments: [UemEnvironment],
		retainedSecretRefs: Set<String>
	) throws {
		let previousRefs = Set(
			previousEnvironments.compactMap { normalizedSecretRef($0.secretRef) }
		)
		let removedRefs = previousRefs.subtracting(retainedSecretRefs)
		for secretRef in removedRefs {
			try keychain.deleteEnvironmentClientSecret(secretRef: secretRef)
			try keychain.deleteEnvironmentBasicPassword(secretRef: secretRef)
			try keychain.deleteEnvironmentApiKey(secretRef: secretRef)
		}
	}

	private func hydrateSecrets(in environments: [UemEnvironment]) throws -> [UemEnvironment] {
		var hydrated: [UemEnvironment] = []
		for environment in environments {
			let (resolved, _) = resolvedSecretRef(for: environment)
			var hydratedEnvironment = resolved
			hydratedEnvironment.clientSecret =
				try keychain.getEnvironmentClientSecret(
					secretRef: resolved.secretRef
				) ?? ""
			hydratedEnvironment.basicPassword =
				try keychain.getEnvironmentBasicPassword(
					secretRef: resolved.secretRef
				) ?? ""
			hydratedEnvironment.apiKey =
				try keychain.getEnvironmentApiKey(
					secretRef: resolved.secretRef
				) ?? ""
			hydrated.append(hydratedEnvironment)
		}
		return hydrated
	}

	private func persistEnvironmentsToDefaults(
		_ environments: [UemEnvironment]
	) throws {
		let data = try JSONEncoder().encode(environments)
		defaults.set(data, forKey: Keys.environments)
	}

	private func resolvedSecretRef(
		for environment: UemEnvironment
	) -> (environment: UemEnvironment, generated: Bool) {
		var resolved = environment
		guard let normalized = normalizedSecretRef(environment.secretRef) else {
			resolved.secretRef = UUID().uuidString
			return (resolved, true)
		}
		resolved.secretRef = normalized
		return (resolved, false)
	}

	private func normalizedSecretRef(_ value: String?) -> String? {
		normalizedValue(value)
	}

	private func publishWidgetSharedState(from state: SettingsState) {
		let payload = makeWidgetSharedState(from: state)
		guard let payloadData = try? JSONEncoder().encode(payload) else { return }
		var didWrite = false
		for identifier in WidgetSharedState.candidateAppGroupIdentifiers {
			guard let containerURL = FileManager.default.containerURL(
				forSecurityApplicationGroupIdentifier: identifier
			) else {
				continue
			}
			let fileURL = containerURL.appendingPathComponent(
				WidgetSharedState.activeEnvironmentCardFilename,
				isDirectory: false
			)
			do {
				try payloadData.write(to: fileURL, options: .atomic)
				didWrite = true
			} catch {
				continue
			}
		}
		guard didWrite else { return }
#if canImport(WidgetKit)
		WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedState.widgetKind)
		WidgetCenter.shared.reloadAllTimelines()
#endif
	}

	private func makeWidgetSharedState(from state: SettingsState) -> WidgetSharedState {
		let activeEnvironment = resolveActiveEnvironment(from: state)
		return WidgetSharedState(
			activeEnvironmentFriendlyName: normalizedValue(activeEnvironment?.friendlyName),
			activeEnvironmentOrgGroupName: normalizedValue(activeEnvironment?.orgGroupName),
			activeEnvironmentHost: normalizedHost(from: activeEnvironment?.uemUrl),
			activeEnvironmentDeviceCount: state.activeEnvironmentDeviceCount,
			activeEnvironmentAppCount: state.activeEnvironmentAppCount,
			availableUpdatesCount: state.availableUpdatesCount,
			activeEnvironmentAccentTintHex: Self.widgetDefaultAccentTintHex,
			lastUpdated: Date()
		)
	}

	private func resolveActiveEnvironment(from state: SettingsState) -> UemEnvironment? {
		guard !state.uemEnvironments.isEmpty else { return nil }
		if let activeUuid = normalizedValue(state.activeEnvironmentUuid) {
			return state.uemEnvironments.first(where: { normalizedValue($0.orgGroupUuid) == activeUuid })
		}
		return state.uemEnvironments.first
	}

	private func normalizedHost(from urlString: String?) -> String? {
		guard let normalized = normalizedValue(urlString) else { return nil }
		if let host = URL(string: normalized)?.host, !host.isEmpty {
			return host
		}
		return normalized
	}

	private func normalizedValue(_ value: String?) -> String? {
		guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
			!trimmed.isEmpty
		else {
			return nil
		}
		return trimmed
	}

	private func normalizedColorHex(_ value: String?) -> String? {
		guard let trimmed = normalizedValue(value) else { return nil }
		return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
	}
}
