//
//  UEMEnvironment.swift
//  Juice
//
//  Created by Pete Lindley on 27/1/2026.
//

import Foundation

struct UemEnvironment: Codable, Identifiable {
    var id: UUID = UUID()
    var friendlyName: String = ""
    var uemUrl: String = ""
    var clientId: String = ""
    var clientSecret: String = ""
    var oauthRegion: String = ""
    var orgGroupName: String = ""
    var orgGroupId: String = ""
    var orgGroupUuid: String = ""
    var secretRef: String = UUID().uuidString

	init(
		id: UUID = UUID(),
		friendlyName: String = "",
		uemUrl: String = "",
		clientId: String = "",
		clientSecret: String = "",
		oauthRegion: String = "",
		orgGroupName: String = "",
		orgGroupId: String = "",
		orgGroupUuid: String = "",
		secretRef: String = UUID().uuidString
	) {
		self.id = id
		self.friendlyName = friendlyName
		self.uemUrl = uemUrl
		self.clientId = clientId
		self.clientSecret = clientSecret
		self.oauthRegion = oauthRegion
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
        case clientId = "ClientId"
        case clientSecret = "ClientSecret"
        case oauthRegion = "OAuthRegion"
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
		try container.encode(clientId, forKey: .clientId)
		try container.encode(clientSecret, forKey: .clientSecret)
		try container.encode(oauthRegion, forKey: .oauthRegion)
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
