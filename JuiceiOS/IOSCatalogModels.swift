import Foundation

struct IOSCaskApp: Decodable, Identifiable, Hashable {
    let token: String
    let fullToken: String?
    let name: [String]?
    let desc: String?
    let version: String?
    let homepage: String?

    var id: String { token }

    enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case name
        case desc
        case version
        case homepage
    }

    var displayName: String {
        if let first = name?.first, !first.isEmpty { return first }
        return token
    }
}

struct IOSAvailableUpdate: Identifiable, Hashable {
    let app: IOSCaskApp
    let installedVersion: String

    var id: String { app.token }
}
