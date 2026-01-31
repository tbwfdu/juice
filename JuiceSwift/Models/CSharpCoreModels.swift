import Foundation
#if os(macOS)
import AppKit
#endif

struct AppConfig: Codable {
    var environment: String?

    enum CodingKeys: String, CodingKey {
        case environment = "Environment"
    }
}

struct ChangedValue: Codable {
    var key: String
    var oldValue: String
    var newValue: String
}

struct Entity: Codable {
    var name: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
    }
}

struct ProgressUpdate: Codable {
    var errorCount: Int?
    var successCount: Int?
    var completedAppsCount: String?
    var totalAppsCount: String?
    var inProgressAppName: String?
    var currentAppStatus: String?
    var nextAppName: String?
}

struct MunkiMetadata: Codable {
    var installerFile: String?
    var installerPlist: String?
    var iconFile: String?

    enum CodingKeys: String, CodingKey {
        case installerFile = "InstallerFile"
        case installerPlist = "InstallerPlist"
        case iconFile = "IconFile"
    }
}

struct RecipeApplication: Codable {
    var guid: String = UUID().uuidString
    var identifier: String?
    var displayName: String?
    var description: String?
    var url: String?
    var pkgInfo: JsonRecipeMetadata.MunkiJson.Pkginfo?

    enum CodingKeys: String, CodingKey {
        case guid = "Guid"
        case identifier = "Identifier"
        case displayName = "DisplayName"
        case description = "Description"
        case url = "Url"
        case pkgInfo = "PkgInfo"
    }
}

struct JuiceResult {
    var appName: String?
    var success: Bool?
    var reason: String?
    var resultMessage: String?
    var applicationId: String?
    var applicationUuid: String?
    var transactionId: String?
    var blobId: Int?
    var guid: String?
    var appIconPath: String?
    var iconPath: String?
    var jsonResponse: [String: Any]?
}

struct JuiceSettings: Codable {
    var applicationDataFolder: String?
    var localSettingsFile: String?
    var verboseLogging: String?
    var storagePath: String?
    var munkiToolsPath: String?
    var munkiPreferencesPath: String?
    var uemEnvironments: [UemEnvironment]?
    var databaseServerUrl: String?
    var databaseVersionEndpoint: String?
    var databaseDownloadEndpoint: String?

    enum CodingKeys: String, CodingKey {
        case applicationDataFolder = "ApplicationDataFolder"
        case localSettingsFile = "LocalSettingsFile"
        case verboseLogging = "VerboseLogging"
        case storagePath = "StoragePath"
        case munkiToolsPath = "MunkiToolsPath"
        case munkiPreferencesPath = "MunkiPreferencesPath"
        case uemEnvironments = "UemEnvironments"
        case databaseServerUrl = "DatabaseServerUrl"
        case databaseVersionEndpoint = "DatabaseVersionEndpoint"
        case databaseDownloadEndpoint = "DatabaseDownloadEndpoint"
    }
}

struct LocalSettings: Codable {}

struct FileContents: Codable {
    var theme: String? = "Light"
    var verboseLogging: String = "True"
    var getAppUpdatesOnStartup: String = "True"
    var eulaAccepted: String = "True"
    var uemEnvironments: [UemEnvironment]?
    var activeEnvironmentUuid: String?
    var storagePath: String?
    var databaseServerUrl: String?
    var databaseVersionEndpoint: String?
    var databaseDownloadEndpoint: String?

    enum CodingKeys: String, CodingKey {
        case theme = "Theme"
        case verboseLogging = "VerboseLogging"
        case getAppUpdatesOnStartup = "GetAppUpdatesOnStartup"
        case eulaAccepted = "EulaAccepted"
        case uemEnvironments = "UemEnvironments"
        case activeEnvironmentUuid = "ActiveEnvironmentUuid"
        case storagePath = "StoragePath"
        case databaseServerUrl = "DatabaseServerUrl"
        case databaseVersionEndpoint = "DatabaseVersionEndpoint"
        case databaseDownloadEndpoint = "DatabaseDownloadEndpoint"
    }
}

struct SuccessfulDownload {
    var fileName: String
    var fileExtension: String
    var fullFilePath: String
    var fullFolderPath: String
    var guid: UUID = UUID()
    var selectedIconPath: String?
    var selectedIconIndex: Int?
    #if os(macOS)
    var availableIcons: [NSImage] = []
    #endif
    var munkiMetadata: MunkiMetadata?
    var macApplication: CaskApplication?
    var uploadProgress: UploadProgress?
    var shouldCloseFlyout: Bool = false
    var parsedMetadata: ParsedMetadata?
    var proposedMetadata: ParsedMetadata?
}

struct SuccessfulUpload {
    var name: String
    var state: String
    var selectedIconPath: String?
    var munkiMetadata: MunkiMetadata?
    var macApplication: CaskApplication?
    var uploadProgress: UploadProgress?
}

struct ImportedApplication: Identifiable {
    var id: UUID = UUID()
    var fileName: String
    var fileExtension: String
    var fullFilePath: String
    var hasMetadata: Bool = false
    var isSelected: Bool = false
    var munkiMetadata: MunkiMetadata?
    var macApplication: CaskApplication?
    #if os(macOS)
    var selectedIcon: NSImage?
    var importedIcnsImage: NSImage?
    var availableIcons: [NSImage] = []
    #endif
    var selectedIconIndex: Int?
    var selectedIconPath: String?
    var uploadProgress: UploadProgress? = UploadProgress()
    var metadataProgress: MetadataProgress = MetadataProgress()
    var shouldCloseFlyout: Bool = false
    var parsedMetadata: ParsedMetadata?
    var proposedMetadata: ParsedMetadata?
}
