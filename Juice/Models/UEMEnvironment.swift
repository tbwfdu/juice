//
//  UEMEnvironment.swift
//  Juice
//
//  Created by Pete Lindley on 27/1/2026.
//

import Foundation

enum UemAuthenticationType: String, Codable, CaseIterable, Identifiable {
	case oauthClientCredentials = "OAuthClientCredentials"
	case basicAuthApiKey = "BasicAuthApiKey"

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .oauthClientCredentials:
			return "OAuth"
		case .basicAuthApiKey:
			return "Basic Auth + API Key"
		}
	}

	init(decodedValue: String?) {
		guard let decodedValue else {
			self = .oauthClientCredentials
			return
		}
		let normalized = decodedValue.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		switch normalized.lowercased() {
		case "basicauthapikey", "basic_auth_api_key", "basic":
			self = .basicAuthApiKey
		case "oauthclientcredentials", "oauth_client_credentials", "oauth":
			self = .oauthClientCredentials
		default:
			self = .oauthClientCredentials
		}
	}
}

struct UemEnvironment: Codable, Identifiable {
    var id: UUID = UUID()
    var friendlyName: String = ""
    var uemUrl: String = ""
    var authenticationType: UemAuthenticationType = .oauthClientCredentials
    var clientId: String = ""
    var clientSecret: String = ""
    var oauthRegion: String = ""
    var basicUsername: String = ""
    var basicPassword: String = ""
    var apiKey: String = ""
    var orgGroupName: String = ""
    var orgGroupId: String = ""
    var orgGroupUuid: String = ""
    var secretRef: String = UUID().uuidString

	init(
		id: UUID = UUID(),
		friendlyName: String = "",
		uemUrl: String = "",
		authenticationType: UemAuthenticationType = .oauthClientCredentials,
		clientId: String = "",
		clientSecret: String = "",
		oauthRegion: String = "",
		basicUsername: String = "",
		basicPassword: String = "",
		apiKey: String = "",
		orgGroupName: String = "",
		orgGroupId: String = "",
		orgGroupUuid: String = "",
		secretRef: String = UUID().uuidString
	) {
		self.id = id
		self.friendlyName = friendlyName
		self.uemUrl = uemUrl
		self.authenticationType = authenticationType
		self.clientId = clientId
		self.clientSecret = clientSecret
		self.oauthRegion = oauthRegion
		self.basicUsername = basicUsername
		self.basicPassword = basicPassword
		self.apiKey = apiKey
		self.orgGroupName = orgGroupName
		self.orgGroupId = orgGroupId
		self.orgGroupUuid = orgGroupUuid
		let trimmedSecretRef = secretRef.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		self.secretRef = trimmedSecretRef.isEmpty
			? UUID().uuidString : trimmedSecretRef
	}

    func deepCopy() -> UemEnvironment {
        self
    }

    enum CodingKeys: String, CodingKey {
        case friendlyName = "FriendlyName"
        case uemUrl = "UemUrl"
        case authenticationType = "AuthenticationType"
        case clientId = "ClientId"
        case clientSecret = "ClientSecret"
        case oauthRegion = "OAuthRegion"
        case basicUsername = "BasicUsername"
        case basicPassword = "BasicPassword"
        case apiKey = "ApiKey"
        case orgGroupName = "OrgGroupName"
        case orgGroupId = "OrgGroupId"
        case orgGroupUuid = "OrgGroupUuid"
        case secretRef = "SecretRef"
    }

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		friendlyName = try container.decodeIfPresent(
			String.self,
			forKey: .friendlyName
		) ?? ""
		uemUrl = try container.decodeIfPresent(
			String.self,
			forKey: .uemUrl
		) ?? ""
		authenticationType = UemAuthenticationType(
			decodedValue: try container.decodeIfPresent(
				String.self,
				forKey: .authenticationType
			)
		)
		clientId = try container.decodeIfPresent(
			String.self,
			forKey: .clientId
		) ?? ""
		clientSecret = try container.decodeIfPresent(
			String.self,
			forKey: .clientSecret
		) ?? ""
		oauthRegion = try container.decodeIfPresent(
			String.self,
			forKey: .oauthRegion
		) ?? ""
		basicUsername = try container.decodeIfPresent(
			String.self,
			forKey: .basicUsername
		) ?? ""
		basicPassword = try container.decodeIfPresent(
			String.self,
			forKey: .basicPassword
		) ?? ""
		apiKey = try container.decodeIfPresent(
			String.self,
			forKey: .apiKey
		) ?? ""
		orgGroupName = try container.decodeIfPresent(
			String.self,
			forKey: .orgGroupName
		) ?? ""
		orgGroupId = try container.decodeIfPresent(
			String.self,
			forKey: .orgGroupId
		) ?? ""
		orgGroupUuid = try container.decodeIfPresent(
			String.self,
			forKey: .orgGroupUuid
		) ?? ""
		let decodedSecretRef = try container.decodeIfPresent(
			String.self,
			forKey: .secretRef
		) ?? ""
		let trimmedSecretRef = decodedSecretRef.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		secretRef = trimmedSecretRef.isEmpty
			? UUID().uuidString : trimmedSecretRef
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(friendlyName, forKey: .friendlyName)
		try container.encode(uemUrl, forKey: .uemUrl)
		try container.encode(authenticationType.rawValue, forKey: .authenticationType)
		try container.encode(clientId, forKey: .clientId)
		try container.encode(clientSecret, forKey: .clientSecret)
		try container.encode(oauthRegion, forKey: .oauthRegion)
		try container.encode(basicUsername, forKey: .basicUsername)
		try container.encode(basicPassword, forKey: .basicPassword)
		try container.encode(apiKey, forKey: .apiKey)
		try container.encode(orgGroupName, forKey: .orgGroupName)
		try container.encode(orgGroupId, forKey: .orgGroupId)
		try container.encode(orgGroupUuid, forKey: .orgGroupUuid)
		let trimmedSecretRef = secretRef.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		try container.encode(
			trimmedSecretRef.isEmpty ? UUID().uuidString : trimmedSecretRef,
			forKey: .secretRef
		)
	}
}
