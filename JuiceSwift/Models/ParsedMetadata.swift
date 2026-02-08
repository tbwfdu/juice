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

    init() {
        _metadata = nil
        autoremove = nil
        catalogs = nil
        installed_size = nil
        installer_item_hash = nil
        installer_item_location = nil
        installer_item_size = nil
        minimum_os_version = nil
        name = nil
        receipts = nil
        uninstall_method = nil
        uninstallable = nil
        version = nil
        description = nil
        category = nil
        icon_name = nil
        requires = nil
        developer = nil
        unattended_install = nil
        display_name = nil
        postinstall_script = nil
        blocking_applications = nil
        uninstall_script = nil
        unattended_uninstall = nil
        maximum_os_version = nil
        postuninstall_script = nil
        restart_action = nil
        preinstall_script = nil
        preuninstall_script = nil
        installer_choices_xml = nil
        installcheck_script = nil
        uninstallcheck_script = nil
        installer_type = nil
        installs = nil
        items_to_copy = nil
        extra = nil
    }

    enum CodingKeys: String, CodingKey {
        case _metadata
        case autoremove
        case catalogs
        case installed_size
        case installer_item_hash
        case installer_item_location
        case installer_item_size
        case minimum_os_version
        case name
        case receipts
        case uninstall_method
        case uninstallable
        case version
        case description
        case category
        case icon_name
        case requires
        case developer
        case unattended_install
        case display_name
        case postinstall_script
        case blocking_applications
        case uninstall_script
        case unattended_uninstall
        case maximum_os_version
        case postuninstall_script
        case restart_action
        case preinstall_script
        case preuninstall_script
        case installer_choices_xml
        case installcheck_script
        case uninstallcheck_script
        case installer_type
        case installs
        case items_to_copy
        case extra
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        _metadata = try? container.decode(Metadata.self, forKey: ._metadata)
        autoremove = decodeBool(container, key: .autoremove)
        catalogs = decodeStringArray(container, key: .catalogs)
        installed_size = decodeInt(container, key: .installed_size)
        installer_item_hash = decodeString(container, key: .installer_item_hash)
        installer_item_location = decodeString(container, key: .installer_item_location)
        installer_item_size = decodeInt(container, key: .installer_item_size)
        minimum_os_version = decodeString(container, key: .minimum_os_version)
        name = decodeString(container, key: .name)
        receipts = try? container.decode([Receipt].self, forKey: .receipts)
        uninstall_method = decodeString(container, key: .uninstall_method)
        uninstallable = decodeBool(container, key: .uninstallable)
        version = decodeString(container, key: .version)
        description = decodeString(container, key: .description)
        category = decodeString(container, key: .category)
        icon_name = decodeString(container, key: .icon_name)
        requires = decodeStringArray(container, key: .requires)
        developer = decodeString(container, key: .developer)
        unattended_install = decodeString(container, key: .unattended_install)
        display_name = decodeString(container, key: .display_name)
        postinstall_script = decodeString(container, key: .postinstall_script)
        blocking_applications = decodeStringArray(container, key: .blocking_applications)
        uninstall_script = decodeString(container, key: .uninstall_script)
        unattended_uninstall = decodeString(container, key: .unattended_uninstall)
        maximum_os_version = decodeString(container, key: .maximum_os_version)
        postuninstall_script = decodeString(container, key: .postuninstall_script)
        restart_action = decodeString(container, key: .restart_action)
        preinstall_script = decodeString(container, key: .preinstall_script)
        preuninstall_script = decodeString(container, key: .preuninstall_script)
        installer_choices_xml = try? container.decode([InstallerChoicesXml].self, forKey: .installer_choices_xml)
        installcheck_script = decodeString(container, key: .installcheck_script)
        uninstallcheck_script = decodeString(container, key: .uninstallcheck_script)
        installer_type = decodeString(container, key: .installer_type)
        installs = try? container.decode([InstallItem].self, forKey: .installs)
        items_to_copy = try? container.decode([ItemToCopy].self, forKey: .items_to_copy)
        extra = try? container.decode([String: AnyCodable].self, forKey: .extra)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(_metadata, forKey: ._metadata)
        try container.encodeIfPresent(autoremove, forKey: .autoremove)
        try container.encodeIfPresent(catalogs, forKey: .catalogs)
        try container.encodeIfPresent(installed_size, forKey: .installed_size)
        try container.encodeIfPresent(installer_item_hash, forKey: .installer_item_hash)
        try container.encodeIfPresent(installer_item_location, forKey: .installer_item_location)
        try container.encodeIfPresent(installer_item_size, forKey: .installer_item_size)
        try container.encodeIfPresent(minimum_os_version, forKey: .minimum_os_version)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(receipts, forKey: .receipts)
        try container.encodeIfPresent(uninstall_method, forKey: .uninstall_method)
        try container.encodeIfPresent(uninstallable, forKey: .uninstallable)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(icon_name, forKey: .icon_name)
        try container.encodeIfPresent(requires, forKey: .requires)
        try container.encodeIfPresent(developer, forKey: .developer)
        try container.encodeIfPresent(unattended_install, forKey: .unattended_install)
        try container.encodeIfPresent(display_name, forKey: .display_name)
        try container.encodeIfPresent(postinstall_script, forKey: .postinstall_script)
        try container.encodeIfPresent(blocking_applications, forKey: .blocking_applications)
        try container.encodeIfPresent(uninstall_script, forKey: .uninstall_script)
        try container.encodeIfPresent(unattended_uninstall, forKey: .unattended_uninstall)
        try container.encodeIfPresent(maximum_os_version, forKey: .maximum_os_version)
        try container.encodeIfPresent(postuninstall_script, forKey: .postuninstall_script)
        try container.encodeIfPresent(restart_action, forKey: .restart_action)
        try container.encodeIfPresent(preinstall_script, forKey: .preinstall_script)
        try container.encodeIfPresent(preuninstall_script, forKey: .preuninstall_script)
        try container.encodeIfPresent(installer_choices_xml, forKey: .installer_choices_xml)
        try container.encodeIfPresent(installcheck_script, forKey: .installcheck_script)
        try container.encodeIfPresent(uninstallcheck_script, forKey: .uninstallcheck_script)
        try container.encodeIfPresent(installer_type, forKey: .installer_type)
        try container.encodeIfPresent(installs, forKey: .installs)
        try container.encodeIfPresent(items_to_copy, forKey: .items_to_copy)
        try container.encodeIfPresent(extra, forKey: .extra)
    }

    private func decodeString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    private func decodeStringArray(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> [String]? {
        if let value = try? container.decodeIfPresent([String].self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return [value]
        }
        return nil
    }

    private func decodeInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    private func decodeBool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Bool? {
        if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            let lower = value.lowercased()
            return lower == "true" || lower == "1" || lower == "yes"
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        return nil
    }
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
