//
//  DashboardModel.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 26/1/2026.
//

import SwiftUI

struct PageViewData {
	let caskCount: Int
	let recipeCount: Int
	let availableUpdates: Int
	let queueItems: [CaskApplication]
	let searchResults: [CaskApplication]
	let updateItems: [CaskApplication]
	let importItems: [ImportedApplication]
	let importResults: [ImportedApplication]
	let sampleSearchResult: CaskApplication
	let settings: JuiceConfig
	let uemApps: [UemApplication]
	let caskApplication: CaskApplication

	static let sample = PageViewData(
		caskCount: 214,
		recipeCount: 86,
		availableUpdates: 3,
		queueItems: [
			CaskApplication(
				token: "arc",
				fullToken: "arc",
				name: ["Arc"],
				desc: "Chromium-based browser",
				url: "https://example.com/arc.dmg",
				version: "1.72.0",
				matchingRecipeId: "arc"
			),
			CaskApplication(
				token: "tableplus",
				fullToken: "tableplus",
				name: ["TablePlus"],
				desc: "Database management tool",
				url: "https://example.com/tableplus.zip",
				version: "5.9"
			),
			CaskApplication(
				token: "raycast",
				fullToken: "raycast",
				name: ["Raycast"],
				desc: "Command launcher",
				url: "https://example.com/raycast.dmg",
				version: "1.74.2",
				matchingRecipeId: "raycast"
			),
		],
		searchResults: [
			CaskApplication(
				token: "slack",
				fullToken: "slack",
				name: ["Slack"],
				desc: "Team communication",
				url: "https://example.com/slack.dmg",
				version: "4.37.82"
			),
			CaskApplication(
				token: "figma",
				fullToken: "figma",
				name: ["Figma"],
				desc: "Collaborative design",
				url: "https://example.com/figma.dmg",
				version: "124.7",
				matchingRecipeId: "figma"
			),
		],
		updateItems: [],
		importItems: [
			ImportedApplication(
				fileName: "Jamf Pro.pkg",
				fileExtension: ".pkg",
				fullFilePath: "/Users/pete/Imports/Jamf Pro.pkg",
				hasMetadata: true,
				munkiMetadata: MunkiMetadata(
					installerFile: "/Users/pete/Imports/output/Jamf Pro.pkg",
					installerPlist: "/Users/pete/Imports/output/Jamf Pro.plist",
					iconFile: "/Users/pete/Imports/output/Jamf Pro.png"
				),
				macApplication: CaskApplication(
					token: "jamf-pro",
					fullToken: "jamf-pro",
					name: ["Jamf Pro"],
					desc: "Device management suite",
					url: "https://example.com/jamf-pro.pkg",
					version: "11.0.0"
				)
			),
			ImportedApplication(
				fileName: "Notion.dmg",
				fileExtension: ".dmg",
				fullFilePath: "/Users/pete/Imports/Notion.dmg",
				hasMetadata: false,
				munkiMetadata: nil,
				macApplication: nil
			),
			ImportedApplication(
				fileName: "Chef Tools.zip",
				fileExtension: ".zip",
				fullFilePath: "/Users/pete/Imports/Chef Tools.zip",
				hasMetadata: false,
				munkiMetadata: nil,
				macApplication: nil
			),
		],
		importResults: [
			ImportedApplication(
				fileName: "Xcode.pkg",
				fileExtension: ".pkg",
				fullFilePath: "/Users/pete/Imports/Xcode.pkg",
				hasMetadata: true,
				munkiMetadata: MunkiMetadata(
					installerFile: "/Users/pete/Imports/output/Xcode.pkg",
					installerPlist: "/Users/pete/Imports/output/Xcode.plist",
					iconFile: "/Users/pete/Imports/output/Xcode.png"
				),
				macApplication: CaskApplication(
					token: "xcode",
					fullToken: "xcode",
					name: ["Xcode"],
					desc: "Apple developer tools",
					url: "https://example.com/xcode.pkg",
					version: "16.2"
				)
			),
			ImportedApplication(
				fileName: "Adobe CC.dmg",
				fileExtension: ".dmg",
				fullFilePath: "/Users/pete/Imports/Adobe CC.dmg",
				hasMetadata: false,
				munkiMetadata: nil,
				macApplication: nil
			),
		],
		sampleSearchResult: CaskApplication(
			token: "horizon-client",
			fullToken: "horizon-client",
			name: ["Omnissa Horizon Client"],
			desc: "Enterprise desktop virtualization client for macOS.",
			url: "https://example.com/horizon-client.pkg",
			version: "2312",
			matchingRecipeId: "horizon-client"
		),
		settings: JuiceConfig(
			uemEnvironments: [
				UemEnvironment(
					friendlyName: "Primary Tenant",
					uemUrl: "https://uem.example.com",
					clientId: "uem-client-id",
					clientSecret: "client-secret",
					oauthRegion: "Americas",
					orgGroupName: "Global Org Group",
					orgGroupId: "1234",
					orgGroupUuid: "abcd-1234-efgh-5678"
				),
				UemEnvironment(
					friendlyName: "Secondary Tenant",
					uemUrl: "https://uem-secondary.example.com",
					clientId: "secondary-client-id",
					clientSecret: "secondary-secret",
					oauthRegion: "EMEA",
					orgGroupName: "Engineering",
					orgGroupId: "5678",
					orgGroupUuid: "wxyz-9876-zyxw-4321"
				),
			],
			activeEnvironmentUuid: "abcd-1234-efgh-5678",
			databaseVersion: "2024.02",
			appVersion: "1.0.0"
		),
		uemApps: [
			UemApplication(
				applicationName: "Microsoft Outlook",
				bundleId: "com.ws1.macos.Microsoft-Outlook",
				appVersion: "16.96.25041326.0",
				actualFileVersion: "16.96.25041326",
				appType: "Internal",
				status: "Active",
				platform: 10,
				supportedModels: SupportedModels(
					model: [
						Model(applicationId: 2312, modelId: 14, modelName: "MacBook Pro"),
						Model(applicationId: 2312, modelId: 15, modelName: "MacBook Air"),
						Model(applicationId: 2312, modelId: 16, modelName: "Mac Mini"),
						Model(applicationId: 2312, modelId: 30, modelName: "iMac"),
						Model(applicationId: 2312, modelId: 31, modelName: "Mac Pro"),
						Model(applicationId: 2312, modelId: 35, modelName: "MacBook"),
						Model(applicationId: 2312, modelId: 113, modelName: "Mac Studio")
					]
				),
				assignmentStatus: "Assigned",
				categoryList: CategoryList(category: []),
				smartGroups: [
					SmartGroup(id: 1632, name: "All Devices")
				],
				isReimbursable: false,
				applicationSource: 0,
				locationGroupId: 1418,
				rootLocationGroupName: "Dropbear Labs (UAT)",
				organizationGroupUuid: "94e8fd6d-cb42-4692-bde0-3cbb9249ee6a",
				largeIconUri: "https://ds1831.awmdm.com/DeviceServices/publicblob/4315ee8c-0bfa-4b63-a500-4706d9043514/BlobHandler.pblob",
				mediumIconUri: "https://ds1831.awmdm.com/DeviceServices/publicblob/d96dec40-5d7f-4ea2-b936-83b041779b40/BlobHandler.pblob",
				smallIconUri: "https://ds1831.awmdm.com/DeviceServices/publicblob/9828cd4c-94b2-4c08-a8fa-1258a0c21ed3/BlobHandler.pblob",
				pushMode: 0,
				appRank: 0,
				assignedDeviceCount: 0,
				installedDeviceCount: 0,
				notInstalledDeviceCount: 0,
				autoUpdateVersion: false,
				enableProvisioning: false,
				isDependencyFile: false,
				contentGatewayId: 0,
				iconFileName: "Microsoft_Outlook_1.png",
				applicationFileName: "Microsoft_Outlook_16.96.25041326_Installer-16.96.25041326.pkg",
				metadataFileName: "Microsoft_Outlook-16.96.25041326.plist",
				numericId: Id(value: 2312),
				uuid: "211da721-e637-4751-9f23-7f0b8ddfbdac",
				isSelected: false,
				hasUpdate: false,
				isLatest: nil,
				wasMatched: nil,
				updatedApplicationGuid: nil,
				updatedApplication: nil
			),

			UemApplication(
				applicationName: "zoomusInstallerFull",
				bundleId: "com.ws1.macos.zoomusInstallerFull",
				appVersion: "6.6.2.65462",
				actualFileVersion: "6.6.2.65462",
				appType: "Internal",
				status: "Active",
				platform: 10,
				supportedModels: SupportedModels(
					model: [
						Model(applicationId: 2694, modelId: 14, modelName: "MacBook Pro"),
						Model(applicationId: 2694, modelId: 15, modelName: "MacBook Air"),
						Model(applicationId: 2694, modelId: 16, modelName: "Mac Mini"),
						Model(applicationId: 2694, modelId: 30, modelName: "iMac"),
						Model(applicationId: 2694, modelId: 31, modelName: "Mac Pro"),
						Model(applicationId: 2694, modelId: 35, modelName: "MacBook"),
						Model(applicationId: 2694, modelId: 113, modelName: "Mac Studio")
					]
				),
				assignmentStatus: "Not Assigned",
				categoryList: CategoryList(category: []),
				smartGroups: [],
				isReimbursable: false,
				applicationSource: 0,
				locationGroupId: 1418,
				rootLocationGroupName: "Dropbear Labs (UAT)",
				organizationGroupUuid: "94e8fd6d-cb42-4692-bde0-3cbb9249ee6a",
				largeIconUri: "https://ds1831.awmdm.com/DeviceServices/publicblob/a7f1b13f-8cf9-4c30-a481-0d701d01b0dd/BlobHandler.pblob",
				mediumIconUri: "https://ds1831.awmdm.com/DeviceServices/publicblob/cc2aa46f-a28e-41d5-a80d-9dfa75c447f1/BlobHandler.pblob",
				smallIconUri: "https://ds1831.awmdm.com/DeviceServices/publicblob/72cc1f43-8c55-4701-96a2-10ac48e5c49f/BlobHandler.pblob",
				pushMode: 0,
				appRank: 0,
				assignedDeviceCount: 0,
				installedDeviceCount: 0,
				notInstalledDeviceCount: 0,
				autoUpdateVersion: false,
				enableProvisioning: false,
				isDependencyFile: false,
				contentGatewayId: 0,
				iconFileName: "zoomusInstallerFull_4.png",
				applicationFileName: "zoomusInstallerFull-6.6.2.65462.pkg",
				metadataFileName: "zoomusInstallerFull-6.6.2.65462.plist",
				numericId: Id(value: 2694),
				uuid: "2ab4559b-f0f1-4b2c-8b08-c136588732e7",
				isSelected: false,
				hasUpdate: false,
				isLatest: nil,
				wasMatched: nil,
				updatedApplicationGuid: nil,
				updatedApplication: nil
			)
		],
		caskApplication: decodeCaskApplication(from: """
                {
                    "_id": {
                        "$oid": "68fe0ff311099f10c48ad893"
                    },
                    "token": "omnissa-horizon-client",
                    "full_token": "omnissa-horizon-client",
                    "old_tokens": [
                        "vmware-horizon-client"
                    ],
                    "tap": "homebrew/cask",
                    "name": [
                        "Omnissa Horizon Client"
                    ],
                    "desc": "Virtual machine client",
                    "homepage": "https://www.omnissa.com/",
                    "url": "https://download3.omnissa.com/software/CART26FQ2_MAC_2506/Omnissa-Horizon-Client-2506-8.16.0-16536825094.dmg",
                    "url_specs": {},
                    "version": "2506-8.16.0-16536825094,CART26FQ2_MAC_2506",
                    "outdated": false,
                    "sha256": "45bb7a2ec1b309e9bf93ccda155ab78890c12eabe52cff3e57cd900662a100c0",
                    "depends_on": {
                        "macos": {}
                    },
                    "auto_updates": true,
                    "deprecated": false,
                    "disabled": false,
                    "languages": [],
                    "variations": {},
                    "matchingRecipeId": "com.github.dataJAR-recipes.munki.Omnissa Horizon Client",
                    "matchedOn": "name",
                    "matchedScore": 100
                }
        """)
	)

	static let instance = PageViewData(
		caskCount: 0,
		recipeCount: 0,
		availableUpdates: 0,
		queueItems: [],
		searchResults: [],
		updateItems: [],
		importItems: [],
		importResults: [],
		sampleSearchResult: CaskApplication(
			token: "horizon-client",
			fullToken: "horizon-client",
			name: ["Omnissa Horizon Client"],
			desc: "Enterprise desktop virtualization client for macOS.",
			url: "https://example.com/horizon-client.pkg",
			version: "2312",
			matchingRecipeId: "horizon-client"
		),
		settings: JuiceConfig(
			uemEnvironments: [
				UemEnvironment(
					friendlyName: "Primary Tenant",
					uemUrl: "https://uem.example.com",
					clientId: "uem-client-id",
					clientSecret: "client-secret",
					oauthRegion: "Americas",
					orgGroupName: "Global Org Group",
					orgGroupId: "1234",
					orgGroupUuid: "abcd-1234-efgh-5678"
				),
			],
			activeEnvironmentUuid: "abcd-1234-efgh-5678",
			databaseVersion: "2024.02",
			appVersion: "1.0.0"
		),
		uemApps: [],
		caskApplication: decodeCaskApplication(from: """
                {
                    "_id": { "$oid": "000000000000000000000000" },
                    "token": "placeholder",
                    "full_token": "placeholder",
                    "old_tokens": [],
                    "tap": "homebrew/cask",
                    "name": ["Placeholder App"],
                    "desc": "Placeholder cask application",
                    "homepage": "https://example.com",
                    "url": "https://example.com/app.dmg",
                    "url_specs": {},
                    "version": "0.0.0",
                    "outdated": false,
                    "sha256": "",
                    "depends_on": { "macos": {} },
                    "auto_updates": false,
                    "deprecated": false,
                    "disabled": false,
                    "languages": [],
                    "variations": {}
                }
        """)
	)
}

private func decodeCaskApplication(from json: String) -> CaskApplication {
    let data = Data(json.utf8)
    let decoder = JSONDecoder()
    // Allow snake_case keys like full_token to map to camelCase if the model uses it
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    do {
        return try decoder.decode(CaskApplication.self, from: data)
    } catch {
        fatalError("Failed to decode sample CaskApplication: \(error)")
    }
}

struct JuiceConfig {
	let uemEnvironments: [UemEnvironment]
	let activeEnvironmentUuid: String?
	let databaseVersion: String
	let appVersion: String
}
