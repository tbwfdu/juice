import Foundation

//Allow use of UUID as the unique identifier
extension UemApplication: Identifiable {
	var id: String {
		if let uuid, !uuid.isEmpty { return uuid }
		if let numeric = numericId?.value { return String(numeric) }
		return UUID().uuidString
	}
}


struct Id: Codable, Sendable {
    var value: Int?

    enum CodingKeys: String, CodingKey {
        case value = "Value"
    }
}

struct OrganizationGroup: Codable {
    var name: String?
    var groupId: String?
    var locationGroupType: String?
    var country: String?
    var locale: String?
    var createdOn: String?
    var users: String?
    var admins: String?
    var devices: String?
    var isCustomerTypeExistInParentHierarchy: Bool?
    var id: Id?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case groupId = "GroupId"
        case locationGroupType = "LocationGroupType"
        case country = "Country"
        case locale = "Locale"
        case createdOn = "CreatedOn"
        case users = "Users"
        case admins = "Admins"
        case devices = "Devices"
        case isCustomerTypeExistInParentHierarchy = "IsCustomerTypeExistInParentHierarchy"
        case id = "Id"
    }

    /// Use numeric `Id.Value` when available (required by several UEM endpoints),
    /// and fall back to `GroupId` only when needed.
    var resolvedGroupId: String? {
        if let numeric = id?.value {
            return String(numeric)
        }
        return groupId?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ParentLocationGroupRef: Codable, Sendable {
    var id: Id?
    var uuid: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case uuid = "Uuid"
    }
}

struct OrganizationGroupChildrenResponseItem: Codable, Sendable {
    var name: String?
    var groupId: String?
    var locationGroupType: String?
    var country: String?
    var locale: String?
    var parentLocationGroup: ParentLocationGroupRef?
    var createdOn: String?
    var lgLevel: Int?
    var users: String?
    var admins: String?
    var devices: String?
    var isCustomerTypeExistInParentHierarchy: Bool?
    var id: Id?
    var uuid: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case groupId = "GroupId"
        case locationGroupType = "LocationGroupType"
        case country = "Country"
        case locale = "Locale"
        case parentLocationGroup = "ParentLocationGroup"
        case createdOn = "CreatedOn"
        case lgLevel = "LgLevel"
        case users = "Users"
        case admins = "Admins"
        case devices = "Devices"
        case isCustomerTypeExistInParentHierarchy = "IsCustomerTypeExistInParentHierarchy"
        case id = "Id"
        case uuid = "Uuid"
    }
}

struct ActiveEnvironmentDetails: Sendable {
    var parentDeviceCount: Int?
    var parentAdminCount: Int?
    var childOrganizationGroupCount: Int
    var appCount: Int?
    var parentGroupName: String?
    var parentGroupId: String?
    var parentGroupUuid: String?
}

struct UemApplication: Codable, Sendable {
    var applicationName: String
    var bundleId: String
    var appVersion: String
    var actualFileVersion: String
    var appType: String?
    var status: String?
    var platform: Int?
    var supportedModels: SupportedModels?
    var assignmentStatus: String?
    var categoryList: CategoryList?
    var smartGroups: [SmartGroup]?
    var isReimbursable: Bool?
    var applicationSource: Int?
    var locationGroupId: Int?
    var rootLocationGroupName: String?
    var organizationGroupUuid: String?
    var largeIconUri: String?
    var mediumIconUri: String?
    var smallIconUri: String?
    var pushMode: Int?
    var appRank: Int?
    var assignedDeviceCount: Int?
    var installedDeviceCount: Int?
    var notInstalledDeviceCount: Int?
    var autoUpdateVersion: Bool?
    var enableProvisioning: Bool?
    var isDependencyFile: Bool?
    var contentGatewayId: Int?
    var iconFileName: String?
    var applicationFileName: String
    var metadataFileName: String?
    var numericId: Id?
    var uuid: String?
    var isSelected: Bool? = false
    var hasUpdate: Bool? = false
    var hasLaterVersionInConsole: Bool? = false
    var isLatest: Bool?
    var wasMatched: Bool?
    var updatedApplicationGuid: String?
    var updatedApplication: CaskApplication?

    enum CodingKeys: String, CodingKey {
        case applicationName = "ApplicationName"
        case bundleId = "BundleId"
        case appVersion = "AppVersion"
        case actualFileVersion = "ActualFileVersion"
        case appType = "AppType"
        case status = "Status"
        case platform = "Platform"
        case supportedModels = "SupportedModels"
        case assignmentStatus = "AssignmentStatus"
        case categoryList = "CategoryList"
        case smartGroups = "SmartGroups"
        case isReimbursable = "IsReimbursable"
        case applicationSource = "ApplicationSource"
        case locationGroupId = "LocationGroupId"
        case rootLocationGroupName = "RootLocationGroupName"
        case organizationGroupUuid = "OrganizationGroupUuid"
        case largeIconUri = "LargeIconUri"
        case mediumIconUri = "MediumIconUri"
        case smallIconUri = "SmallIconUri"
        case pushMode = "PushMode"
        case appRank = "AppRank"
        case assignedDeviceCount = "AssignedDeviceCount"
        case installedDeviceCount = "InstalledDeviceCount"
        case notInstalledDeviceCount = "NotInstalledDeviceCount"
        case autoUpdateVersion = "AutoUpdateVersion"
        case enableProvisioning = "EnableProvisioning"
        case isDependencyFile = "IsDependencyFile"
        case contentGatewayId = "ContentGatewayId"
        case iconFileName = "IconFileName"
        case applicationFileName = "ApplicationFileName"
        case metadataFileName = "MetadataFileName"
        case numericId = "Id"
        case uuid = "Uuid"
        case isSelected = "IsSelected"
        case hasUpdate = "HasUpdate"
        case hasLaterVersionInConsole = "HasLaterVersionInConsole"
        case isLatest = "IsLatest"
        case wasMatched = "WasMatched"
        case updatedApplicationGuid = "UpdatedApplicationGuid"
        case updatedApplication = "UpdatedApplication"
    }
}

struct CategoryList: Codable, Sendable {
    var category: [AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case category = "Category"
    }
}

struct SmartGroup: Codable {
    var id: Int?
    var name: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

struct Model: Codable {
    var applicationId: Int?
    var modelId: Int?
    var modelName: String?

    enum CodingKeys: String, CodingKey {
        case applicationId = "ApplicationId"
        case modelId = "ModelId"
        case modelName = "ModelName"
    }
}

struct SupportedModels: Codable {
    var model: [Model]?

    enum CodingKeys: String, CodingKey {
        case model = "Model"
    }
}

enum AnyCodable: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyCodable].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }
}
