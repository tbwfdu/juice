import Foundation

struct SettingsStore {
	struct SettingsState: Codable {
		var activeEnvironmentUuid: String?
		var uemEnvironments: [UemEnvironment]
		var databaseServerUrl: String?
		var databaseVersionEndpoint: String?
		var databaseDownloadEndpoint: String?
		var storagePath: String?

		init(
			activeEnvironmentUuid: String? = nil,
			uemEnvironments: [UemEnvironment] = [],
			databaseServerUrl: String? = nil,
			databaseVersionEndpoint: String? = nil,
			databaseDownloadEndpoint: String? = nil,
			storagePath: String? = nil
		) {
			self.activeEnvironmentUuid = activeEnvironmentUuid
			self.uemEnvironments = uemEnvironments
			self.databaseServerUrl = databaseServerUrl
			self.databaseVersionEndpoint = databaseVersionEndpoint
			self.databaseDownloadEndpoint = databaseDownloadEndpoint
			self.storagePath = storagePath
		}
	}

	private enum Keys {
		static let prefix = "juice.settings."
		static let environments = prefix + "uemEnvironments"
		static let activeEnvironmentUuid = prefix + "activeEnvironmentUuid"
		static let databaseServerUrl = prefix + "databaseServerUrl"
		static let databaseVersionEndpoint = prefix + "databaseVersionEndpoint"
		static let databaseDownloadEndpoint = prefix + "databaseDownloadEndpoint"
		static let storagePath = prefix + "storagePath"
		static let didImportLegacy = prefix + "didImportLegacy"
	}

	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func load() -> SettingsState {
		let environments = loadEnvironments()
		let activeUuid = defaults.string(forKey: Keys.activeEnvironmentUuid)
		let state = SettingsState(
			activeEnvironmentUuid: activeUuid,
			uemEnvironments: environments,
			databaseServerUrl: defaults.string(forKey: Keys.databaseServerUrl),
			databaseVersionEndpoint: defaults.string(forKey: Keys.databaseVersionEndpoint),
			databaseDownloadEndpoint: defaults.string(forKey: Keys.databaseDownloadEndpoint),
			storagePath: defaults.string(forKey: Keys.storagePath)
		)
		return state
	}

	func save(_ state: SettingsState) throws {
		let data = try JSONEncoder().encode(state.uemEnvironments)
		defaults.set(data, forKey: Keys.environments)
		defaults.set(state.activeEnvironmentUuid, forKey: Keys.activeEnvironmentUuid)
		defaults.set(state.databaseServerUrl, forKey: Keys.databaseServerUrl)
		defaults.set(state.databaseVersionEndpoint, forKey: Keys.databaseVersionEndpoint)
		defaults.set(state.databaseDownloadEndpoint, forKey: Keys.databaseDownloadEndpoint)
		defaults.set(state.storagePath, forKey: Keys.storagePath)

	}

	func reset() {
		defaults.removeObject(forKey: Keys.environments)
		defaults.removeObject(forKey: Keys.activeEnvironmentUuid)
		defaults.removeObject(forKey: Keys.databaseServerUrl)
		defaults.removeObject(forKey: Keys.databaseVersionEndpoint)
		defaults.removeObject(forKey: Keys.databaseDownloadEndpoint)
		defaults.removeObject(forKey: Keys.storagePath)
		defaults.removeObject(forKey: Keys.didImportLegacy)
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

		let state = SettingsState(
			activeEnvironmentUuid: decoded.activeEnvironmentUuid,
			uemEnvironments: decoded.uemEnvironments ?? [],
			databaseServerUrl: decoded.databaseServerUrl,
			databaseVersionEndpoint: decoded.databaseVersionEndpoint,
			databaseDownloadEndpoint: decoded.databaseDownloadEndpoint,
			storagePath: decoded.storagePath
		)

		try? save(state)
		defaults.set(true, forKey: Keys.didImportLegacy)
		return state
	}

	private func loadEnvironments() -> [UemEnvironment] {
		guard let data = defaults.data(forKey: Keys.environments) else { return [] }
		guard let decoded = try? JSONDecoder().decode([UemEnvironment].self, from: data) else {
			return []
		}
		return decoded
	}
}
