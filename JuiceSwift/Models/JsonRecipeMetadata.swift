import Foundation

struct JsonRecipeMetadata: Codable {

    enum JSONValue: Codable, Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case object([String: JSONValue])
        case array([JSONValue])
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let b = try? container.decode(Bool.self) {
                self = .bool(b)
            } else if let n = try? container.decode(Double.self) {
                self = .number(n)
            } else if let s = try? container.decode(String.self) {
                self = .string(s)
            } else if let a = try? container.decode([JSONValue].self) {
                self = .array(a)
            } else if let o = try? container.decode([String: JSONValue].self) {
                self = .object(o)
            } else {
                throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let s):
                try container.encode(s)
            case .number(let n):
                try container.encode(n)
            case .bool(let b):
                try container.encode(b)
            case .array(let a):
                try container.encode(a)
            case .object(let o):
                try container.encode(o)
            case .null:
                try container.encodeNil()
            }
        }
    }

    struct MunkiJson: Codable {

        struct AdditionalMakepkginfoOption: Codable {
        }

        struct AdditionalPkginfo: Codable {
            var version: String?
            var name: String?
            var installs: [Install]?
            var minimum_os_version: String?
            var installcheck_script: String?
            var items_to_copy: [ItemsToCopy]?
            var uninstall_method: String?
            var uninstall_script: String?
            var blocking_applications: [String]?
            var installer_type: String?
            var requires: [String]?
            var minosversion: String?
            var icon_name: String?
            var display_name: String?

            enum CodingKeys: String, CodingKey {
                case version = "version"
                case name = "name"
                case installs = "installs"
                case minimum_os_version = "minimum_os_version"
                case installcheck_script = "installcheck_script"
                case items_to_copy = "items_to_copy"
                case uninstall_method = "uninstall_method"
                case uninstall_script = "uninstall_script"
                case blocking_applications = "blocking_applications"
                case installer_type = "installer_type"
                case requires = "requires"
                case minosversion = "minosversion"
                case icon_name = "icon_name"
                case display_name = "display_name"
            }
        }

        struct Arguments: Codable {
            var version: String?
            var should_produce_versioned_name: String?
            var suffix: String?
            var faux_root: String?
            var installs_item_paths: [String]?
            var plist_version_key: String?
            var input_plist_path: String?
            var dmg_path: String?
            var dmg_root: String?
            var warning_message: String?
            var pkg_path: String?
            var repo_subdirectory: String?
            var pkgroot: String?
            var pkgdirs: Pkgdirs?
            var additional_pkginfo: AdditionalPkginfo?
            var destination_path: String?
            var flat_pkg_path: String?
            var pattern: String?
            var purge_destination: String?
            var skip_payload: String?
            var version_comparison_key: String?
            var archive_path: String?
            var derive_minimum_os_version: String?
            var pkg_payload_path: String?
            var replace: String?
            var find: String?
            var input_string: String?
            var quarantined_files_path: String?
            var source_path: String?
            var result_output_var_name: String?
            var re_pattern: String?
            var url: String?
            var source_pkg: String?
            var plist_keys: PlistKeys?
            var info_path: String?
            var app_path: String?
            var munkiimport_pkgname: String?
            var overwrite: String?
            var munkiimport_appname: String?
            var requirement: String?
            var input_path: String?
            var app_name: String?
            var force_munkiimport: String?
            var dmg_megabytes: String?
            var expected_authority_names: [String]?
            var choosen_locale: String?
            var target: String?
            var source: String?
            var asset_regex: String?
            var github_repo: String?
            var include_prereleases: String?
            var additional_makepkginfo_options: [String]?
            var predicate: String?
            var download_dir: String?
            var binary_path: String?
            var index: String?
            var split_on: String?
            var pkginfo_repo_path: String?
            var pkg_ids_set_optional_true: [String]?
            var subprocess_args: String?
            var subprocess_timeout: Int?
            var subprocess_fail_on_error: String?
            var base_pkg_path: String?
            var k2clientconfig_options: String?
            var k2clientconfig_path: String?
            var changes: [Change]?
            var uninstaller_pkg_path: String?
            var source_flatpkg_dir: String?
            var destination_pkg: String?
            var archive_format: String?
            var mode: String?
            var resource_path: String?
            var json_path: String?
            var json_key: String?
            var file_path: String?
            var file_mode: String?
            var file_content: String?
            var force_pkg_build: String?
            var pkg_request: PkgRequest?
            var pkginfo: Pkginfo?

            enum CodingKeys: String, CodingKey {
                case version = "version"
                case should_produce_versioned_name = "should_produce_versioned_name"
                case suffix = "suffix"
                case faux_root = "faux_root"
                case installs_item_paths = "installs_item_paths"
                case plist_version_key = "plist_version_key"
                case input_plist_path = "input_plist_path"
                case dmg_path = "dmg_path"
                case dmg_root = "dmg_root"
                case warning_message = "warning_message"
                case pkg_path = "pkg_path"
                case repo_subdirectory = "repo_subdirectory"
                case pkgroot = "pkgroot"
                case pkgdirs = "pkgdirs"
                case additional_pkginfo = "additional_pkginfo"
                case destination_path = "destination_path"
                case flat_pkg_path = "flat_pkg_path"
                case pattern = "pattern"
                case purge_destination = "purge_destination"
                case skip_payload = "skip_payload"
                case version_comparison_key = "version_comparison_key"
                case archive_path = "archive_path"
                case derive_minimum_os_version = "derive_minimum_os_version"
                case pkg_payload_path = "pkg_payload_path"
                case replace = "replace"
                case find = "find"
                case input_string = "input_string"
                case quarantined_files_path = "quarantined_files_path"
                case source_path = "source_path"
                case result_output_var_name = "result_output_var_name"
                case re_pattern = "re_pattern"
                case url = "url"
                case source_pkg = "source_pkg"
                case plist_keys = "plist_keys"
                case info_path = "info_path"
                case app_path = "app_path"
                case munkiimport_pkgname = "munkiimport_pkgname"
                case overwrite = "overwrite"
                case munkiimport_appname = "munkiimport_appname"
                case requirement = "requirement"
                case input_path = "input_path"
                case app_name = "app_name"
                case force_munkiimport = "force_munkiimport"
                case dmg_megabytes = "dmg_megabytes"
                case expected_authority_names = "expected_authority_names"
                case choosen_locale = "choosen_locale"
                case target = "target"
                case source = "source"
                case asset_regex = "asset_regex"
                case github_repo = "github_repo"
                case include_prereleases = "include_prereleases"
                case additional_makepkginfo_options = "additional_makepkginfo_options"
                case predicate = "predicate"
                case download_dir = "download_dir"
                case binary_path = "binary_path"
                case index = "index"
                case split_on = "split_on"
                case pkginfo_repo_path = "pkginfo_repo_path"
                case pkg_ids_set_optional_true = "pkg_ids_set_optional_true"
                case subprocess_args = "subprocess_args"
                case subprocess_timeout = "subprocess_timeout"
                case subprocess_fail_on_error = "subprocess_fail_on_error"
                case base_pkg_path = "base_pkg_path"
                case k2clientconfig_options = "k2clientconfig_options"
                case k2clientconfig_path = "k2clientconfig_path"
                case changes = "changes"
                case uninstaller_pkg_path = "uninstaller_pkg_path"
                case source_flatpkg_dir = "source_flatpkg_dir"
                case destination_pkg = "destination_pkg"
                case archive_format = "archive_format"
                case mode = "mode"
                case resource_path = "resource_path"
                case json_path = "json_path"
                case json_key = "json_key"
                case file_path = "file_path"
                case file_mode = "file_mode"
                case file_content = "file_content"
                case force_pkg_build = "force_pkg_build"
                case pkg_request = "pkg_request"
                case pkginfo = "pkginfo"
            }
        }

        struct BlockingApplication: Codable {
        }

        struct Catalog: Codable {
        }

        struct Change: Codable {
            var path: String?
            var CFBundleIdentifier: String?
            var version_comparison_key: String?

            enum CodingKeys: String, CodingKey {
                case path = "path"
                case CFBundleIdentifier = "CFBundleIdentifier"
                case version_comparison_key = "version_comparison_key"
            }
        }

        struct ExpectedAuthorityName: Codable {
        }

        struct Input: Codable {
            var DESTINATION_APP_NAME: String?
            var MUNKI_REPO_SUBDIR: String?
            var ICON_NAME: String?
            var pkginfo: Pkginfo?
            var ARBITRARY_SUFFIX: String?
            var APPLE_ID: String?
            var NAME: String?
            var USE_VERSIONED_FILENAME: String?
            var FILENAME_SUFFIX: String?
            var JDK_NAME: String?
            var DESTINATION_PATH: String?
            var OS: String?
            var VERSION: String?
            var PATH: String?
            var DERIVE_MIN_OS: String?
            var SUPPORTED_ARCH: String?
            var MINIMUM_OS_VERSION: String?
            var DOWNLOADURL: String?
            var PRODUCTID: String?
            var FORCE_MUNKIIMPORT: String?
            var MUNKI_CATEGORY: String?
            var PYTHON_MAJOR_VERSION: String?
            var INSTALLER_TYPE: String?
            var DISPLAY_NAME: String?
            var MUNKI_DEVELOPER: String?
            var MUNKI_CATALOGS: String?
            var SNAGIT_LICENCE_KEY: String?
            var LANGUAGE: String?
            var DEFAULT_CATALOG: String?
            var DOWNLOAD_URL: String?
            var REQUIRES: String?
            var MUNKI_NAME: String?
            var ARCH: String?
            var SUPPORTED_OS: String?
            var SOFTWARETYPE: String?
            var SOFTWARETITLE: String?
            var VENDOR: String?
            var MAJOR_VERSION: String?
            var MUNKI_ARCHITECTURE: String?
            var USER_AGENT: String?
            var SEARCH_URL: String?
            var os: String?
            var APP_FILENAME: String?
            var pkginfo_keys_to_copy_from_sparkle_feed: [String]?
            var app_name: String?
            var SEARCH_PATTERN: String?
            var MUNKI_DESCRIPTION: String?
            var VERSION_DESTINATION_PATH: String?
            var SNAGIT_2024_LICENCE_KEY: String?
            var LOCALE: String?
            var unattended_uninstall: String?
            var SPARKLE_FEED_URL: String?
            var MUNKI_DISPLAY_NAME: String?
            var INSTALL_ARCH: String?
            var force_munkiimport: String?
            var DISPLAYNAME: String?
            var DESCRIPTION: String?
            var ID: String?
            var VERSIONTYPE: String?
            var munki_required_update_name: String?
            var OS_VERSION: String?
            var CULTURE_CODE: String?
            var DOWNLOAD_URL_SCHEME: String?
            var BASENAME: String?
            var MUNKITOOLS_CORE_NAME: String?
            var MUNKITOOLS_APP_USAGE_DESCRIPTION: String?
            var MUNKITOOLS_LAUNCHD_DESCRIPTION: String?
            var MUNKI_CATALOG: String?
            var INCLUDE_PRERELEASES: String?
            var MUNKITOOLS_LAUNCHD_DISPLAYNAME: String?
            var MUNKITOOLS_APP_NAME: String?
            var MUNKITOOLS_CORE_DISPLAYNAME: String?
            var MUNKITOOLS_APP_DESCRIPTION: String?
            var MUNKITOOLS_CORE_DESCRIPTION: String?
            var MUNKITOOLS_APP_USAGE_DISPLAYNAME: String?
            var MUNKI_ICON: String?
            var MUNKITOOLS_ADMIN_DESCRIPTION: String?
            var MUNKITOOLS_APP_DISPLAYNAME: String?
            var MUNKITOOLS_APP_USAGE_NAME: String?
            var MUNKITOOLS_ADMIN_NAME: String?
            var MUNKITOOLS_ADMIN_DISPLAYNAME: String?
            var MUNKITOOLS_LAUNCHD_NAME: String?
            var MUNKITOOLS_PYTHON_DISPLAYNAME: String?
            var MUNKITOOLS_PYTHON_DESCRIPTION: String?
            var MUNKITOOLS_PYTHON_NAME: String?
            var MAKEPKGINFO_PKGNAME: String?
            var K2CLIENTCONFIG_OPTIONS: String?
            var pkg_ids_set_optional_true: [String]?
            var FILENAME: String?
            var SELECTION: String?
            var UNINSTALL_PASSWORD: String?
            var pathname: String?
            var PLATFORM_ARCH: String?
            var TERMINAL_APP: String?
            var PRIVATE_TOKEN: String?
            var GITLAB_HOSTNAME: String?
            var JOB_NAME: String?
            var ARTIFACT_PATH: String?
            var URLENCODED_PROJECT: String?
            var VIRUSTOTAL_AUTO_SUBMIT: String?
            var RELEASE: String?
            var MUNKIIMPORT_PKG_NAME: String?
            var RELEASE_CHANNEL: String?
            var PKG_PATH: String?

            enum CodingKeys: String, CodingKey {
                case DESTINATION_APP_NAME = "DESTINATION_APP_NAME"
                case MUNKI_REPO_SUBDIR = "MUNKI_REPO_SUBDIR"
                case ICON_NAME = "ICON_NAME"
                case pkginfo = "pkginfo"
                case ARBITRARY_SUFFIX = "ARBITRARY_SUFFIX"
                case APPLE_ID = "APPLE_ID"
                case NAME = "NAME"
                case USE_VERSIONED_FILENAME = "USE_VERSIONED_FILENAME"
                case FILENAME_SUFFIX = "FILENAME_SUFFIX"
                case JDK_NAME = "JDK_NAME"
                case DESTINATION_PATH = "DESTINATION_PATH"
                case OS = "OS"
                case VERSION = "VERSION"
                case PATH = "PATH"
                case DERIVE_MIN_OS = "DERIVE_MIN_OS"
                case SUPPORTED_ARCH = "SUPPORTED_ARCH"
                case MINIMUM_OS_VERSION = "MINIMUM_OS_VERSION"
                case DOWNLOADURL = "DOWNLOADURL"
                case PRODUCTID = "PRODUCTID"
                case FORCE_MUNKIIMPORT = "FORCE_MUNKIIMPORT"
                case MUNKI_CATEGORY = "MUNKI_CATEGORY"
                case PYTHON_MAJOR_VERSION = "PYTHON_MAJOR_VERSION"
                case INSTALLER_TYPE = "INSTALLER_TYPE"
                case DISPLAY_NAME = "DISPLAY_NAME"
                case MUNKI_DEVELOPER = "MUNKI_DEVELOPER"
                case MUNKI_CATALOGS = "MUNKI_CATALOGS"
                case SNAGIT_LICENCE_KEY = "SNAGIT_LICENCE_KEY"
                case LANGUAGE = "LANGUAGE"
                case DEFAULT_CATALOG = "DEFAULT_CATALOG"
                case DOWNLOAD_URL = "DOWNLOAD_URL"
                case REQUIRES = "REQUIRES"
                case MUNKI_NAME = "MUNKI_NAME"
                case ARCH = "ARCH"
                case SUPPORTED_OS = "SUPPORTED_OS"
                case SOFTWARETYPE = "SOFTWARETYPE"
                case SOFTWARETITLE = "SOFTWARETITLE"
                case VENDOR = "VENDOR"
                case MAJOR_VERSION = "MAJOR_VERSION"
                case MUNKI_ARCHITECTURE = "MUNKI_ARCHITECTURE"
                case USER_AGENT = "USER_AGENT"
                case SEARCH_URL = "SEARCH_URL"
                case os = "os"
                case APP_FILENAME = "APP_FILENAME"
                case pkginfo_keys_to_copy_from_sparkle_feed = "pkginfo_keys_to_copy_from_sparkle_feed"
                case app_name = "app_name"
                case SEARCH_PATTERN = "SEARCH_PATTERN"
                case MUNKI_DESCRIPTION = "MUNKI_DESCRIPTION"
                case VERSION_DESTINATION_PATH = "VERSION_DESTINATION_PATH"
                case SNAGIT_2024_LICENCE_KEY = "SNAGIT_2024_LICENCE_KEY"
                case LOCALE = "LOCALE"
                case unattended_uninstall = "unattended_uninstall"
                case SPARKLE_FEED_URL = "SPARKLE_FEED_URL"
                case MUNKI_DISPLAY_NAME = "MUNKI_DISPLAY_NAME"
                case INSTALL_ARCH = "INSTALL_ARCH"
                case force_munkiimport = "force_munkiimport"
                case DISPLAYNAME = "DISPLAYNAME"
                case DESCRIPTION = "DESCRIPTION"
                case ID = "ID"
                case VERSIONTYPE = "VERSIONTYPE"
                case munki_required_update_name = "munki_required_update_name"
                case OS_VERSION = "OS_VERSION"
                case CULTURE_CODE = "CULTURE_CODE"
                case DOWNLOAD_URL_SCHEME = "DOWNLOAD_URL_SCHEME"
                case BASENAME = "BASENAME"
                case MUNKITOOLS_CORE_NAME = "MUNKITOOLS_CORE_NAME"
                case MUNKITOOLS_APP_USAGE_DESCRIPTION = "MUNKITOOLS_APP_USAGE_DESCRIPTION"
                case MUNKITOOLS_LAUNCHD_DESCRIPTION = "MUNKITOOLS_LAUNCHD_DESCRIPTION"
                case MUNKI_CATALOG = "MUNKI_CATALOG"
                case INCLUDE_PRERELEASES = "INCLUDE_PRERELEASES"
                case MUNKITOOLS_LAUNCHD_DISPLAYNAME = "MUNKITOOLS_LAUNCHD_DISPLAYNAME"
                case MUNKITOOLS_APP_NAME = "MUNKITOOLS_APP_NAME"
                case MUNKITOOLS_CORE_DISPLAYNAME = "MUNKITOOLS_CORE_DISPLAYNAME"
                case MUNKITOOLS_APP_DESCRIPTION = "MUNKITOOLS_APP_DESCRIPTION"
                case MUNKITOOLS_CORE_DESCRIPTION = "MUNKITOOLS_CORE_DESCRIPTION"
                case MUNKITOOLS_APP_USAGE_DISPLAYNAME = "MUNKITOOLS_APP_USAGE_DISPLAYNAME"
                case MUNKI_ICON = "MUNKI_ICON"
                case MUNKITOOLS_ADMIN_DESCRIPTION = "MUNKITOOLS_ADMIN_DESCRIPTION"
                case MUNKITOOLS_APP_DISPLAYNAME = "MUNKITOOLS_APP_DISPLAYNAME"
                case MUNKITOOLS_APP_USAGE_NAME = "MUNKITOOLS_APP_USAGE_NAME"
                case MUNKITOOLS_ADMIN_NAME = "MUNKITOOLS_ADMIN_NAME"
                case MUNKITOOLS_ADMIN_DISPLAYNAME = "MUNKITOOLS_ADMIN_DISPLAYNAME"
                case MUNKITOOLS_LAUNCHD_NAME = "MUNKITOOLS_LAUNCHD_NAME"
                case MUNKITOOLS_PYTHON_DISPLAYNAME = "MUNKITOOLS_PYTHON_DISPLAYNAME"
                case MUNKITOOLS_PYTHON_DESCRIPTION = "MUNKITOOLS_PYTHON_DESCRIPTION"
                case MUNKITOOLS_PYTHON_NAME = "MUNKITOOLS_PYTHON_NAME"
                case MAKEPKGINFO_PKGNAME = "MAKEPKGINFO_PKGNAME"
                case K2CLIENTCONFIG_OPTIONS = "K2CLIENTCONFIG_OPTIONS"
                case pkg_ids_set_optional_true = "pkg_ids_set_optional_true"
                case FILENAME = "FILENAME"
                case SELECTION = "SELECTION"
                case UNINSTALL_PASSWORD = "UNINSTALL_PASSWORD"
                case pathname = "pathname"
                case PLATFORM_ARCH = "PLATFORM_ARCH"
                case TERMINAL_APP = "TERMINAL_APP"
                case PRIVATE_TOKEN = "PRIVATE_TOKEN"
                case GITLAB_HOSTNAME = "GITLAB_HOSTNAME"
                case JOB_NAME = "JOB_NAME"
                case ARTIFACT_PATH = "ARTIFACT_PATH"
                case URLENCODED_PROJECT = "URLENCODED_PROJECT"
                case VIRUSTOTAL_AUTO_SUBMIT = "VIRUSTOTAL_AUTO_SUBMIT"
                case RELEASE = "RELEASE"
                case MUNKIIMPORT_PKG_NAME = "MUNKIIMPORT_PKG_NAME"
                case RELEASE_CHANNEL = "RELEASE_CHANNEL"
                case PKG_PATH = "PKG_PATH"
            }
        }

        struct Install: Codable {
            var path: String?
            var CFBundleShortVersionString: String?
            var version_comparison_key: String?
            var CFBundleIdentifier: String?
            var minosversion: String?
            var type: String?
            var CFBundleVersion: String?
            var md5checksum: String?
            var CFBundleName: String?

            enum CodingKeys: String, CodingKey {
                case path = "path"
                case CFBundleShortVersionString = "CFBundleShortVersionString"
                case version_comparison_key = "version_comparison_key"
                case CFBundleIdentifier = "CFBundleIdentifier"
                case minosversion = "minosversion"
                case type = "type"
                case CFBundleVersion = "CFBundleVersion"
                case md5checksum = "md5checksum"
                case CFBundleName = "CFBundleName"
            }
        }

        struct InstallerChoicesXml: Codable {
            var attributeSetting: String?
            var choiceAttribute: String?
            var choiceIdentifier: String?

            enum CodingKeys: String, CodingKey {
                case attributeSetting = "attributeSetting"
                case choiceAttribute = "choiceAttribute"
                case choiceIdentifier = "choiceIdentifier"
            }
        }

        struct InstallerEnvironment: Codable {
            var LOGNAME: String?

            enum CodingKeys: String, CodingKey {
                case LOGNAME = "LOGNAME"
            }
        }

        struct InstallsItemPath: Codable {
        }

        struct ItemsToCopy: Codable {
            var destination_path: String?
            var source_item: String?
            var mode: String?

            enum CodingKeys: String, CodingKey {
                case destination_path = "destination_path"
                case source_item = "source_item"
                case mode = "mode"
            }
        }

        struct LibraryJavaJavaVirtualMachinesZulu11: Codable {
            var jdk: String?

            enum CodingKeys: String, CodingKey {
                case jdk = "jdk"
            }
        }

        struct Pkgdirs: Codable {
            var Library: String?
            var LibraryJava: String?
            var LibraryJavaJavaVirtualMachines: String?
            var Applications: String?
            var tmp: String?
            var LibraryObjectiveSeeBlockBlock: String?
            var LibraryInternetPlugIns: String?
            var LibraryApplicationSupportAvid: String?
            var LibraryAudio: String?
            var LibraryApplicationSupport: String?
            var LibraryApplicationSupportAvidAudioPlugIns: String?
            var LibraryApplicationSupportAvidAudio: String?
            var LibraryAudioPlugInsVST: String?
            var LibraryAudioPlugIns: String?
            var Applicationsrekordbox6: String?
            var Applicationsrekordbox7: String?
            var LibraryJavaJavaVirtualMachineszulu11: LibraryJavaJavaVirtualMachinesZulu11?

            enum CodingKeys: String, CodingKey {
                case Library = "Library"
                case LibraryJava = "Library/Java"
                case LibraryJavaJavaVirtualMachines = "Library/Java/JavaVirtualMachines"
                case Applications = "Applications"
                case tmp = "tmp"
                case LibraryObjectiveSeeBlockBlock = "Library/Objective-See/BlockBlock"
                case LibraryInternetPlugIns = "Library/Internet Plug-Ins"
                case LibraryApplicationSupportAvid = "Library/Application Support/Avid"
                case LibraryAudio = "Library/Audio"
                case LibraryApplicationSupport = "Library/Application Support"
                case LibraryApplicationSupportAvidAudioPlugIns = "Library/Application Support/Avid/Audio/Plug-Ins"
                case LibraryApplicationSupportAvidAudio = "Library/Application Support/Avid/Audio"
                case LibraryAudioPlugInsVST = "Library/Audio/Plug-Ins/VST"
                case LibraryAudioPlugIns = "Library/Audio/Plug-Ins"
                case Applicationsrekordbox6 = "Applications/rekordbox 6"
                case Applicationsrekordbox7 = "Applications/rekordbox 7"
                case LibraryJavaJavaVirtualMachineszulu11 = "Library/Java/JavaVirtualMachines/zulu-11"
            }
        }

        struct PkgIdsSetOptionalTrue: Codable {
        }

        struct Pkginfo: Codable {
            var category: String?
            var icon_name: String?
            var requires: [String]?
            var minimum_os_version: String?
            var catalogs: [String]?
            var developer: String?
            var unattended_install: String?
            var display_name: String?
            var description: String?
            var name: String?
            var postinstall_script: String?
            var uninstall_method: String?
            var blocking_applications: [String]?
            var uninstall_script: String?
            var unattended_uninstall: String?
            var maximum_os_version: String?
            var postuninstall_script: String?
            var RestartAction: String?
            var preinstall_script: String?
            var items_to_copy: [ItemsToCopy]?
            var uninstallable: String?
            var unattended_unnstall: String?
            var preuninstall_script: String?
            var installer_choices_xml: [InstallerChoicesXml]?
            var installer_environment: InstallerEnvironment?
            var installcheck_script: String?

            enum CodingKeys: String, CodingKey {
                case category = "category"
                case icon_name = "icon_name"
                case requires = "requires"
                case minimum_os_version = "minimum_os_version"
                case catalogs = "catalogs"
                case developer = "developer"
                case unattended_install = "unattended_install"
                case display_name = "display_name"
                case description = "description"
                case name = "name"
                case postinstall_script = "postinstall_script"
                case uninstall_method = "uninstall_method"
                case blocking_applications = "blocking_applications"
                case uninstall_script = "uninstall_script"
                case unattended_uninstall = "unattended_uninstall"
                case maximum_os_version = "maximum_os_version"
                case postuninstall_script = "postuninstall_script"
                case RestartAction = "RestartAction"
                case preinstall_script = "preinstall_script"
                case items_to_copy = "items_to_copy"
                case uninstallable = "uninstallable"
                case unattended_unnstall = "unattended_unnstall"
                case preuninstall_script = "preuninstall_script"
                case installer_choices_xml = "installer_choices_xml"
                case installer_environment = "installer_environment"
                case installcheck_script = "installcheck_script"
            }
        }

        struct PkginfoKeysToCopyFromSparkleFeed: Codable {
        }

        struct PkgRequest: Codable {
            var pkgdir: String?
            var pkgroot: String?
            var pkgname: String?
            var id: String?
            var scripts: String?
            var version: String?
            var options: String?

            enum CodingKeys: String, CodingKey {
                case pkgdir = "pkgdir"
                case pkgroot = "pkgroot"
                case pkgname = "pkgname"
                case id = "id"
                case scripts = "scripts"
                case version = "version"
                case options = "options"
            }
        }

        struct PlistKeys: Codable {
            var LSMinimumSystemVersion: String?
            var CFBundleVersion: String?
            var CFBundleShortVersionString: String?
            var CFBundleIdentifier: String?

            enum CodingKeys: String, CodingKey {
                case LSMinimumSystemVersion = "LSMinimumSystemVersion"
                case CFBundleVersion = "CFBundleVersion"
                case CFBundleShortVersionString = "CFBundleShortVersionString"
                case CFBundleIdentifier = "CFBundleIdentifier"
            }
        }

        struct Process: Codable {
            var Processor: String?
            var Arguments: Arguments?
            var Comment: String?
            var overwrite: String?
            var _note: String?
            var purge_destination: String?

            enum CodingKeys: String, CodingKey {
                case Processor = "Processor"
                case Arguments = "Arguments"
                case Comment = "Comment"
                case overwrite = "overwrite"
                case _note = "_note"
                case purge_destination = "purge_destination"
            }
        }

        struct Require: Codable {
        }

        struct Recipe: Codable {
            var ParentRecipe: String?
            var MinimumVersion: String?
            var Process: [Process]?
            var Input: Input?
            var Copyright: String?
            var Identifier: String?
            var Description: String?
            var Comment: String?
            var comments: String?

            enum CodingKeys: String, CodingKey {
                case ParentRecipe = "ParentRecipe"
                case MinimumVersion = "MinimumVersion"
                case Process = "Process"
                case Input = "Input"
                case Copyright = "Copyright"
                case Identifier = "Identifier"
                case Description = "Description"
                case Comment = "Comment"
                case comments = "comments"
            }
        }
    }

    struct PkgJson: Codable {

        struct Recipe: Codable {
            var ParentRecipe: String?
            var MinimumVersion: String?
            var Process: [Process]?
            var Input: Input?
            var Copyright: String?
            var Identifier: String?
            var Description: String?
            var Comment: String?

            enum CodingKeys: String, CodingKey {
                case ParentRecipe = "ParentRecipe"
                case MinimumVersion = "MinimumVersion"
                case Process = "Process"
                case Input = "Input"
                case Copyright = "Copyright"
                case Identifier = "Identifier"
                case Description = "Description"
                case Comment = "Comment"
            }
        }

        struct Addon: Codable {
            var VendorDisplay: String?
            var VendorId: String?
            var NameId: String?
            var NameDisplay: String?

            enum CodingKeys: String, CodingKey {
                case VendorDisplay = "VendorDisplay"
                case VendorId = "VendorId"
                case NameId = "NameId"
                case NameDisplay = "NameDisplay"
            }
        }

        struct AndroidVersion: Codable {
            var ApiLevel: String?

            enum CodingKeys: String, CodingKey {
                case ApiLevel = "ApiLevel"
            }
        }

        struct Arguments: Codable {
            var archive_format: String?
            var archive_path: String?
            var purge_destination: String?
            var destination_path: String?
            var warning_message: String?
            var pkgdirs: Pkgdirs?
            var pkgroot: String?
            var input_plist_path: String?
            var pkg_payload_path: String?
            var source_path: String?
            var plist_version_key: String?
            var pkg_request: PkgRequest?
            var binary_path: String?
            var dmg_path: String?
            var pattern: String?
            var app_path: String?
            var pkg_path: String?
            var source_pkg: String?
            var version: String?
            var index: String?
            var split_on: String?
            var flat_pkg_path: String?
            var plist_keys: PlistKeys?
            var info_path: String?
            var bundleid: String?
            var target: String?
            var source: String?
            var input_path: String?
            var github_repo: String?
            var predicate: String?
            var url: String?
            var filename: String?
            var re_pattern: String?
            var result_output_var_name: String?
            var Comment: String?
            var overwrite: String?
            var extract_root: String?
            var algorithm: String?
            var pathname: String?
            var checksum: String?
            var requirement: String?
            var file_mode: String?
            var file_content: String?
            var file_path: String?
            var app_xml: String?
            var xml_path: String?
            var elements: [Element]?
            var pkgname: String?
            var serial_number: String?
            var mode: String?
            var resource_path: String?
            var pkgtype: String?
            var template_path: String?
            var infofile: String?
            var faux_root: String?
            var installs_item_paths: [String]?
            var derive_minimum_os_version: String?
            var requirements_path: String?
            var os_version: String?
            var upgrade_pip: String?
            var python_version: String?
            var output_plist_path: String?
            var plist_data: PlistData?
            var source_flatpkg_dir: String?
            var destination_pkg: String?
            var tags: Tags?
            var xml_file: String?
            var properties: Properties?
            var force_pkg_build: String?

            enum CodingKeys: String, CodingKey {
                case archive_format = "archive_format"
                case archive_path = "archive_path"
                case purge_destination = "purge_destination"
                case destination_path = "destination_path"
                case warning_message = "warning_message"
                case pkgdirs = "pkgdirs"
                case pkgroot = "pkgroot"
                case input_plist_path = "input_plist_path"
                case pkg_payload_path = "pkg_payload_path"
                case source_path = "source_path"
                case plist_version_key = "plist_version_key"
                case pkg_request = "pkg_request"
                case binary_path = "binary_path"
                case dmg_path = "dmg_path"
                case pattern = "pattern"
                case app_path = "app_path"
                case pkg_path = "pkg_path"
                case source_pkg = "source_pkg"
                case version = "version"
                case index = "index"
                case split_on = "split_on"
                case flat_pkg_path = "flat_pkg_path"
                case plist_keys = "plist_keys"
                case info_path = "info_path"
                case bundleid = "bundleid"
                case target = "target"
                case source = "source"
                case input_path = "input_path"
                case github_repo = "github_repo"
                case predicate = "predicate"
                case url = "url"
                case filename = "filename"
                case re_pattern = "re_pattern"
                case result_output_var_name = "result_output_var_name"
                case Comment = "Comment"
                case overwrite = "overwrite"
                case extract_root = "extract_root"
                case algorithm = "algorithm"
                case pathname = "pathname"
                case checksum = "checksum"
                case requirement = "requirement"
                case file_mode = "file_mode"
                case file_content = "file_content"
                case file_path = "file_path"
                case app_xml = "app_xml"
                case xml_path = "xml_path"
                case elements = "elements"
                case pkgname = "pkgname"
                case serial_number = "serial_number"
                case mode = "mode"
                case resource_path = "resource_path"
                case pkgtype = "pkgtype"
                case template_path = "template_path"
                case infofile = "infofile"
                case faux_root = "faux_root"
                case installs_item_paths = "installs_item_paths"
                case derive_minimum_os_version = "derive_minimum_os_version"
                case requirements_path = "requirements_path"
                case os_version = "os_version"
                case upgrade_pip = "upgrade_pip"
                case python_version = "python_version"
                case output_plist_path = "output_plist_path"
                case plist_data = "plist_data"
                case source_flatpkg_dir = "source_flatpkg_dir"
                case destination_pkg = "destination_pkg"
                case tags = "tags"
                case xml_file = "xml_file"
                case properties = "properties"
                case force_pkg_build = "force_pkg_build"
            }
        }

        struct CFBundleDocumentType: Codable {
            var CFBundleTypeName: String?
            var CFBundleTypeRole: String?
            var CFBundleTypeIconFile: String?

            enum CodingKeys: String, CodingKey {
                case CFBundleTypeName = "CFBundleTypeName"
                case CFBundleTypeRole = "CFBundleTypeRole"
                case CFBundleTypeIconFile = "CFBundleTypeIconFile"
            }
        }

        struct CFBundleTypeExtension: Codable {
        }

        struct CFBundleTypeMIMEType: Codable {
        }

        struct Chown: Codable {
            var group: String?
            var path: String?
            var user: String?
            var mode: String?

            enum CodingKeys: String, CodingKey {
                case group = "group"
                case path = "path"
                case user = "user"
                case mode = "mode"
            }
        }

        struct Element: Codable {
            var xpath: String?
            var text: String?

            enum CodingKeys: String, CodingKey {
                case xpath = "xpath"
                case text = "text"
            }
        }

        struct ExpectedAuthorityName: Codable {
        }

        struct Input: Codable {
            var NAME: String?
            var DEPLOY_INI_FILE: String?
            var PATH: String?
            var BUNDLE_ID: String?
            var LANGUAGE: String?
            var APP_FILENAME: String?
            var PKGID: String?
            var INSTALL_SCRIPT: String?
            var PREINSTALL_SCRIPT_PATH: String?
            var POSTINSTALL_SCRIPT_PATH: String?
            var SEARCH_URL: String?
            var USER_AGENT: String?
            var BUNDLEID: String?
            var SUPPORTED_ARCH: String?
            var DOWNLOAD_URL: String?
            var PKG_ID: String?
            var VENDOR: String?
            var SOFTWARETITLE: String?
            var SOFTWARETITLE1: String?
            var PACKAGENAME: String?
            var SOFTWARETITLE2: String?
            var OSVSERSIONNAME: String?
            var OSFAMILYNAME: String?
            var OSVSERSIONNUMBER: String?
            var VERSIONTYPE: String?
            var SOFTWARETYPE: String?
            var PROCESSORTYPE: String?
            var MAJORVERSION: String?
            var DISTRIBUTION: String?
            var LAUNCHTRAY: String?
            var MODE: String?
            var USERDOMAIN: String?
            var REINSTALLDRIVER: String?
            var POLICYTOKEN: String?
            var STRICTENFORCEMENT: String?
            var UNATTENDEDMODEUI: String?
            var CLOUDNAME: String?
            var HIDEAPPUIONLAUNCH: String?
            var DEVICETOKEN: String?
            var SOFTWARETITLE3: String?
            var SOFTWARETITLE4: String?
            var NAMEWITHOUTSPACES: String?
            var APPNAME: String?
            var VERSION_SPLIT_ON: String?
            var NTCUSTOMERKEYNAME: String?
            var NTPROXYPORT: String?
            var NTSTRINGTAG: String?
            var NTTCPPORT: String?
            var NTPROXYPACADDRESS: String?
            var NTCUSTOMERKEYDATA: String?
            var NTPROXYADDRESS: String?
            var NTUDPPORT: String?
            var NTDATAOVERTCP: String?
            var NTREMOTEACTIONS: String?
            var NTASSIGNMENT: String?
            var NTENGAGE: String?
            var NTSERVERADDRESS: String?
            var ARCHITECTURE: String?
            var BUILD: String?
            var SOFTWARETITLE5: String?
            var VERSION: String?
            var CULTURE_CODE: String?
            var DOWNLOAD_URL_SCHEME: String?
            var OS_VERSION: String?
            var MAJOR_VERSION: String?
            var URL: String?
            var PYTHON_VERSION: String?
            var BRANCH: String?
            var REQUIREMENTS_FILENAME: String?
            var FILENAME: String?
            var SELECTION: String?
            var Comment: String?
            var ARCH: String?
            var SERIAL_NUMBER: String?
            var APP_PAYLOAD: String?
            var CHOICE_CHANGES_XML: String?
            var APP_RELPATH: String?
            var pkg_path: String?
            var TERMINAL_APP: String?
            var PRIVATE_TOKEN: String?
            var JOB_NAME: String?
            var GITLAB_HOSTNAME: String?
            var ARTIFACT_PATH: String?
            var URLENCODED_PROJECT: String?
            var VIRUSTOTAL_AUTO_SUBMIT: String?
            var RELEASE_TYPE: String?
            var DERIVE_MIN_OS: String?
            var RELEASE: String?
            var RELEASE_CHANNEL: String?
            var BEAT_NAME: String?

            enum CodingKeys: String, CodingKey {
                case NAME = "NAME"
                case DEPLOY_INI_FILE = "DEPLOY_INI_FILE"
                case PATH = "PATH"
                case BUNDLE_ID = "BUNDLE_ID"
                case LANGUAGE = "LANGUAGE"
                case APP_FILENAME = "APP_FILENAME"
                case PKGID = "PKGID"
                case INSTALL_SCRIPT = "INSTALL_SCRIPT"
                case PREINSTALL_SCRIPT_PATH = "PREINSTALL_SCRIPT_PATH"
                case POSTINSTALL_SCRIPT_PATH = "POSTINSTALL_SCRIPT_PATH"
                case SEARCH_URL = "SEARCH_URL"
                case USER_AGENT = "USER_AGENT"
                case BUNDLEID = "BUNDLEID"
                case SUPPORTED_ARCH = "SUPPORTED_ARCH"
                case DOWNLOAD_URL = "DOWNLOAD_URL"
                case PKG_ID = "PKG_ID"
                case VENDOR = "VENDOR"
                case SOFTWARETITLE = "SOFTWARETITLE"
                case SOFTWARETITLE1 = "SOFTWARETITLE1"
                case PACKAGENAME = "PACKAGENAME"
                case SOFTWARETITLE2 = "SOFTWARETITLE2"
                case OSVSERSIONNAME = "OSVSERSIONNAME"
                case OSFAMILYNAME = "OSFAMILYNAME"
                case OSVSERSIONNUMBER = "OSVSERSIONNUMBER"
                case VERSIONTYPE = "VERSIONTYPE"
                case SOFTWARETYPE = "SOFTWARETYPE"
                case PROCESSORTYPE = "PROCESSORTYPE"
                case MAJORVERSION = "MAJORVERSION"
                case DISTRIBUTION = "DISTRIBUTION"
                case LAUNCHTRAY = "LAUNCHTRAY"
                case MODE = "MODE"
                case USERDOMAIN = "USERDOMAIN"
                case REINSTALLDRIVER = "REINSTALLDRIVER"
                case POLICYTOKEN = "POLICYTOKEN"
                case STRICTENFORCEMENT = "STRICTENFORCEMENT"
                case UNATTENDEDMODEUI = "UNATTENDEDMODEUI"
                case CLOUDNAME = "CLOUDNAME"
                case HIDEAPPUIONLAUNCH = "HIDEAPPUIONLAUNCH"
                case DEVICETOKEN = "DEVICETOKEN"
                case SOFTWARETITLE3 = "SOFTWARETITLE3"
                case SOFTWARETITLE4 = "SOFTWARETITLE4"
                case NAMEWITHOUTSPACES = "NAMEWITHOUTSPACES"
                case APPNAME = "APPNAME"
                case VERSION_SPLIT_ON = "VERSION_SPLIT_ON"
                case NTCUSTOMERKEYNAME = "NTCUSTOMERKEYNAME"
                case NTPROXYPORT = "NTPROXYPORT"
                case NTSTRINGTAG = "NTSTRINGTAG"
                case NTTCPPORT = "NTTCPPORT"
                case NTPROXYPACADDRESS = "NTPROXYPACADDRESS"
                case NTCUSTOMERKEYDATA = "NTCUSTOMERKEYDATA"
                case NTPROXYADDRESS = "NTPROXYADDRESS"
                case NTUDPPORT = "NTUDPPORT"
                case NTDATAOVERTCP = "NTDATAOVERTCP"
                case NTREMOTEACTIONS = "NTREMOTEACTIONS"
                case NTASSIGNMENT = "NTASSIGNMENT"
                case NTENGAGE = "NTENGAGE"
                case NTSERVERADDRESS = "NTSERVERADDRESS"
                case ARCHITECTURE = "ARCHITECTURE"
                case BUILD = "BUILD"
                case SOFTWARETITLE5 = "SOFTWARETITLE5"
                case VERSION = "VERSION"
                case CULTURE_CODE = "CULTURE_CODE"
                case DOWNLOAD_URL_SCHEME = "DOWNLOAD_URL_SCHEME"
                case OS_VERSION = "OS_VERSION"
                case MAJOR_VERSION = "MAJOR_VERSION"
                case URL = "URL"
                case PYTHON_VERSION = "PYTHON_VERSION"
                case BRANCH = "BRANCH"
                case REQUIREMENTS_FILENAME = "REQUIREMENTS_FILENAME"
                case FILENAME = "FILENAME"
                case SELECTION = "SELECTION"
                case Comment = "Comment"
                case ARCH = "ARCH"
                case SERIAL_NUMBER = "SERIAL_NUMBER"
                case APP_PAYLOAD = "APP_PAYLOAD"
                case CHOICE_CHANGES_XML = "CHOICE_CHANGES_XML"
                case APP_RELPATH = "APP_RELPATH"
                case pkg_path = "pkg_path"
                case TERMINAL_APP = "TERMINAL_APP"
                case PRIVATE_TOKEN = "PRIVATE_TOKEN"
                case JOB_NAME = "JOB_NAME"
                case GITLAB_HOSTNAME = "GITLAB_HOSTNAME"
                case ARTIFACT_PATH = "ARTIFACT_PATH"
                case URLENCODED_PROJECT = "URLENCODED_PROJECT"
                case VIRUSTOTAL_AUTO_SUBMIT = "VIRUSTOTAL_AUTO_SUBMIT"
                case RELEASE_TYPE = "RELEASE_TYPE"
                case DERIVE_MIN_OS = "DERIVE_MIN_OS"
                case RELEASE = "RELEASE"
                case RELEASE_CHANNEL = "RELEASE_CHANNEL"
                case BEAT_NAME = "BEAT_NAME"
            }
        }

        struct InstallsItemPath: Codable {
        }

        struct LibraryApplicationSupportAdobeCommonPlugIns7: Codable {
            var _0MediaCoreGoPro: String?
            var _0: String?
            var _0MediaCore: String?

            enum CodingKeys: String, CodingKey {
                case _0MediaCoreGoPro = "0/MediaCore/GoPro"
                case _0 = "0"
                case _0MediaCore = "0/MediaCore"
            }
        }

        struct LibraryApplicationSupportSeapineTestTrackIntegration: Codable {
            var framework: String?

            enum CodingKeys: String, CodingKey {
                case framework = "framework"
            }
        }

        struct LibraryInternetPlugInsJavaAppletPlugin: Codable {
            var plugin: String?

            enum CodingKeys: String, CodingKey {
                case plugin = "plugin"
            }
        }

        struct Pkg: Codable {
            var LicenseRef: String?
            var Revision: String?
            var SourceUrl: String?
            var Desc: String?
            var License: String?

            enum CodingKeys: String, CodingKey {
                case LicenseRef = "LicenseRef"
                case Revision = "Revision"
                case SourceUrl = "SourceUrl"
                case Desc = "Desc"
                case License = "License"
            }
        }

        struct Pkgdirs: Codable {
            var Applications: String?
            var LibraryApplicationSupportAvid: String?
            var LibraryAudio: String?
            var LibraryApplicationSupport: String?
            var LibraryApplicationSupportAvidAudioPlugIns: String?
            var Library: String?
            var LibraryApplicationSupportAvidAudio: String?
            var LibraryAudioPlugInsVST: String?
            var LibraryAudioPlugIns: String?
            var privatetmpLinkOptimizer: String?
            var LibraryAdobeLicenseDecoder: String?
            var ScreenSavers: String?
            var Scripts: String?
            var LibraryJava: String?
            var LibraryJavaJavaVirtualMachines: String?
            var ApplicationsAdobeFlashPlayerAddInsairappinstaller: String?
            var ApplicationsUtilities: String?
            var ApplicationsAdobeFlashPlayer: String?
            var ApplicationsAdobeFlashPlayerAddIns: String?
            var ApplicationsAdobe: String?
            var LibraryFrameworks: String?
            var LibraryScreenSavers: String?
            var LibraryColorPickers: String?
            var usr: String?
            var usrlocal: String?
            var usrlocalbin: String?
            var LibraryProfiles: String?
            var opt: String?
            var rootprivatetmp: String?
            var scripts: String?
            var usrlocalshareman: String?
            var usrlocalshare: String?
            var usrlocalsharemanman1: String?
            var LibraryInternetPlugIns: String?
            var LibraryInternetPlugInsJavaAppletPlugin: LibraryInternetPlugInsJavaAppletPlugin?
            var privatetmp: String?
            var privatetmpTraffic: String?
            var LibraryApplicationSupportAdobe: String?
            var LibraryApplicationSupportAdobeCommonPlugins7: LibraryApplicationSupportAdobeCommonPlugIns7?
            var LibraryApplicationSupportAdobeCommonPlugins: String?
            var LibraryApplicationSupportAdobeCommon: String?
            var LibraryAutoPkg: String?
            var LibraryLaunchDaemons: String?
            var LibraryAutoPkgautopkgserver: String?
            var LibraryAutoPkgautopkglib: String?
            var LibraryApplicationSupportSeapine: String?
            var LibraryApplicationSupportSeapineTestTrackIntegration: LibraryApplicationSupportSeapineTestTrackIntegration?
            var privateetc: String?
            var ApplicationsHelixALM: String?
            var usrlocalseapine: String?
            var usrlocalseapinett: String?
            var LibraryAudioPlugInsHAL: String?
            var usrlocalautopkg: String?
            var LibraryAutoPkgautopkgcmd: String?
            var LibraryAutoPkgPython3: String?

            enum CodingKeys: String, CodingKey {
                case Applications = "Applications"
                case LibraryApplicationSupportAvid = "Library/Application Support/Avid"
                case LibraryAudio = "Library/Audio"
                case LibraryApplicationSupport = "Library/Application Support"
                case LibraryApplicationSupportAvidAudioPlugIns = "Library/Application Support/Avid/Audio/Plug-Ins"
                case Library = "Library"
                case LibraryApplicationSupportAvidAudio = "Library/Application Support/Avid/Audio"
                case LibraryAudioPlugInsVST = "Library/Audio/Plug-Ins/VST"
                case LibraryAudioPlugIns = "Library/Audio/Plug-Ins"
                case privatetmpLinkOptimizer = "private/tmp/LinkOptimizer"
                case LibraryAdobeLicenseDecoder = "Library/Adobe License Decoder"
                case ScreenSavers = "Screen Savers"
                case Scripts = "Scripts"
                case LibraryJava = "Library/Java"
                case LibraryJavaJavaVirtualMachines = "Library/Java/JavaVirtualMachines"
                case ApplicationsAdobeFlashPlayerAddInsairappinstaller = "Applications/Adobe/Flash Player/AddIns/airappinstaller"
                case ApplicationsUtilities = "Applications/Utilities"
                case ApplicationsAdobeFlashPlayer = "Applications/Adobe/Flash Player"
                case ApplicationsAdobeFlashPlayerAddIns = "Applications/Adobe/Flash Player/AddIns"
                case ApplicationsAdobe = "Applications/Adobe"
                case LibraryFrameworks = "Library/Frameworks"
                case LibraryScreenSavers = "Library/Screen Savers"
                case LibraryColorPickers = "Library/ColorPickers"
                case usr = "usr"
                case usrlocal = "usr/local"
                case usrlocalbin = "usr/local/bin"
                case LibraryProfiles = "Library/Profiles"
                case opt = "opt"
                case rootprivatetmp = "root/private/tmp"
                case scripts = "scripts"
                case usrlocalshareman = "usr/local/share/man"
                case usrlocalshare = "usr/local/share/"
                case usrlocalsharemanman1 = "usr/local/share/man/man1"
                case LibraryInternetPlugIns = "Library/Internet Plug-Ins"
                case LibraryInternetPlugInsJavaAppletPlugin = "Library/Internet Plug-Ins/JavaAppletPlugin"
                case privatetmp = "private/tmp"
                case privatetmpTraffic = "private/tmp/Traffic"
                case LibraryApplicationSupportAdobe = "Library/Application Support/Adobe"
                case LibraryApplicationSupportAdobeCommonPlugins7 = "Library/Application Support/Adobe/Common/Plug-ins/7"
                case LibraryApplicationSupportAdobeCommonPlugins = "Library/Application Support/Adobe/Common/Plug-ins"
                case LibraryApplicationSupportAdobeCommon = "Library/Application Support/Adobe/Common"
                case LibraryAutoPkg = "Library/AutoPkg"
                case LibraryLaunchDaemons = "Library/LaunchDaemons"
                case LibraryAutoPkgautopkgserver = "Library/AutoPkg/autopkgserver"
                case LibraryAutoPkgautopkglib = "Library/AutoPkg/autopkglib"
                case LibraryApplicationSupportSeapine = "Library/Application Support/Seapine"
                case LibraryApplicationSupportSeapineTestTrackIntegration = "Library/Application Support/Seapine/TestTrackIntegration"
                case privateetc = "private/etc"
                case ApplicationsHelixALM = "Applications/HelixALM"
                case usrlocalseapine = "usr/local/seapine"
                case usrlocalseapinett = "usr/local/seapine/tt"
                case LibraryAudioPlugInsHAL = "Library/Audio/Plug-Ins/HAL"
                case usrlocalautopkg = "usr/local/autopkg"
                case LibraryAutoPkgautopkgcmd = "Library/AutoPkg/autopkgcmd"
                case LibraryAutoPkgPython3 = "Library/AutoPkg/Python3"
            }
        }

        struct PkgRequest: Codable {
            var version: String?
            var chown: [Chown]?
            var id: String?
            var options: String?
            var pkgname: String?
            var pkgroot: String?
            var scripts: String?
            var pkgdir: String?
            var pkgdirs: String?
            var pkgtype: String?
            var resources: String?
            var infofile: String?

            enum CodingKeys: String, CodingKey {
                case version = "version"
                case chown = "chown"
                case id = "id"
                case options = "options"
                case pkgname = "pkgname"
                case pkgroot = "pkgroot"
                case scripts = "scripts"
                case pkgdir = "pkgdir"
                case pkgdirs = "pkgdirs"
                case pkgtype = "pkgtype"
                case resources = "resources"
                case infofile = "infofile"
            }
        }

        struct PlistData: Codable {
            var CFBundleDocumentTypes: [CFBundleDocumentType]?

            enum CodingKeys: String, CodingKey {
                case CFBundleDocumentTypes = "CFBundleDocumentTypes"
            }
        }

        struct PlistKeys: Codable {
            var CFBundleShortVersionString: String?
            var CFBundleIdentifier: String?
            var CFBundleVersion: String?
            var AlphanumericVersionString: String?
            var LSMinimumSystemVersion: String?
            var CFBundleName: String?

            enum CodingKeys: String, CodingKey {
                case CFBundleShortVersionString = "CFBundleShortVersionString"
                case CFBundleIdentifier = "CFBundleIdentifier"
                case CFBundleVersion = "CFBundleVersion"
                case AlphanumericVersionString = "AlphanumericVersionString"
                case LSMinimumSystemVersion = "LSMinimumSystemVersion"
                case CFBundleName = "CFBundleName"
            }
        }

        struct Process: Codable {
            var Processor: String?
            var Arguments: Arguments?
            var Comment: String?
            var _Comment: String?

            enum CodingKeys: String, CodingKey {
                case Processor = "Processor"
                case Arguments = "Arguments"
                case Comment = "Comment"
                case _Comment = "_Comment"
            }
        }

        struct Properties: Codable {
            var Pkg: Pkg?
            var Addon: Addon?
            var AndroidVersion: AndroidVersion?

            enum CodingKeys: String, CodingKey {
                case Pkg = "Pkg"
                case Addon = "Addon"
                case AndroidVersion = "AndroidVersion"
            }
        }

        struct Tags: Codable {
            var revision: String?
            var namedisplay: String?
            var nameid: String?
            var useslicense: String?
            var vendorid: String?
            var license: String?
            var description: String?
            var vendordisplay: String?
            var apilevel: String?

            enum CodingKeys: String, CodingKey {
                case revision = "revision"
                case namedisplay = "name-display"
                case nameid = "name-id"
                case useslicense = "uses-license"
                case vendorid = "vendor-id"
                case license = "license"
                case description = "description"
                case vendordisplay = "vendor-display"
                case apilevel = "api-level"
            }
        }
    }

    struct DownloadJson: Codable {

        struct Recipe: Codable {
            var NormalizedURL: String?
            var Identifier: String?
            var Description: String?
            var MinimumVersion: String?
            var Process: [Process]?
            var Input: Input?
            var Copyright: String?
            var Comment: String?
            var comment: String?
            var ParentRecipe: String?
            var SupportedPlatforms: [String]?

            enum CodingKeys: String, CodingKey {
                case NormalizedURL = "NormalizedURL"
                case Identifier = "Identifier"
                case Description = "Description"
                case MinimumVersion = "MinimumVersion"
                case Process = "Process"
                case Input = "Input"
                case Copyright = "Copyright"
                case Comment = "Comment"
                case comment = "comment"
                case ParentRecipe = "ParentRecipe"
                case SupportedPlatforms = "SupportedPlatforms"
            }
        }

        struct AdditionalArgument: Codable {
        }

        struct AppcastQueryPairs: Codable {
            var appName: String?
            var appVersion: String?

            enum CodingKeys: String, CodingKey {
                case appName = "appName"
                case appVersion = "appVersion"
            }
        }

        struct AppcastRequestHeaders: Codable {
            var UserAgent: String?
            var useragent: String?

            enum CodingKeys: String, CodingKey {
                case UserAgent = "User-Agent"
                case useragent = "user-agent"
            }
        }

        struct Arguments: Codable {
            var password: String?
            var password_file: String?
            var apple_id: String?
            var appID_key: String?
            var username: String?
            var warning_message: String?
            var url: String?
            var filename: String?
            var re_pattern: String?
            var release: String?
            var jvm_type: String?
            var jdk_type: String?
            var jdk_version: String?
            var binary_type: String?
            var curl_opts: [String]?
            var appcast_url: String?
            var github_repo: String?
            var include_prereleases: String?
            var result_output_var_name: String?
            var asset_regex: String?
            var urlencode_path_component: String?
            var product_name: String?
            var registration_info: RegistrationInfo?
            var product_name_pattern: String?
            var SOURCEFORGE_FILE_PATTERN: String?
            var SOURCEFORGE_PROJECT_NAME: String?
            var comment: String?
            var download_dir: String?
            var request_headers: RequestHeaders?
            var re_flags: [String]?
            var appcast_request_headers: AppcastRequestHeaders?
            var CHECK_FILESIZE_ONLY: String?
            var latest_only: String?
            var base_url: String?
            var predicate: String?
            var requestheaders: RequestHeaders?
            var product: String?
            var channel: String?
            var locale_id: String?
            var version: String?
            var locale: String?
            var platform: String?
            var os_version: String?
            var major_version: String?
            var target_os: String?
            var requirement: JSONValue?
            var input_path: String?
            var alternate_xmlns_url: String?
            var strict_verification: String?
            var appcast_query_pairs: AppcastQueryPairs?
            var sort_by_highest_tag_names: String?
            var architecture: String?
            var SOURCEFORGE_PROJECT_ID: String?
            var replace: String?
            var input_string: String?
            var find: String?
            var os: String?
            var arch: String?
            var project_name: String?
            var release_type: String?
            var arch_name: String?
            var login_data: String?
            var expected_authority_names: [String]?
            var archive_path: String?
            var destination_path: String?
            var purge_destination: String?
            var plist_keys: PlistKeys?
            var info_path: String?
            var name: String?
            var archive_format: String?
            var culture_code: String?
            var munki_update_name: String?
            var prefetch_filename: String?
            var pattern: String?
            var flat_pkg_path: String?
            var product_code: String?
            var pkgroot: String?
            var plist_version_key: String?
            var input_plist_path: String?
            var dont_skip: String?
            var output_filepath: String?
            var xml_file: String?
            var pkgdirs: Pkgdirs?
            var pkg_path: String?
            var source_pkg: String?
            var pkg_payload_path: String?
            var index: String?
            var split_on: String?
            var additional_arguments: [String]?
            var dmg_path: String?
            var Comment: String?
            var tags: Tags?
            var source_path: String?
            var overwrite: String?
            var checksum: String?
            var algorithm: String?
            var requirements: String?
            var xml_path: String?
            var elements: [Element]?
            var target: String?
            var source: String?
            var output_plist_path: String?
            var plist_data: PlistData?

            enum CodingKeys: String, CodingKey {
                case password = "password"
                case password_file = "password_file"
                case apple_id = "apple_id"
                case appID_key = "appID_key"
                case username = "username"
                case warning_message = "warning_message"
                case url = "url"
                case filename = "filename"
                case re_pattern = "re_pattern"
                case release = "release"
                case jvm_type = "jvm_type"
                case jdk_type = "jdk_type"
                case jdk_version = "jdk_version"
                case binary_type = "binary_type"
                case curl_opts = "curl_opts"
                case appcast_url = "appcast_url"
                case github_repo = "github_repo"
                case include_prereleases = "include_prereleases"
                case result_output_var_name = "result_output_var_name"
                case asset_regex = "asset_regex"
                case urlencode_path_component = "urlencode_path_component"
                case product_name = "product_name"
                case registration_info = "registration_info"
                case product_name_pattern = "product_name_pattern"
                case SOURCEFORGE_FILE_PATTERN = "SOURCEFORGE_FILE_PATTERN"
                case SOURCEFORGE_PROJECT_NAME = "SOURCEFORGE_PROJECT_NAME"
                case comment = "comment"
                case download_dir = "download_dir"
                case request_headers = "request_headers"
                case re_flags = "re_flags"
                case appcast_request_headers = "appcast_request_headers"
                case CHECK_FILESIZE_ONLY = "CHECK_FILESIZE_ONLY"
                case latest_only = "latest_only"
                case base_url = "base_url"
                case predicate = "predicate"
                case requestheaders = "request-headers"
                case product = "product"
                case channel = "channel"
                case locale_id = "locale_id"
                case version = "version"
                case locale = "locale"
                case platform = "platform"
                case os_version = "os_version"
                case major_version = "major_version"
                case target_os = "target_os"
                case requirement = "requirement"
                case input_path = "input_path"
                case alternate_xmlns_url = "alternate_xmlns_url"
                case strict_verification = "strict_verification"
                case appcast_query_pairs = "appcast_query_pairs"
                case sort_by_highest_tag_names = "sort_by_highest_tag_names"
                case architecture = "architecture"
                case SOURCEFORGE_PROJECT_ID = "SOURCEFORGE_PROJECT_ID"
                case replace = "replace"
                case input_string = "input_string"
                case find = "find"
                case os = "os"
                case arch = "arch"
                case project_name = "project_name"
                case release_type = "release_type"
                case arch_name = "arch_name"
                case login_data = "login_data"
                case expected_authority_names = "expected_authority_names"
                case archive_path = "archive_path"
                case destination_path = "destination_path"
                case purge_destination = "purge_destination"
                case plist_keys = "plist_keys"
                case info_path = "info_path"
                case name = "name"
                case archive_format = "archive_format"
                case culture_code = "culture_code"
                case munki_update_name = "munki_update_name"
                case prefetch_filename = "prefetch_filename"
                case pattern = "pattern"
                case flat_pkg_path = "flat_pkg_path"
                case product_code = "product_code"
                case pkgroot = "pkgroot"
                case plist_version_key = "plist_version_key"
                case input_plist_path = "input_plist_path"
                case dont_skip = "dont_skip"
                case output_filepath = "output_filepath"
                case xml_file = "xml_file"
                case pkgdirs = "pkgdirs"
                case pkg_path = "pkg_path"
                case source_pkg = "source_pkg"
                case pkg_payload_path = "pkg_payload_path"
                case index = "index"
                case split_on = "split_on"
                case additional_arguments = "additional_arguments"
                case dmg_path = "dmg_path"
                case Comment = "Comment"
                case tags = "tags"
                case source_path = "source_path"
                case overwrite = "overwrite"
                case checksum = "checksum"
                case algorithm = "algorithm"
                case requirements = "requirements"
                case xml_path = "xml_path"
                case elements = "elements"
                case target = "target"
                case source = "source"
                case output_plist_path = "output_plist_path"
                case plist_data = "plist_data"
            }
        }

        struct CurlOpt: Codable {
        }

        struct Element: Codable {
            var xpath: String?
            var text: String?

            enum CodingKeys: String, CodingKey {
                case xpath = "xpath"
                case text = "text"
            }
        }

        struct ExpectedAuthorityName: Codable {
        }

        struct Input: Codable {
            var NOSKIP: String?
            var VERSION_EMIT_PATH: String?
            var PATTERN: String?
            var APPLE_ID: String?
            var PASSWORD_FILE: String?
            var PASSWORD: String?
            var BETA: String?
            var NAME: String?
            var AC_USERNAME: String?
            var AC_PASSWORD: String?
            var OS: String?
            var CHEF_VERSION: String?
            var URL: String?
            var VERSION: String?
            var RELEASE: String?
            var JVM_TYPE: String?
            var JDK_TYPE: String?
            var JDK_VERSION: String?
            var BINARY_TYPE: String?
            var SPARKLE_FEED_URL: String?
            var USER_AGENT: String?
            var PRERELEASE: String?
            var DOWNLOAD_ARCH: String?
            var ARCH: String?
            var DOWNLOAD_URL: String?
            var LOCALE: String?
            var OS_TYPE: String?
            var baseurl: String?
            var REG_FIRSTNAME: String?
            var REG_EMAIL: String?
            var REG_LASTNAME: String?
            var PRODUCT_NAME_PATTERN: String?
            var REG_PHONE: String?
            var REG_CITY: String?
            var REG_STATE: String?
            var REG_COUNTRY: String?
            var SEARCH_PATTERN: String?
            var SEARCH_URL: String?
            var ARCH_TYPE: String?
            var HORIZON_MAJOR_VERSION: String?
            var MAJOR_VERSION: String?
            var ARCHITECTURE: String?
            var DOWNLOAD_TYPE: String?
            var DOWNLOAD_KEY: String?
            var DOWNLOAD_TITLE: String?
            var DOWNLOAD_ARCHITECTURE: String?
            var SUPPORTED_ARCH: String?
            var include_prereleases: String?
            var BASE_URL: String?
            var POLYCOMRPDESKTOP_DMG_REPATTERN: String?
            var CHECK_PAGE_URL: String?
            var url: String?
            var RELEASE_CHANNEL1: String?
            var RELEASE_CHANNEL2: String?
            var LATESTONLY: String?
            var DOWNLOAD_CHECK_URL: String?
            var PRODUCTID: String?
            var DOWNLOADURL: String?
            var DEVELOPER: String?
            var VENDOR: String?
            var SOFTWARETITLE: String?
            var DOWNLOAD_UUID: String?
            var DOWNLOAD_FILENAME: String?
            var SOFTWARETITLE1: String?
            var SOFTWARETITLE2: String?
            var OSFAMILYNAME: String?
            var OSVSERSIONNAME: String?
            var OSVSERSIONNUMBER: String?
            var SOFTWARETYPE: String?
            var DISTRIBUTION: String?
            var PACKAGER: String?
            var SOFTWARETITLE3: String?
            var SOFTWARETITLE4: String?
            var DOWNLOAD_USERAGENT: String?
            var DOWNLOAD_BASE_URL: String?
            var APP_FILENAME: String?
            var CONTENT_TYPE_HEADER: String?
            var DATA_BINARY_CONTENT: String?
            var ID: String?
            var DOWNLOAD_URL_BASE: String?
            var INTEL_SEARCH_PATTERN: String?
            var APPLE_SILICON_SEARCH_PATTERN: String?
            var APPLE_SILICON_ARCHITECTURE: String?
            var INTEL_ARCHITECTURE: String?
            var NAMEWITHOUTSPACES: String?
            var BUILD: String?
            var SOFTWARETITLE5: String?
            var LOCALE_ID: String?
            var CHANNEL: String?
            var PRODUCT: String?
            var OS_VERSION: String?
            var CULTURE_CODE: String?
            var DOWNLOAD_URL_SCHEME: String?
            var PLATFORM: String?
            var LATEST_RELEASE: String?
            var TARGET_OS: String?
            var INCLUDE_PRERELEASES: String?
            var BRANCH: String?
            var APPCAST_URL: String?
            var REVISION: String?
            var INCL_PRERELEASES: String?
            var PLATFORM_ARCH: String?
            var FILENAME: String?
            var ECLIPSE_CODE: String?
            var GITHUB_REPO: String?
            var majorRelease: String?
            var minorRelease: String?
            var GITLAB_HOSTNAME: String?
            var JOB_NAME: String?
            var PRIVATE_TOKEN: String?
            var URLENCODED_PROJECT: String?
            var VIRUSTOTAL_AUTO_SUBMIT: String?
            var RELEASE_TYPE: String?
            var BEAT_NAME: String?
            var OPTIONAL_VERSION: String?
            var PREFERRED_MAJOR_VERSION: String?
            var LANGUAGE: String?
            var USERNAME: String?
            var TYPE: String?
            var HASHED: String?

            enum CodingKeys: String, CodingKey {
                case NOSKIP = "NOSKIP"
                case VERSION_EMIT_PATH = "VERSION_EMIT_PATH"
                case PATTERN = "PATTERN"
                case APPLE_ID = "APPLE_ID"
                case PASSWORD_FILE = "PASSWORD_FILE"
                case PASSWORD = "PASSWORD"
                case BETA = "BETA"
                case NAME = "NAME"
                case AC_USERNAME = "AC_USERNAME"
                case AC_PASSWORD = "AC_PASSWORD"
                case OS = "OS"
                case CHEF_VERSION = "CHEF_VERSION"
                case URL = "URL"
                case VERSION = "VERSION"
                case RELEASE = "RELEASE"
                case JVM_TYPE = "JVM_TYPE"
                case JDK_TYPE = "JDK_TYPE"
                case JDK_VERSION = "JDK_VERSION"
                case BINARY_TYPE = "BINARY_TYPE"
                case SPARKLE_FEED_URL = "SPARKLE_FEED_URL"
                case USER_AGENT = "USER_AGENT"
                case PRERELEASE = "PRERELEASE"
                case DOWNLOAD_ARCH = "DOWNLOAD_ARCH"
                case ARCH = "ARCH"
                case DOWNLOAD_URL = "DOWNLOAD_URL"
                case LOCALE = "LOCALE"
                case OS_TYPE = "OS_TYPE"
                case baseurl = "baseurl"
                case REG_FIRSTNAME = "REG_FIRSTNAME"
                case REG_EMAIL = "REG_EMAIL"
                case REG_LASTNAME = "REG_LASTNAME"
                case PRODUCT_NAME_PATTERN = "PRODUCT_NAME_PATTERN"
                case REG_PHONE = "REG_PHONE"
                case REG_CITY = "REG_CITY"
                case REG_STATE = "REG_STATE"
                case REG_COUNTRY = "REG_COUNTRY"
                case SEARCH_PATTERN = "SEARCH_PATTERN"
                case SEARCH_URL = "SEARCH_URL"
                case ARCH_TYPE = "ARCH_TYPE"
                case HORIZON_MAJOR_VERSION = "HORIZON_MAJOR_VERSION"
                case MAJOR_VERSION = "MAJOR_VERSION"
                case ARCHITECTURE = "ARCHITECTURE"
                case DOWNLOAD_TYPE = "DOWNLOAD_TYPE"
                case DOWNLOAD_KEY = "DOWNLOAD_KEY"
                case DOWNLOAD_TITLE = "DOWNLOAD_TITLE"
                case DOWNLOAD_ARCHITECTURE = "DOWNLOAD_ARCHITECTURE"
                case SUPPORTED_ARCH = "SUPPORTED_ARCH"
                case include_prereleases = "include_prereleases"
                case BASE_URL = "BASE_URL"
                case POLYCOMRPDESKTOP_DMG_REPATTERN = "POLYCOMRPDESKTOP_DMG_REPATTERN"
                case CHECK_PAGE_URL = "CHECK_PAGE_URL"
                case url = "url"
                case RELEASE_CHANNEL1 = "RELEASE_CHANNEL1"
                case RELEASE_CHANNEL2 = "RELEASE_CHANNEL2"
                case LATESTONLY = "LATESTONLY"
                case DOWNLOAD_CHECK_URL = "DOWNLOAD_CHECK_URL"
                case PRODUCTID = "PRODUCTID"
                case DOWNLOADURL = "DOWNLOADURL"
                case DEVELOPER = "DEVELOPER"
                case VENDOR = "VENDOR"
                case SOFTWARETITLE = "SOFTWARETITLE"
                case DOWNLOAD_UUID = "DOWNLOAD_UUID"
                case DOWNLOAD_FILENAME = "DOWNLOAD_FILENAME"
                case SOFTWARETITLE1 = "SOFTWARETITLE1"
                case SOFTWARETITLE2 = "SOFTWARETITLE2"
                case OSFAMILYNAME = "OSFAMILYNAME"
                case OSVSERSIONNAME = "OSVSERSIONNAME"
                case OSVSERSIONNUMBER = "OSVSERSIONNUMBER"
                case SOFTWARETYPE = "SOFTWARETYPE"
                case DISTRIBUTION = "DISTRIBUTION"
                case PACKAGER = "PACKAGER"
                case SOFTWARETITLE3 = "SOFTWARETITLE3"
                case SOFTWARETITLE4 = "SOFTWARETITLE4"
                case DOWNLOAD_USERAGENT = "DOWNLOAD_USERAGENT"
                case DOWNLOAD_BASE_URL = "DOWNLOAD_BASE_URL"
                case APP_FILENAME = "APP_FILENAME"
                case CONTENT_TYPE_HEADER = "CONTENT_TYPE_HEADER"
                case DATA_BINARY_CONTENT = "DATA_BINARY_CONTENT"
                case ID = "ID"
                case DOWNLOAD_URL_BASE = "DOWNLOAD_URL_BASE"
                case INTEL_SEARCH_PATTERN = "INTEL_SEARCH_PATTERN"
                case APPLE_SILICON_SEARCH_PATTERN = "APPLE_SILICON_SEARCH_PATTERN"
                case APPLE_SILICON_ARCHITECTURE = "APPLE_SILICON_ARCHITECTURE"
                case INTEL_ARCHITECTURE = "INTEL_ARCHITECTURE"
                case NAMEWITHOUTSPACES = "NAMEWITHOUTSPACES"
                case BUILD = "BUILD"
                case SOFTWARETITLE5 = "SOFTWARETITLE5"
                case LOCALE_ID = "LOCALE_ID"
                case CHANNEL = "CHANNEL"
                case PRODUCT = "PRODUCT"
                case OS_VERSION = "OS_VERSION"
                case CULTURE_CODE = "CULTURE_CODE"
                case DOWNLOAD_URL_SCHEME = "DOWNLOAD_URL_SCHEME"
                case PLATFORM = "PLATFORM"
                case LATEST_RELEASE = "LATEST_RELEASE"
                case TARGET_OS = "TARGET_OS"
                case INCLUDE_PRERELEASES = "INCLUDE_PRERELEASES"
                case BRANCH = "BRANCH"
                case APPCAST_URL = "APPCAST_URL"
                case REVISION = "REVISION"
                case INCL_PRERELEASES = "INCL_PRERELEASES"
                case PLATFORM_ARCH = "PLATFORM_ARCH"
                case FILENAME = "FILENAME"
                case ECLIPSE_CODE = "ECLIPSE_CODE"
                case GITHUB_REPO = "GITHUB_REPO"
                case majorRelease = "majorRelease"
                case minorRelease = "minorRelease"
                case GITLAB_HOSTNAME = "GITLAB_HOSTNAME"
                case JOB_NAME = "JOB_NAME"
                case PRIVATE_TOKEN = "PRIVATE_TOKEN"
                case URLENCODED_PROJECT = "URLENCODED_PROJECT"
                case VIRUSTOTAL_AUTO_SUBMIT = "VIRUSTOTAL_AUTO_SUBMIT"
                case RELEASE_TYPE = "RELEASE_TYPE"
                case BEAT_NAME = "BEAT_NAME"
                case OPTIONAL_VERSION = "OPTIONAL_VERSION"
                case PREFERRED_MAJOR_VERSION = "PREFERRED_MAJOR_VERSION"
                case LANGUAGE = "LANGUAGE"
                case USERNAME = "USERNAME"
                case TYPE = "TYPE"
                case HASHED = "HASHED"
            }
        }

        struct Pkgdirs: Codable {
            var Applications: String?
            var usr: String?
            var usrlocal: String?
            var usrlocalbin: String?
            var LibraryPreferencePanes: String?
            var Library: String?
            var LibraryJava: String?
            var LibraryJavaJavaVirtualMachines: String?

            enum CodingKeys: String, CodingKey {
                case Applications = "Applications"
                case usr = "usr"
                case usrlocal = "usr/local"
                case usrlocalbin = "usr/local/bin"
                case LibraryPreferencePanes = "Library/PreferencePanes"
                case Library = "Library"
                case LibraryJava = "Library/Java"
                case LibraryJavaJavaVirtualMachines = "Library/Java/JavaVirtualMachines"
            }
        }

        struct PlistData: Codable {
            var CFBundleShortVersionString: String?

            enum CodingKeys: String, CodingKey {
                case CFBundleShortVersionString = "CFBundleShortVersionString"
            }
        }

        struct PlistKeys: Codable {
            var UpdateVersion: String?
            var CFBundleVersion: String?
            var CFBundleShortVersionString: String?
            var CFBundleIdentifier: String?
            var LSMinimumSystemVersion: String?

            enum CodingKeys: String, CodingKey {
                case UpdateVersion = "Update Version"
                case CFBundleVersion = "CFBundleVersion"
                case CFBundleShortVersionString = "CFBundleShortVersionString"
                case CFBundleIdentifier = "CFBundleIdentifier"
                case LSMinimumSystemVersion = "LSMinimumSystemVersion"
            }
        }

        struct Process: Codable {
            var Processor: String?
            var Arguments: Arguments?
            var Comment: String?
            var request_headers: RequestHeaders?
            var Comments: String?

            enum CodingKeys: String, CodingKey {
                case Processor = "Processor"
                case Arguments = "Arguments"
                case Comment = "Comment"
                case request_headers = "request_headers"
                case Comments = "Comments"
            }
        }

        struct ReFlag: Codable {
        }

        struct RegistrationInfo: Codable {
            var phone: String?
            var city: String?
            var country: String?
            var lastname: String?
            var firstname: String?
            var email: String?
            var state: String?

            enum CodingKeys: String, CodingKey {
                case phone = "phone"
                case city = "city"
                case country = "country"
                case lastname = "lastname"
                case firstname = "firstname"
                case email = "email"
                case state = "state"
            }
        }

        struct RequestHeaders: Codable {
            var AcceptEncoding: String?
            var SecFetchMode: String?
            var Referer: String?
            var SecFetchDest: String?
            var SecFetchSite: String?
            var AcceptLanguage: String?
            var useragent: String?
            var Accept: String?
            var Connection: String?
            var Host: String?
            var UserAgent: String?
            var Cookie: String?
            var Priority: String?
            var contenttype: String?
            var PRIVATETOKEN: String?
            var accept: String?
            var acceptlanguage: String?

            enum CodingKeys: String, CodingKey {
                case AcceptEncoding = "Accept-Encoding"
                case SecFetchMode = "Sec-Fetch-Mode"
                case Referer = "Referer"
                case SecFetchDest = "Sec-Fetch-Dest"
                case SecFetchSite = "Sec-Fetch-Site"
                case AcceptLanguage = "Accept-Language"
                case useragent = "user-agent"
                case Accept = "Accept"
                case Connection = "Connection"
                case Host = "Host"
                case UserAgent = "User-Agent"
                case Cookie = "Cookie"
                case Priority = "Priority"
                case contenttype = "content-type"
                case PRIVATETOKEN = "PRIVATE-TOKEN"
                case accept = "accept"
                case acceptlanguage = "accept-language"
            }
        }

        struct RequestHeaders2: Codable {
            var useragent: String?

            enum CodingKeys: String, CodingKey {
                case useragent = "user-agent"
            }
        }

        struct SupportedPlatform: Codable {
        }

        struct Tags: Codable {
            var url: String?

            enum CodingKeys: String, CodingKey {
                case url = "url"
            }
        }
    }
}
