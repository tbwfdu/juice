//
//  UEMEnvironment.swift
//  JuiceSwift
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
    }
}
