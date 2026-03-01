import Foundation
#if os(macOS)
import AppKit
#endif

struct Recipe: Codable {
    var id: LiteDBId?
    var parentRecipe: String?
    var name: String?
    var displayName: String?
    var copyright: String?
    var identifier: String?
    var description: String?
    var comment: String?
    var comments: String?
    var pkgInfo: PkgInfo?
    var input: Input?
    var guid: UUID?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case parentRecipe = "ParentRecipe"
        case name = "Name"
        case displayName = "DisplayName"
        case copyright = "Copyright"
        case identifier = "Identifier"
        case description = "Description"
        case comment = "Comment"
        case comments = "comments"
        case pkgInfo = "PkgInfo"
        case input = "Input"
        case guid = "Guid"
    }
}

struct Input: Codable {
    var destinationAppName: String?
    var munkiRepoSubdir: String?
    var iconName: String?
    var pkgInfo: PkgInfo?
    var arbitrarySuffix: String?
    var appleId: String?
    var name: String?
    var useVersionedFilename: String?
    var filenameSuffix: String?
    var jdkName: String?
    var destinationPath: String?
    var os: String?
    var version: String?
    var path: String?
    var deriveMinOs: String?
    var supportedArch: String?
    var minimumOsVersion: String?
    var downloadUrl: String?
    var productId: String?
    var forceMunkiimport: String?
    var munkiCategory: String?
    var pythonMajorVersion: String?
    var installerType: String?
    var displayName: String?
    var munkiDeveloper: String?
    var munkiCatalogs: String?
    var snagitLicenceKey: String?
    var language: String?
    var defaultCatalog: String?
    var downloadUrlAlt: String?
    var requires: String?
    var munkiName: String?
    var arch: String?
    var supportedOs: String?
    var softwareType: String?
    var softwareTitle: String?
    var vendor: String?
    var majorVersion: String?
    var munkiArchitecture: String?
    var userAgent: String?
    var searchUrl: String?
    var osLower: String?
    var appFilename: String?
    var pkginfoKeysToCopyFromSparkleFeed: [String?]?
    var appName: String?
    var searchPattern: String?
    var munkiDescription: String?
    var versionDestinationPath: String?
    var snagit2024LicenceKey: String?
    var locale: String?
    var unattendedUninstall: String?
    var sparkleFeedUrl: String?
    var munkiDisplayName: String?
    var installArch: String?
    var forceMunkiimportLower: String?
    var displayname: String?
    var descriptionUpper: String?
    var id: String?
    var versionType: String?
    var munkiRequiredUpdateName: String?
    var osVersion: String?
    var cultureCode: String?
    var downloadUrlScheme: String?
    var basename: String?
    var munkitoolsCoreName: String?
    var munkitoolsAppUsageDescription: String?
    var munkitoolsLaunchdDescription: String?
    var munkiCatalog: String?
    var includePrereleases: String?
    var munkitoolsLaunchdDisplayname: String?
    var munkitoolsAppName: String?
    var munkitoolsCoreDisplayname: String?
    var munkitoolsAppDescription: String?
    var munkitoolsCoreDescription: String?
    var munkitoolsAppUsageDisplayname: String?
    var munkiIcon: String?
    var munkitoolsAdminDescription: String?
    var munkitoolsAppDisplayname: String?
    var munkitoolsAppUsageName: String?
    var munkitoolsAdminName: String?
    var munkitoolsAdminDisplayname: String?
    var munkitoolsLaunchdName: String?
    var munkitoolsPythonDisplayname: String?
    var munkitoolsPythonDescription: String?
    var munkitoolsPythonName: String?
    var makepkginfoPkgname: String?
    var k2clientconfigOptions: String?
    var pkgIdsSetOptionalTrue: [String]?
    var filename: String?
    var selection: String?
    var uninstallPassword: String?
    var pathname: String?
    var platformArch: String?
    var terminalApp: String?
    var privateToken: String?
    var gitlabHostname: String?
    var jobName: String?
    var artifactPath: String?
    var urlencodedProject: String?
    var virustotalAutoSubmit: String?
    var release: String?
    var munkiimportPkgName: String?
    var releaseChannel: String?
    var pkgPath: String?

    enum CodingKeys: String, CodingKey {
        case destinationAppName = "DESTINATION_APP_NAME"
        case munkiRepoSubdir = "MUNKI_REPO_SUBDIR"
        case iconName = "ICON_NAME"
        case pkgInfo = "pkginfo"
        case arbitrarySuffix = "ARBITRARY_SUFFIX"
        case appleId = "APPLE_ID"
        case name = "NAME"
        case useVersionedFilename = "USE_VERSIONED_FILENAME"
        case filenameSuffix = "FILENAME_SUFFIX"
        case jdkName = "JDK_NAME"
        case destinationPath = "DESTINATION_PATH"
        case os = "OS"
        case version = "VERSION"
        case path = "PATH"
        case deriveMinOs = "DERIVE_MIN_OS"
        case supportedArch = "SUPPORTED_ARCH"
        case minimumOsVersion = "MINIMUM_OS_VERSION"
        case downloadUrl = "DOWNLOADURL"
        case productId = "PRODUCTID"
        case forceMunkiimport = "FORCE_MUNKIIMPORT"
        case munkiCategory = "MUNKI_CATEGORY"
        case pythonMajorVersion = "PYTHON_MAJOR_VERSION"
        case installerType = "INSTALLER_TYPE"
        case displayName = "DISPLAY_NAME"
        case munkiDeveloper = "MUNKI_DEVELOPER"
        case munkiCatalogs = "MUNKI_CATALOGS"
        case snagitLicenceKey = "SNAGIT_LICENCE_KEY"
        case language = "LANGUAGE"
        case defaultCatalog = "DEFAULT_CATALOG"
        case downloadUrlAlt = "DOWNLOAD_URL"
        case requires = "REQUIRES"
        case munkiName = "MUNKI_NAME"
        case arch = "ARCH"
        case supportedOs = "SUPPORTED_OS"
        case softwareType = "SOFTWARETYPE"
        case softwareTitle = "SOFTWARETITLE"
        case vendor = "VENDOR"
        case majorVersion = "MAJOR_VERSION"
        case munkiArchitecture = "MUNKI_ARCHITECTURE"
        case userAgent = "USER_AGENT"
        case searchUrl = "SEARCH_URL"
        case osLower = "os"
        case appFilename = "APP_FILENAME"
        case pkginfoKeysToCopyFromSparkleFeed = "pkginfo_keys_to_copy_from_sparkle_feed"
        case appName = "app_name"
        case searchPattern = "SEARCH_PATTERN"
        case munkiDescription = "MUNKI_DESCRIPTION"
        case versionDestinationPath = "VERSION_DESTINATION_PATH"
        case snagit2024LicenceKey = "SNAGIT_2024_LICENCE_KEY"
        case locale = "LOCALE"
        case unattendedUninstall = "unattended_uninstall"
        case sparkleFeedUrl = "SPARKLE_FEED_URL"
        case munkiDisplayName = "MUNKI_DISPLAY_NAME"
        case installArch = "INSTALL_ARCH"
        case forceMunkiimportLower = "force_munkiimport"
        case displayname = "DISPLAYNAME"
        case descriptionUpper = "DESCRIPTION"
        case id = "ID"
        case versionType = "VERSIONTYPE"
        case munkiRequiredUpdateName = "munki_required_update_name"
        case osVersion = "OS_VERSION"
        case cultureCode = "CULTURE_CODE"
        case downloadUrlScheme = "DOWNLOAD_URL_SCHEME"
        case basename = "BASENAME"
        case munkitoolsCoreName = "MUNKITOOLS_CORE_NAME"
        case munkitoolsAppUsageDescription = "MUNKITOOLS_APP_USAGE_DESCRIPTION"
        case munkitoolsLaunchdDescription = "MUNKITOOLS_LAUNCHD_DESCRIPTION"
        case munkiCatalog = "MUNKI_CATALOG"
        case includePrereleases = "INCLUDE_PRERELEASES"
        case munkitoolsLaunchdDisplayname = "MUNKITOOLS_LAUNCHD_DISPLAYNAME"
        case munkitoolsAppName = "MUNKITOOLS_APP_NAME"
        case munkitoolsCoreDisplayname = "MUNKITOOLS_CORE_DISPLAYNAME"
        case munkitoolsAppDescription = "MUNKITOOLS_APP_DESCRIPTION"
        case munkitoolsCoreDescription = "MUNKITOOLS_CORE_DESCRIPTION"
        case munkitoolsAppUsageDisplayname = "MUNKITOOLS_APP_USAGE_DISPLAYNAME"
        case munkiIcon = "MUNKI_ICON"
        case munkitoolsAdminDescription = "MUNKITOOLS_ADMIN_DESCRIPTION"
        case munkitoolsAppDisplayname = "MUNKITOOLS_APP_DISPLAYNAME"
        case munkitoolsAppUsageName = "MUNKITOOLS_APP_USAGE_NAME"
        case munkitoolsAdminName = "MUNKITOOLS_ADMIN_NAME"
        case munkitoolsAdminDisplayname = "MUNKITOOLS_ADMIN_DISPLAYNAME"
        case munkitoolsLaunchdName = "MUNKITOOLS_LAUNCHD_NAME"
        case munkitoolsPythonDisplayname = "MUNKITOOLS_PYTHON_DISPLAYNAME"
        case munkitoolsPythonDescription = "MUNKITOOLS_PYTHON_DESCRIPTION"
        case munkitoolsPythonName = "MUNKITOOLS_PYTHON_NAME"
        case makepkginfoPkgname = "MAKEPKGINFO_PKGNAME"
        case k2clientconfigOptions = "K2CLIENTCONFIG_OPTIONS"
        case pkgIdsSetOptionalTrue = "pkg_ids_set_optional_true"
        case filename = "FILENAME"
        case selection = "SELECTION"
        case uninstallPassword = "UNINSTALL_PASSWORD"
        case pathname = "pathname"
        case platformArch = "PLATFORM_ARCH"
        case terminalApp = "TERMINAL_APP"
        case privateToken = "PRIVATE_TOKEN"
        case gitlabHostname = "GITLAB_HOSTNAME"
        case jobName = "JOB_NAME"
        case artifactPath = "ARTIFACT_PATH"
        case urlencodedProject = "URLENCODED_PROJECT"
        case virustotalAutoSubmit = "VIRUSTOTAL_AUTO_SUBMIT"
        case release = "RELEASE"
        case munkiimportPkgName = "MUNKIIMPORT_PKG_NAME"
        case releaseChannel = "RELEASE_CHANNEL"
        case pkgPath = "PKG_PATH"
    }
}

struct PkgInfo: Codable {
    var category: String?
    var iconName: String?
    var requires: [String]?
    var installs: [InstallItem]?
    var minimumOsVersion: String?
    var developer: String?
    var unattendedInstall: String?
    var displayName: String?
    var description: String?
    var name: String?
    var postinstallScript: String?
    var uninstallMethod: String?
    var blockingApplications: [String]?
    var uninstallScript: String?
    var unattendedUninstall: String?
    var maximumOsVersion: String?
    var postuninstallScript: String?
    var restartAction: String?
    var preinstallScript: String?
    var uninstallable: String?
    var unattendedUnnstall: String?
    var preuninstallScript: String?
    var installerChoicesXML: [InstallerChoicesXML?]?
    var installcheckScript: String?

    enum CodingKeys: String, CodingKey {
        case category = "category"
        case iconName = "icon_name"
        case requires = "requires"
        case installs = "installs"
        case minimumOsVersion = "minimum_os_version"
        case developer = "developer"
        case unattendedInstall = "unattended_install"
        case displayName = "display_name"
        case description = "description"
        case name = "name"
        case postinstallScript = "postinstall_script"
        case uninstallMethod = "uninstall_method"
        case blockingApplications = "blocking_applications"
        case uninstallScript = "uninstall_script"
        case unattendedUninstall = "unattended_uninstall"
        case maximumOsVersion = "maximum_os_version"
        case postuninstallScript = "postuninstall_script"
        case restartAction = "RestartAction"
        case preinstallScript = "preinstall_script"
        case uninstallable = "uninstallable"
        case unattendedUnnstall = "unattended_unnstall"
        case preuninstallScript = "preuninstall_script"
        case installerChoicesXML = "installer_choices_xml"
        case installcheckScript = "installcheck_script"
    }
}

struct RecipeMatchCandidate: Codable, Hashable, Identifiable {
    var displayName: String
    var identifier: String
    var score: Int
    var matchedOn: String

    var id: String { identifier }
}

struct InstallerChoicesXML: Codable {
    var attributeSetting: String?
    var choiceAttribute: String?
    var choiceIdentifier: String?
}

final class CaskApplication: ObservableObject, Codable, Identifiable {
    var dbId: LiteDBId?
    var token: String
    var fullToken: String
    var oldTokens: [String]?
    var tap: String
    var name: [String]
    var desc: String?
    var homepage: String?
    var url: String
    var urlSpecs: URLSpecs?
    var version: String
    var outdated: Bool
    var sha256: String
    var caveats: String?
    var dependsOn: DependsOn?
    var conflictsWith: ConflictsWith?
    var autoUpdates: Bool?
    var deprecated: Bool?
    var disabled: Bool?
    var languages: [String]?
    var variations: Variations?
    var useSpecificOs: Bool
    var specificOs: String?
    var guid: String
    var appToUpdate: UemApplication?
    @Published var downloadProgress: DownloadProgress
    var parsedMetadata: ParsedMetadata?
    var matchingRecipeId: String?
    var matchingRecipeCandidates: [RecipeMatchCandidate]?
    var matchedOn: String?
    var matchedScore: Int?

    var id: String { fullToken.isEmpty ? token : fullToken }

    init(
        token: String,
        fullToken: String = "",
        tap: String = "homebrew/cask",
        name: [String],
        desc: String? = nil,
        homepage: String? = nil,
        url: String,
        version: String,
        outdated: Bool = false,
        sha256: String = "",
        caveats: String? = nil,
        autoUpdates: Bool? = nil,
        deprecated: Bool? = nil,
        disabled: Bool? = nil,
        languages: [String]? = nil,
        useSpecificOs: Bool = false,
        specificOs: String? = nil,
        guid: String = UUID().uuidString,
        matchingRecipeId: String? = nil,
        matchingRecipeCandidates: [RecipeMatchCandidate]? = nil,
        matchedOn: String? = nil,
        matchedScore: Int? = nil,
        downloadProgress: DownloadProgress = DownloadProgress()
    ) {
        self.dbId = nil
        self.token = token
        self.fullToken = fullToken
        self.oldTokens = nil
        self.tap = tap
        self.name = name
        self.desc = desc
        self.homepage = homepage
        self.url = url
        self.urlSpecs = nil
        self.version = version
        self.outdated = outdated
        self.sha256 = sha256
        self.caveats = caveats
        self.dependsOn = nil
        self.conflictsWith = nil
        self.autoUpdates = autoUpdates
        self.deprecated = deprecated
        self.disabled = disabled
        self.languages = languages
        self.variations = nil
        self.useSpecificOs = useSpecificOs
        self.specificOs = specificOs
        self.guid = guid
        self.appToUpdate = nil
        self.downloadProgress = downloadProgress
        self.parsedMetadata = nil
        self.matchingRecipeId = matchingRecipeId
        self.matchingRecipeCandidates = matchingRecipeCandidates
        self.matchedOn = matchedOn
        self.matchedScore = matchedScore
    }

    enum CodingKeys: String, CodingKey {
        case dbId = "_id"
        case token
        case fullToken = "full_token"
        case oldTokens = "old_tokens"
        case tap
        case name
        case desc
        case homepage
        case url
        case urlSpecs = "url_specs"
        case version
        case outdated
        case sha256
        case caveats
        case dependsOn = "depends_on"
        case conflictsWith = "conflicts_with"
        case autoUpdates = "auto_updates"
        case deprecated
        case disabled
        case languages
        case variations
        case useSpecificOs = "use_specific_os"
        case specificOs = "specific_os"
        case guid
        case appToUpdate = "app_to_update"
        case downloadProgress
        case parsedMetadata = "ParsedMetadata"
        case matchingRecipeId
        case matchingRecipeCandidates
        case matchedOn
        case matchedScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dbId = try container.decodeIfPresent(LiteDBId.self, forKey: .dbId)
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        fullToken = try container.decodeIfPresent(String.self, forKey: .fullToken) ?? ""
        oldTokens = try container.decodeIfPresent([String].self, forKey: .oldTokens)
        tap = try container.decodeIfPresent(String.self, forKey: .tap) ?? ""
        name = try container.decodeIfPresent([String].self, forKey: .name) ?? []
        desc = try container.decodeIfPresent(String.self, forKey: .desc)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        urlSpecs = try container.decodeIfPresent(URLSpecs.self, forKey: .urlSpecs)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? ""
        outdated = try container.decodeIfPresent(Bool.self, forKey: .outdated) ?? false
        sha256 = try container.decodeIfPresent(String.self, forKey: .sha256) ?? ""
        caveats = try container.decodeIfPresent(String.self, forKey: .caveats)
        dependsOn = try container.decodeIfPresent(DependsOn.self, forKey: .dependsOn)
        conflictsWith = try container.decodeIfPresent(ConflictsWith.self, forKey: .conflictsWith)
        autoUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoUpdates)
        deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated)
        disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled)
        languages = try container.decodeIfPresent([String].self, forKey: .languages)
        variations = try container.decodeIfPresent(Variations.self, forKey: .variations)
        useSpecificOs = try container.decodeIfPresent(Bool.self, forKey: .useSpecificOs) ?? false
        specificOs = try container.decodeIfPresent(String.self, forKey: .specificOs)
        guid = try container.decodeIfPresent(String.self, forKey: .guid) ?? UUID().uuidString
        appToUpdate = try container.decodeIfPresent(UemApplication.self, forKey: .appToUpdate)
        downloadProgress = try container.decodeIfPresent(DownloadProgress.self, forKey: .downloadProgress) ?? DownloadProgress()
        parsedMetadata = try container.decodeIfPresent(ParsedMetadata.self, forKey: .parsedMetadata)
        matchingRecipeId = try container.decodeIfPresent(String.self, forKey: .matchingRecipeId)
        matchingRecipeCandidates = try container.decodeIfPresent([RecipeMatchCandidate].self, forKey: .matchingRecipeCandidates)
        matchedOn = try container.decodeIfPresent(String.self, forKey: .matchedOn)
        matchedScore = try container.decodeIfPresent(Int.self, forKey: .matchedScore)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(dbId, forKey: .dbId)
        try container.encode(token, forKey: .token)
        try container.encode(fullToken, forKey: .fullToken)
        try container.encodeIfPresent(oldTokens, forKey: .oldTokens)
        try container.encode(tap, forKey: .tap)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(desc, forKey: .desc)
        try container.encodeIfPresent(homepage, forKey: .homepage)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(urlSpecs, forKey: .urlSpecs)
        try container.encode(version, forKey: .version)
        try container.encode(outdated, forKey: .outdated)
        try container.encode(sha256, forKey: .sha256)
        try container.encodeIfPresent(caveats, forKey: .caveats)
        try container.encodeIfPresent(dependsOn, forKey: .dependsOn)
        try container.encodeIfPresent(conflictsWith, forKey: .conflictsWith)
        try container.encodeIfPresent(autoUpdates, forKey: .autoUpdates)
        try container.encodeIfPresent(deprecated, forKey: .deprecated)
        try container.encodeIfPresent(disabled, forKey: .disabled)
        try container.encodeIfPresent(languages, forKey: .languages)
        try container.encodeIfPresent(variations, forKey: .variations)
        try container.encode(useSpecificOs, forKey: .useSpecificOs)
        try container.encodeIfPresent(specificOs, forKey: .specificOs)
        try container.encode(guid, forKey: .guid)
        try container.encodeIfPresent(appToUpdate, forKey: .appToUpdate)
        try container.encode(downloadProgress, forKey: .downloadProgress)
        try container.encodeIfPresent(parsedMetadata, forKey: .parsedMetadata)
        try container.encodeIfPresent(matchingRecipeId, forKey: .matchingRecipeId)
        try container.encodeIfPresent(matchingRecipeCandidates, forKey: .matchingRecipeCandidates)
        try container.encodeIfPresent(matchedOn, forKey: .matchedOn)
        try container.encodeIfPresent(matchedScore, forKey: .matchedScore)
    }
}

struct LiteDBId: Codable {
    var oid: String

    enum CodingKeys: String, CodingKey {
        case oid = "$oid"
    }
}

struct Artifact: Codable {
    var uninstall: [Uninstall?]?
    var pkg: [String?]?
    var postflight: String?
    var quit: String?
}

struct BigSur: Codable {
    var url: String?
    var sha256: String?
}

struct Catalina: Codable {
    var url: String?
    var sha256: String?
}

struct ConflictsWith: Codable {
    var cask: [String?]?
}

struct DependsOn: Codable {
    var macOS: MacOS?

    enum CodingKeys: String, CodingKey {
        case macOS = "macos"
    }
}

struct ElCapitan: Codable {
    var url: String?
    var sha256: String?
}

struct HighSierra: Codable {
    var url: String?
    var sha256: String?
}

struct MacOS: Codable {
    var versions: [String?]?
}

struct Mojave: Codable {
    var url: String?
    var sha256: String?
}

struct Monterey: Codable {
    var url: String?
    var sha256: String?
}

struct RubySourceChecksum: Codable {
    var sha256: String?
}

struct Sequoia: Codable {
    var url: String?
    var sha256: String?
}

struct Sierra: Codable {
    var url: String?
    var sha256: String?
}

struct Sonoma: Codable {
    var url: String?
    var sha256: String?
}

struct Uninstall: Codable {
    var launchctl: [String?]?
    var signal: [String?]?
    var delete: [String?]?
}

struct URLSpecs: Codable {}

struct Variations: Codable {
    var sequoia: Sequoia?
    var sonoma: Sonoma?
    var ventura: Ventura?
    var monterey: Monterey?
    var bigSur: BigSur?
    var catalina: Catalina?
    var mojave: Mojave?
    var highSierra: HighSierra?
    var sierra: Sierra?
    var elCapitan: ElCapitan?

    enum CodingKeys: String, CodingKey {
        case sequoia
        case sonoma
        case ventura
        case monterey
        case bigSur = "big_sur"
        case catalina
        case mojave
        case highSierra = "high_sierra"
        case sierra
        case elCapitan = "el_capitan"
    }
}

struct Ventura: Codable {
    var url: String?
    var sha256: String?
}

struct Zap: Codable {
    var trash: [String?]?
}

// MARK: - Core Domain Models

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
    var databaseAppsEndpoint: String?
    var databaseRecipesEndpoint: String?
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
        case databaseAppsEndpoint = "DatabaseAppsEndpoint"
        case databaseRecipesEndpoint = "DatabaseRecipesEndpoint"
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
    var databaseAppsEndpoint: String?
    var databaseRecipesEndpoint: String?
    var databaseServerUrl: String?
    var databaseVersionEndpoint: String?
    var databaseDownloadEndpoint: String?
    var prominentButtonTintHex: String?
    var useActiveEnvironmentBrandingTint: Bool?

    enum CodingKeys: String, CodingKey {
        case theme = "Theme"
        case verboseLogging = "VerboseLogging"
        case getAppUpdatesOnStartup = "GetAppUpdatesOnStartup"
        case eulaAccepted = "EulaAccepted"
        case uemEnvironments = "UemEnvironments"
        case activeEnvironmentUuid = "ActiveEnvironmentUuid"
        case storagePath = "StoragePath"
        case databaseAppsEndpoint = "DatabaseAppsEndpoint"
        case databaseRecipesEndpoint = "DatabaseRecipesEndpoint"
        case databaseServerUrl = "DatabaseServerUrl"
        case databaseVersionEndpoint = "DatabaseVersionEndpoint"
        case databaseDownloadEndpoint = "DatabaseDownloadEndpoint"
        case prominentButtonTintHex = "ProminentButtonTintHex"
        case useActiveEnvironmentBrandingTint = "UseActiveEnvironmentBrandingTint"
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
    var matchingRecipeId: String?
    var matchingRecipeCandidates: [RecipeMatchCandidate] = []
    var matchedOn: String?
    var matchedScore: Int?
    #if os(macOS)
    var selectedIcon: NSImage?
    var importedIcnsImage: NSImage?
    var availableIcons: [NSImage] = []
    #endif
    var availableIconPaths: [String] = []
    var selectedIconIndex: Int?
    var selectedIconPath: String?
    var cachedFileSizeBytes: Int64?
    var uploadProgress: UploadProgress? = UploadProgress()
    var metadataProgress: MetadataProgress = MetadataProgress()
    var shouldCloseFlyout: Bool = false
    var parsedMetadata: ParsedMetadata?
    var proposedMetadata: ParsedMetadata?
}

extension ImportedApplication {
    var displayTitle: String {
        if let macApplication, let firstName = macApplication.name.first, !firstName.isEmpty {
            return firstName
        }
        if fileExtension.lowercased() == ".app", fileName.lowercased().hasSuffix(".app") {
            return String(fileName.dropLast(4))
        }
        return fileName
    }

    var displaySubtitle: String {
        if let macApplication, let desc = macApplication.desc, !desc.isEmpty {
            return desc
        }
        return fileName
    }

    var queueSubtitle: String {
        if let macApplication, let desc = macApplication.desc, !desc.isEmpty {
            return desc
        }
        return fullFilePath
    }
}

// MARK: - Model Display Helpers

extension CaskApplication {
    var displayName: String {
        name.first ?? token
    }

    var hasRecipe: Bool {
        matchingRecipeId != nil
    }

    var iconSource: String {
        url
    }

    var fileType: String {
        let lower = url.lowercased()
        if lower.contains(".pkg") { return "pkg" }
        if lower.contains(".dmg") { return "dmg" }
        if lower.contains(".zip") { return "zip" }
        return URL(fileURLWithPath: url).pathExtension
    }
}

// MARK: - Concurrency Bridges

// Allow model types to cross actor boundaries until full Sendable auditing is complete.
extension CaskApplication: @unchecked Sendable {}
extension Recipe: @unchecked Sendable {}
