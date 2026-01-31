import Foundation

struct ParsedMetadata: Codable {
    var _metadata: Metadata?
    var autoremove: Bool?
    var catalogs: [String]?
    var installed_size: Int?
    var installer_item_hash: String?
    var installer_item_location: String?
    var installer_item_size: Int?
    var minimum_os_version: String?
    var name: String?
    var receipts: [Receipt]?
    var uninstall_method: String?
    var uninstallable: Bool?
    var version: String?
    var description: String?
    var category: String?
    var icon_name: String?
    var requires: [String]?
    var developer: String?
    var unattended_install: String?
    var display_name: String?
    var postinstall_script: String?
    var blocking_applications: [String]?
    var uninstall_script: String?
    var unattended_uninstall: String?
    var maximum_os_version: String?
    var postuninstall_script: String?
    var restart_action: String?
    var preinstall_script: String?
    var preuninstall_script: String?
    var installer_choices_xml: [InstallerChoicesXml]?
    var installcheck_script: String?
    var uninstallcheck_script: String?
    var installer_type: String?
    var installs: [InstallItem]?
    var items_to_copy: [ItemToCopy]?
    var extra: [String: AnyCodable]?
}

struct Metadata: Codable {
    var created_by: String?
    var creation_date: String?
    var munki_version: String?
    var os_version: String?
    var extra: [String: AnyCodable]?
}

struct Receipt: Codable {
    var installed_size: Int?
    var packageid: String?
    var version: String?
    var extra: [String: AnyCodable]?
}

struct InstallerChoicesXml: Codable {
    var choice_attribute: String?
    var choice_identifier: String?
    var choice_value: Int?
    var extra: [String: AnyCodable]?
}

struct InstallItem: Codable {
    var cfBundleIdentifier: String?
    var cfBundleName: String?
    var cfBundleShortVersionString: String?
    var cfBundleVersion: String?
    var minosversion: String?
    var path: String?
    var type: String?
    var version_comparison_key: String?
    var extra: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case cfBundleIdentifier = "CFBundleIdentifier"
        case cfBundleName = "CFBundleName"
        case cfBundleShortVersionString = "CFBundleShortVersionString"
        case cfBundleVersion = "CFBundleVersion"
        case minosversion = "minosversion"
        case path = "path"
        case type = "type"
        case version_comparison_key = "version_comparison_key"
        case extra = "_extra"
    }
}

struct ItemToCopy: Codable {
    var destination_path: String?
    var source_item: String?
    var extra: [String: AnyCodable]?
}
