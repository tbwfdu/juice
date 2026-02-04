//
//  AppDetailSheet.swift
//  Juice
//
//  Created by Pete Lindley on 28/1/2026.
//

import SwiftUI

struct AppDetailSheet: View {
	let item: UemApplication
	let onAddToQueue: (() -> Void)?
	let onClose: (() -> Void)?
	@StateObject private var focusObserver = WindowFocusObserver()

	@Environment(\.dismiss) private var dismiss
	@State private var overviewExpanded = true
	@State private var countsExpanded = false
	@State private var smartGroupsExpanded = false
	@State private var matchedExpanded = false

	var body: some View {
		let glassBaseOpacity = focusObserver.isFocused ? 0.9 : 0.25
        VStack(alignment: .leading, spacing: 20) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DisclosureGroup("Overview", isExpanded: $overviewExpanded) {
                        detailGrid(rows: overviewRows)
                    }
                    .disclosureGroupStyle(DetailSectionDisclosureStyle())

                    if !countRows.isEmpty {
                        DisclosureGroup("Counts", isExpanded: $countsExpanded) {
                            detailGrid(rows: countRows)
                        }
                        .disclosureGroupStyle(DetailSectionDisclosureStyle())
                    }

                    if !smartGroupNames.isEmpty {
                        DisclosureGroup("Smart Groups", isExpanded: $smartGroupsExpanded) {
                            FlowLayout(spacing: 8, rowSpacing: 8) {
                                ForEach(smartGroupNames, id: \.self) { name in
                                    Pill(name, color: .blue)
                                }
                            }
                        }
                        .disclosureGroupStyle(DetailSectionDisclosureStyle())
                    }

                    if let matchedApp = item.updatedApplication {
                        DisclosureGroup("Matched Catalog App", isExpanded: $matchedExpanded) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(matchedApp.name.first ?? matchedApp.token)
                                    .font(.system(.headline, weight: .semibold))
                                matchedCatalogDetails(for: matchedApp)
                            }
                        }
                        .disclosureGroupStyle(DetailSectionDisclosureStyle())
                    }
                }
                .padding(.top, 4)
                .padding(.trailing, 22)
            }
            .padding(.trailing, -22)
            .frame(maxHeight: .infinity, alignment: .top)
            .layoutPriority(1)

			HStack {
				Spacer()
				JuiceButtons.secondary("Close") {
					if let onClose {
						onClose()
					} else {
						dismiss()
					}
				}
				JuiceButtons.primary("Add to Queue") {
					onAddToQueue?()
					dismiss()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            if #available(macOS 26.0, iOS 26.0, *) {
                ZStack {
                    shape.fill(Color.white.opacity(glassBaseOpacity))
                    GlassEffectContainer {
                        shape
                            .fill(Color.white)
                            .glassEffect(.regular, in: shape)
                    }
                }
            } else {
                shape.fill(.ultraThinMaterial)
            }
        }
        .background(WindowFocusReader { focusObserver.attach($0) })
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 4)
        .padding(20)
        .frame(minWidth: 400, minHeight: 520)
		.background(Color.clear)
		#if os(macOS)
		.presentationBackground(.clear)
		#endif
	}

	private var header: some View {
		HStack(alignment: .top, spacing: 18) {
			IconByFiletype(applicationFileName: item.applicationFileName)
			VStack(alignment: .leading, spacing: 8) {
				Text(item.applicationName)
					.font(.system(size: 22, weight: .semibold))
					.foregroundStyle(.primary)

				Text(item.rootLocationGroupName ?? "Unknown location group")
					.font(.system(size: 13, weight: .medium))
					.foregroundStyle(.secondary)

				FlowLayout(spacing: 8, rowSpacing: 8) {
					if item.hasUpdate ?? false {
						Pill("Has Update", color: .orange)
					}
					if item.status != "Active" {
						Pill("Inactive", color: .gray)
					}
					if item.wasMatched == false {
						Pill("No Matches", color: .gray)
					}
					if item.wasMatched == true && item.hasUpdate == false {
						Pill("Up To Date", color: .green)
					}
				}
			}
			Spacer()
			VStack(alignment: .trailing, spacing: 6) {
				Text("Current Version")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(.secondary)
				Text(item.appVersion)
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(.secondary)
				
				if let newVersion = item.updatedApplication?.version, !newVersion.isEmpty {
					Text("New Version")
						.font(.system(size: 11, weight: .bold))
						.foregroundStyle(.secondary)
					Text(newVersion)
						.font(.system(size: 14, weight: .semibold)).lineLimit(1)
				}
			}
		}
	}

	private var overviewRows: [DetailRow] {
		[
			DetailRow(label: "Bundle ID", value: item.bundleId),
			DetailRow(label: "App Type", value: item.appType ?? "Not available"),
			DetailRow(label: "Assignment", value: item.assignmentStatus ?? "Not available"),
			DetailRow(label: "Platform", value: item.platform.map(String.init) ?? "Not available"),
			DetailRow(label: "Application Source", value: item.applicationSource.map(String.init) ?? "Not available"),
			DetailRow(label: "Location Group ID", value: item.locationGroupId.map(String.init) ?? "Not available"),
			DetailRow(label: "Organization UUID", value: item.organizationGroupUuid ?? "Not available"),
			DetailRow(label: "App File", value: item.applicationFileName),
			DetailRow(label: "Metadata File", value: item.metadataFileName ?? "Not available"),
			DetailRow(label: "Icon File", value: item.iconFileName ?? "Not available"),
		]
	}

	private var countRows: [DetailRow] {
		var rows: [DetailRow] = []
		if let assigned = item.assignedDeviceCount {
			rows.append(DetailRow(label: "Assigned Devices", value: String(assigned)))
		}
		if let installed = item.installedDeviceCount {
			rows.append(DetailRow(label: "Installed Devices", value: String(installed)))
		}
		if let notInstalled = item.notInstalledDeviceCount {
			rows.append(DetailRow(label: "Not Installed Devices", value: String(notInstalled)))
		}
		if let supported = item.supportedModels?.model?.count {
			rows.append(DetailRow(label: "Supported Models", value: String(supported)))
		}
		return rows
	}

	private var smartGroupNames: [String] {
		item.smartGroups?
			.compactMap { $0.name }
			.filter { !$0.isEmpty } ?? []
	}

	private func detailGrid(rows: [DetailRow]) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
				HStack(alignment: .top, spacing: 12) {
					Text(row.label)
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.frame(minWidth: 200, idealWidth: 240, maxWidth: 320, alignment: .leading)
					Text(row.value)
						.font(.system(size: 12, weight: .medium))
						.foregroundStyle(.primary)
						// Removed lineLimit(1)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
				.padding(.vertical, 6)
				.padding(.horizontal, 8)
				.background(index.isMultiple(of: 2) ? Color.black.opacity(0.03) : Color.clear)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
	}

	private func matchedCatalogRows(for app: CaskApplication) -> [DetailRow] {
		var rows: [DetailRow] = [
			DetailRow(label: "Version", value: app.version),
			DetailRow(label: "Token", value: app.fullToken.isEmpty ? app.token : app.fullToken),
			DetailRow(label: "Description", value: app.desc ?? "Not available"),
			DetailRow(label: "URL", value: app.url),
			DetailRow(label: "Matched On", value: app.matchedOn ?? "Not available"),
			DetailRow(label: "Match Score", value: app.matchedScore.map(String.init) ?? "Not available")
		]

		if let homepage = app.homepage, !homepage.isEmpty {
			rows.insert(DetailRow(label: "Homepage", value: homepage), at: 3)
		}

		return rows
	}

	private func matchedCatalogDetails(for app: CaskApplication) -> some View {
		let rows = matchedCatalogRows(for: app)

		return VStack(alignment: .leading, spacing: 0) {
			ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
				HStack(alignment: .top, spacing: 12) {
					Text(row.label)
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(.secondary)
						.frame(minWidth: 200, idealWidth: 240, maxWidth: 320, alignment: .leading)

					if row.label == "Matched On" {
						Pill(row.value, color: .blue)
							.padding(.vertical, 2)
							.padding(.horizontal, 4)
							.frame(maxWidth: .infinity, alignment: .leading)
					} else if row.label == "Match Score" {
						let scoreValue = Int(row.value) ?? 85
						Pill(row.value, color: matchScoreColor(score: scoreValue))
							.padding(.vertical, 2)
							.padding(.horizontal, 4)
							.frame(maxWidth: .infinity, alignment: .leading)
					} else {
						Text(row.value)
							.font(.system(size: 12, weight: .medium))
							.foregroundStyle(.primary)
							// Removed lineLimit(2)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}
				.padding(.vertical, 6)
				.padding(.horizontal, 8)
				.background(index.isMultiple(of: 2) ? Color.black.opacity(0.03) : Color.clear)
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
	}

	private func matchScoreColor(score: Int) -> Color {
		let clampedScore = min(max(score, 85), 100)
		let t = CGFloat(clampedScore - 85) / 15.0
		let start = NSColor.systemYellow.usingColorSpace(.deviceRGB) ?? NSColor.systemYellow
		let end = NSColor.systemGreen.usingColorSpace(.deviceRGB) ?? NSColor.systemGreen
		let red = start.redComponent + (end.redComponent - start.redComponent) * t
		let green = start.greenComponent + (end.greenComponent - start.greenComponent) * t
		let blue = start.blueComponent + (end.blueComponent - start.blueComponent) * t
		return Color(NSColor(red: red, green: green, blue: blue, alpha: 1.0))
	}

	private var imageAsset: String {
		if URL(fileURLWithPath: item.applicationFileName).pathExtension == "zip" {
			"zipImage"
		} else if URL(fileURLWithPath: item.applicationFileName).pathExtension == "dmg" {
			"dmgImage"
		} else if URL(fileURLWithPath: item.applicationFileName).pathExtension == "pkg" {
			"pkgImage"
		} else {
			"documentImage"
		}
	}
}

private struct DetailRow: Identifiable {
	let id = UUID()
	let label: String
	let value: String
}

private struct DetailSectionDisclosureStyle: DisclosureGroupStyle {
	func makeBody(configuration: Configuration) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Button {
				withAnimation(.easeInOut(duration: 0.2)) {
					configuration.isExpanded.toggle()
				}
			} label: {
				HStack(spacing: 10) {
					configuration.label
						.font(.system(size: 16, weight: .bold))
						.foregroundStyle(.primary)
					Spacer()
					Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.vertical, 6)
				.padding(.trailing, 12)
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)

			if configuration.isExpanded {
				configuration.content
					.transition(
						.asymmetric(
							insertion: .opacity.combined(with: .offset(y: 8)),
							removal: .opacity.combined(with: .offset(y: -4))
						)
					)
			}
		}
	}
}

private func decodeCaskApplication(from json: String) -> CaskApplication {
    guard let data = json.data(using: .utf8) else {
        fatalError("Failed to encode preview CaskApplication JSON.")
    }
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(CaskApplication.self, from: data)
    } catch {
        fatalError("Failed to decode preview CaskApplication: \(error)")
    }
}

#Preview {
    let sampleCask = decodeCaskApplication(from: """
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

    AppDetailSheet(
        item: UemApplication(
            applicationName: "Omnissa Horizon Client",
            bundleId: "com.omnissa.horizon.client",
            appVersion: "8.16.0",
            actualFileVersion: "8.16.0",
            appType: "Internal",
            status: "Active",
            platform: 0, // Preview: use an Int; UI maps Int to String with String.init
            supportedModels: SupportedModels(model: []),
            assignmentStatus: "Assigned",
            categoryList: nil,
            smartGroups: [SmartGroup(name: "Engineering"), SmartGroup(name: "Design"), SmartGroup(name: "QA")],
            isReimbursable: nil,
            applicationSource: 0,
            locationGroupId: 12345,
            rootLocationGroupName: "HQ",
            organizationGroupUuid: "987654",
            largeIconUri: nil,
            mediumIconUri: nil,
            smallIconUri: nil,
            pushMode: nil,
            appRank: nil,
            assignedDeviceCount: 120,
            installedDeviceCount: 100,
            notInstalledDeviceCount: 20,
            autoUpdateVersion: nil,
            enableProvisioning: nil,
            isDependencyFile: nil,
            contentGatewayId: nil,
            iconFileName: "OmnissaHorizon.png",
            applicationFileName: "Omnissa-Horizon-Client.pkg",
            metadataFileName: "OmnissaHorizon.xml",
            numericId: nil,
            uuid: nil,
            isSelected: nil,
            hasUpdate: true,
            isLatest: true,
            wasMatched: true,
            updatedApplicationGuid: nil,
            updatedApplication: sampleCask
        ),
        onAddToQueue: {},
        onClose: {}
    )
}
