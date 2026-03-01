import Foundation
import Security

final class KeychainStore: @unchecked Sendable {
	// Safe to share: immutable service string and Keychain APIs are thread-safe.
	static let shared = KeychainStore()

	private let service: String

	init(service: String = Bundle.main.bundleIdentifier ?? "Juice") {
		self.service = service
	}

	func set(_ value: String, forKey key: String) throws {
		let data = Data(value.utf8)
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key
		]

		let update: [String: Any] = [
			kSecValueData as String: data
		]

		let status = SecItemCopyMatching(query as CFDictionary, nil)
		if status == errSecSuccess {
			let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
			guard updateStatus == errSecSuccess else {
				throw KeychainError(status: updateStatus)
			}
		} else if status == errSecItemNotFound {
			query[kSecValueData as String] = data
			let addStatus = SecItemAdd(query as CFDictionary, nil)
			guard addStatus == errSecSuccess else {
				throw KeychainError(status: addStatus)
			}
		} else {
			throw KeychainError(status: status)
		}
	}

	func get(forKey key: String) throws -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		if status == errSecItemNotFound {
			return nil
		}
		guard status == errSecSuccess else {
			throw KeychainError(status: status)
		}
		guard let data = item as? Data else { return nil }
		return String(data: data, encoding: .utf8)
	}

	func delete(forKey key: String) throws {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key
		]
		let status = SecItemDelete(query as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw KeychainError(status: status)
		}
	}

	func environmentClientSecretKey(secretRef: String) -> String {
		"juice.settings.env.\(secretRef).clientSecret"
	}

	func environmentBasicPasswordKey(secretRef: String) -> String {
		"juice.settings.env.\(secretRef).basicPassword"
	}

	func environmentApiKeyKey(secretRef: String) -> String {
		"juice.settings.env.\(secretRef).apiKey"
	}

	func setEnvironmentClientSecret(_ value: String, secretRef: String) throws {
		try set(
			value,
			forKey: environmentClientSecretKey(secretRef: secretRef)
		)
	}

	func getEnvironmentClientSecret(secretRef: String) throws -> String? {
		try get(forKey: environmentClientSecretKey(secretRef: secretRef))
	}

	func deleteEnvironmentClientSecret(secretRef: String) throws {
		try delete(
			forKey: environmentClientSecretKey(secretRef: secretRef)
		)
	}

	func setEnvironmentBasicPassword(_ value: String, secretRef: String) throws {
		try set(
			value,
			forKey: environmentBasicPasswordKey(secretRef: secretRef)
		)
	}

	func getEnvironmentBasicPassword(secretRef: String) throws -> String? {
		try get(forKey: environmentBasicPasswordKey(secretRef: secretRef))
	}

	func deleteEnvironmentBasicPassword(secretRef: String) throws {
		try delete(
			forKey: environmentBasicPasswordKey(secretRef: secretRef)
		)
	}

	func setEnvironmentApiKey(_ value: String, secretRef: String) throws {
		try set(
			value,
			forKey: environmentApiKeyKey(secretRef: secretRef)
		)
	}

	func getEnvironmentApiKey(secretRef: String) throws -> String? {
		try get(forKey: environmentApiKeyKey(secretRef: secretRef))
	}

	func deleteEnvironmentApiKey(secretRef: String) throws {
		try delete(
			forKey: environmentApiKeyKey(secretRef: secretRef)
		)
	}
}

struct KeychainError: LocalizedError {
	let status: OSStatus

	var errorDescription: String? {
		SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error: \(status)"
	}
}
