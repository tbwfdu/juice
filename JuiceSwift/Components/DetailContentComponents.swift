//
//  AppDetailSheet.swift
//  Juice
//
//  Created by Pete Lindley on 28/1/2026.
//

import SwiftUI

// Consolidated inspector detail content sheets for UEM/imported applications.
// Used by: SearchView, UpdatesView, ImportView inspector panels.

struct AppDetailContent: View {
	// MARK: - Inputs

	let item: UemApplication
	let onAddToQueue: (() -> Void)?
	let onClose: (() -> Void)?
	@StateObject private var focusObserver = WindowFocusObserver()

	@Environment(\.dismiss) private var dismiss
	@State private var overviewExpanded = true
	@State private var countsExpanded = false
	@State private var smartGroupsExpanded = false
	@State private var matchedExpanded = false
	@State private var headerHeight: CGFloat = 0

	// MARK: - Body

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			ZStack(alignment: .top) {
				// Scroll content sits below a pinned header; header height is measured dynamically.
					ScrollView {
					VStack(alignment: .leading, spacing: 12) {
						DisclosureGroup("Overview", isExpanded: $overviewExpanded) {
							detailGrid(rows: overviewRows)
						}
						.disclosureGroupStyle(DetailContentDisclosureStyle())

						if !countRows.isEmpty {
							DisclosureGroup("Counts", isExpanded: $countsExpanded) {
								detailGrid(rows: countRows)
							}
							.disclosureGroupStyle(DetailContentDisclosureStyle())
						}

						if !smartGroupNames.isEmpty {
							DisclosureGroup(
								"Smart Groups",
								isExpanded: $smartGroupsExpanded
							) {
								FlowLayout(spacing: 8, rowSpacing: 8) {
									ForEach(smartGroupNames, id: \.self) { name in
										Pill(name, color: .blue)
									}
								}
							}
							.disclosureGroupStyle(DetailContentDisclosureStyle())
						}

						if let matchedApp = item.updatedApplication {
							DisclosureGroup(
								"Matched Catalog App",
								isExpanded: $matchedExpanded
							) {
								VStack(alignment: .leading, spacing: 10) {
									Text(matchedApp.name.first ?? matchedApp.token)
										.font(.system(.headline, weight: .semibold))
									matchedCatalogDetails(for: matchedApp)
								}
							}
							.disclosureGroupStyle(DetailContentDisclosureStyle())
						}
					}
						.padding(.top, headerHeight + 2)
					}
					.panelContentScrollChrome(topInset: 0, bottomContentInset: 20)
					.contentMargins(.top, headerHeight + 2, for: .scrollIndicators)
					.contentMargins(.horizontal, 0, for: .scrollContent)
				.frame(maxHeight: .infinity, alignment: .top)
				.layoutPriority(1)

				VStack(spacing: 0) {
					header
				}
				.background(
					GeometryReader { proxy in
						Color.clear
							.preference(key: DetailContentHeaderHeightKey.self, value: proxy.size.height)
					}
				)
				}
					HStack {
						Spacer()
						Button {
							if let onClose {
								onClose()
							} else {
								dismiss()
							}
						} label: {
							Image(systemName: "xmark")
								.font(.system(size: 11, weight: .regular))
								.padding(.horizontal, -5)
								.padding(.vertical, 2)
						}
						.nativeActionButtonStyle(.secondary, controlSize: .large)
						.buttonBorderShape(.automatic)
						Button {
							onAddToQueue?()
							if onClose == nil {
								dismiss()
							}
						} label: {
							Image(systemName: "plus")
								.font(.system(size: 11, weight: .regular))
								.padding(.horizontal, -5)
								.padding(.vertical, 2)
						}
						.nativeActionButtonStyle(.primary, controlSize: .large)
						.buttonBorderShape(.automatic)
					}
					.padding(.horizontal, 12)
					.padding(.top, 4)
					.padding(.bottom, 12)
			}
		.padding(.top, 24)
		//.padding(5)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.clipped()
		//.border(Color(.red), width: 1)
		.background(WindowFocusReader { focusObserver.attach($0) })
			.frame(minHeight: 420, alignment: .top)
		//.border(Color(.blue), width: 1)
		.background(Color.clear)
		.presentationBackground(.clear)
		.onPreferenceChange(DetailContentHeaderHeightKey.self) { newValue in
			headerHeight = newValue
		}
	}

	private var header: some View {
		Group {
			if #available(macOS 26.0, iOS 16.0, *) {
				let shape = CustomRoundedCorners(radius: 20, corners: [.topLeft, .topRight])
				ZStack {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
					HStack(alignment: .top, spacing: 8) {
						IconByFiletype(applicationFileName: item.applicationFileName)
						VStack(alignment: .leading, spacing: 4) {
							Text(item.applicationName)
								.font(.system(.callout, weight: .semibold))
								.foregroundStyle(.primary)
								.lineLimit(2)
								.minimumScaleFactor(0.85)
							
							Text(item.rootLocationGroupName ?? "Unknown location group")
								.font(.footnote.weight(.regular))
								.foregroundStyle(.secondary)
							
							FlowLayout(spacing: 6, rowSpacing: 6) {
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
						VStack(alignment: .trailing, spacing: 1) {
							Text("Current Version")
								.font(.caption.weight(.medium))
								.foregroundStyle(.secondary)
								.padding(.top, 2)
							Text(item.appVersion)
								.font(.footnote.weight(.regular))
								.lineLimit(1)
								.foregroundStyle(.secondary)
							if let newVersion = item.updatedApplication?.version,
							   !newVersion.isEmpty
							{
							  Text("Latest Version")
								  .font(.caption.weight(.medium))
								  .foregroundStyle(.secondary)
							  Text(newVersion)
								  .foregroundStyle(.secondary)
								  .font(.footnote.weight(.semibold))
								  .lineLimit(1)
								  .frame(maxWidth: 110, alignment: .trailing)
							}
						}
					}
				.padding(12)
				}
				.overlay(shape.strokeBorder(.white.opacity(0.15)))
				.clipShape(shape)
				.frame(maxHeight: 100)
			} else {
				// Fallback: mimic the glass look with a rounded background material
				let shape = CustomRoundedCorners(radius: 20, corners: [.topLeft, .topRight])
				HStack(alignment: .top, spacing: 8) {
					IconByFiletype(applicationFileName: item.applicationFileName)
					VStack(alignment: .leading, spacing: 4) {
						Text(item.applicationName)
							.font(.system(.callout, weight: .semibold))
							.foregroundStyle(.primary)
							.lineLimit(2)
							.minimumScaleFactor(0.85)
						
						Text(item.rootLocationGroupName ?? "Unknown location group")
							.font(.footnote.weight(.regular))
							.foregroundStyle(.secondary)
						
						FlowLayout(spacing: 6, rowSpacing: 6) {
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
					VStack(alignment: .trailing, spacing: 1) {
						Text("Current Version")
							.font(.caption.weight(.medium))
							.foregroundStyle(.secondary)
							.padding(.top, 2)
						Text(item.appVersion)
							.font(.footnote.weight(.regular))
							.lineLimit(1)
							.foregroundStyle(.secondary)
						if let newVersion = item.updatedApplication?.version,
						   !newVersion.isEmpty
						{
						  Text("Latest Version")
							  .font(.caption.weight(.medium))
							  .foregroundStyle(.secondary)
						  Text(newVersion)
							  .foregroundStyle(.secondary)
							  .font(.footnote.weight(.semibold))
							  .lineLimit(1)
							  .frame(maxWidth: 110, alignment: .trailing)
						}
					}
				}
				.padding(12)
				.background(
					shape
						.fill(.ultraThinMaterial)
						.overlay(shape.strokeBorder(.white.opacity(0.15)))
				)
				.clipShape(shape)
				.shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
			}
		}
	}

	private var overviewRows: [DetailContentRow] {
		[
			DetailContentRow(label: "Bundle ID", value: item.bundleId),
			DetailContentRow(
				label: "App Type",
				value: item.appType ?? "Not available"
			),
			DetailContentRow(
				label: "Assignment",
				value: item.assignmentStatus ?? "Not available"
			),
			DetailContentRow(
				label: "Platform",
				value: item.platform.map(String.init) ?? "Not available"
			),
			DetailContentRow(
				label: "Application Source",
				value: item.applicationSource.map(String.init)
					?? "Not available"
			),
			DetailContentRow(
				label: "Location Group ID",
				value: item.locationGroupId.map(String.init) ?? "Not available"
			),
			DetailContentRow(
				label: "Organization UUID",
				value: item.organizationGroupUuid ?? "Not available"
			),
			DetailContentRow(label: "App File", value: item.applicationFileName),
				DetailContentRow(label: "File Size") {
					RemoteFileSizeValueView(
						urlString: item.updatedApplication?.url,
						font: .footnote.weight(.medium)
					)
				},
			DetailContentRow(
				label: "Metadata File",
				value: item.metadataFileName ?? "Not available"
			),
			DetailContentRow(
				label: "Icon File",
				value: item.iconFileName ?? "Not available"
			),
		]
	}

	private var countRows: [DetailContentRow] {
		var rows: [DetailContentRow] = []
		if let assigned = item.assignedDeviceCount {
			rows.append(
				DetailContentRow(label: "Assigned Devices", value: String(assigned))
			)
		}
		if let installed = item.installedDeviceCount {
			rows.append(
				DetailContentRow(label: "Installed Devices", value: String(installed))
			)
		}
		if let notInstalled = item.notInstalledDeviceCount {
			rows.append(
				DetailContentRow(
					label: "Not Installed Devices",
					value: String(notInstalled)
				)
			)
		}
		if let supported = item.supportedModels?.model?.count {
			rows.append(
				DetailContentRow(label: "Supported Models", value: String(supported))
			)
		}
		return rows
	}

	private var smartGroupNames: [String] {
		item.smartGroups?
			.compactMap { $0.name }
			.filter { !$0.isEmpty } ?? []
	}

	private func detailGrid(rows: [DetailContentRow]) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
				HStack(alignment: .top, spacing: 10) {
					Text(row.label)
						.font(.footnote.weight(.medium))
						.foregroundStyle(.secondary)
						.lineLimit(2)
						.frame(
							minWidth: 64,
							idealWidth: 78,
							maxWidth: 96,
							alignment: .leading
						)
					if let valueView = row.valueView {
						valueView
							.frame(maxWidth: .infinity, alignment: .leading)
					} else {
						Text(row.value ?? "")
							.font(.footnote.weight(.regular))
							.foregroundStyle(.primary)
							.frame(maxWidth: .infinity, alignment: .leading)
							.lineLimit(2)
					}
				}
				.padding(.vertical, 5)
				.padding(.horizontal, 8)
				.background(Color.clear)
			}
		}
	}

	private func matchedCatalogRows(for app: CaskApplication) -> [DetailContentRow] {
		var rows: [DetailContentRow] = [
			DetailContentRow(label: "Version", value: app.version),
			DetailContentRow(
				label: "Token",
				value: app.fullToken.isEmpty ? app.token : app.fullToken
			),
			DetailContentRow(label: "Description", value: app.desc ?? "Not available"),
			DetailContentRow(label: "URL", value: app.url),
			DetailContentRow(
				label: "Matched On",
				value: app.matchedOn ?? "Not available"
			),
			DetailContentRow(
				label: "Match Score",
				value: app.matchedScore.map(String.init) ?? "Not available"
			),
		]

		if let homepage = app.homepage, !homepage.isEmpty {
			rows.insert(DetailContentRow(label: "Homepage", value: homepage), at: 3)
		}

		return rows
	}

	private func matchedCatalogDetails(for app: CaskApplication) -> some View {
		let rows = matchedCatalogRows(for: app)

		return VStack(alignment: .leading, spacing: 0) {
			ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
				HStack(alignment: .top, spacing: 12) {
					Text(row.label)
						.font(.footnote.weight(.medium))
						.foregroundStyle(.secondary)
						.lineLimit(2)
						.frame(
							minWidth: 64,
							idealWidth: 78,
							maxWidth: 96,
							alignment: .leading
						)

					if let valueView = row.valueView {
						valueView
							.frame(maxWidth: .infinity, alignment: .leading)
					} else {
						let value = row.value ?? ""
						if row.label == "Matched On" {
							Pill(value, color: .blue)
								.padding(.vertical, 2)
								.padding(.horizontal, 4)
								.frame(maxWidth: .infinity, alignment: .leading)
						} else if row.label == "Match Score" {
							let scoreValue = Int(value) ?? 85
							Pill(
								value,
								color: matchScoreColor(score: scoreValue)
							)
							.padding(.vertical, 2)
							.padding(.horizontal, 4)
							.frame(maxWidth: .infinity, alignment: .leading)
						} else {
							Text(value)
								.font(.footnote.weight(.regular))
								.foregroundStyle(.primary)
								.lineLimit(2)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}
				.padding(.vertical, 5)
				.padding(.horizontal, 8)
				.background(Color.clear)
			}
		}
	}

	private func matchScoreColor(score: Int) -> Color {
		let clampedScore = min(max(score, 85), 100)
		let t = CGFloat(clampedScore - 85) / 15.0
		let start =
			NSColor.systemYellow.usingColorSpace(.deviceRGB)
			?? NSColor.systemYellow
		let end =
			NSColor.systemGreen.usingColorSpace(.deviceRGB)
			?? NSColor.systemGreen
		let red =
			start.redComponent + (end.redComponent - start.redComponent) * t
		let green =
			start.greenComponent + (end.greenComponent - start.greenComponent)
			* t
		let blue =
			start.blueComponent + (end.blueComponent - start.blueComponent) * t
		return Color(NSColor(red: red, green: green, blue: blue, alpha: 1.0))
	}

	private var imageAsset: String {
		if URL(fileURLWithPath: item.applicationFileName).pathExtension == "zip"
		{
			"zipImage"
		} else if URL(fileURLWithPath: item.applicationFileName).pathExtension
			== "dmg"
		{
			"dmgImage"
		} else if URL(fileURLWithPath: item.applicationFileName).pathExtension
			== "pkg"
		{
			"pkgImage"
		} else {
			"documentImage"
		}
	}
}

private struct DetailContentHeaderHeightKey: PreferenceKey {
	static let defaultValue: CGFloat = 0
	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		let next = nextValue()
		if next > 0 {
			value = next
		}
	}
}

private struct DetailContentRow: Identifiable {
	let id = UUID()
	let label: String
	let value: String?
	let valueView: AnyView?

	init(label: String, value: String) {
		self.label = label
		self.value = value
		self.valueView = nil
	}

	init<Content: View>(label: String, @ViewBuilder value: () -> Content) {
		self.label = label
		self.value = nil
		self.valueView = AnyView(value())
	}
}

private struct DetailContentDisclosureStyle: DisclosureGroupStyle {
	func makeBody(configuration: Configuration) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Button {
				withAnimation(.easeInOut(duration: 0.14)) {
					configuration.isExpanded.toggle()
				}
			} label: {
				HStack(spacing: 8) {
					configuration.label
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(.primary)
					Spacer()
					Image(
						systemName: configuration.isExpanded
							? "chevron.down" : "chevron.right"
					)
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.vertical, 4)
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

let sampleCask = decodeCaskApplication(
	from: """
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
		"""
)

struct LeftPanel: View {
	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		return
			shape
			.fill(Color.white.opacity(0.6))
			.overlay(shape.strokeBorder(.white.opacity(0.2)))
			.shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
	}
}

#Preview {

	ZStack {
		JuiceGradient()
			.ignoresSafeArea()
		LeftPanel()
			.frame(width: 450)
			
			.background {
				let shape = RoundedRectangle(
					cornerRadius: 16,
					style: .continuous
				)
				if #available(macOS 26.0, iOS 26.0, *) {
					ZStack {
						shape.fill(Color.white.opacity(0.5))
						//							GlassEffectContainer {
						//								shape
						//									.fill(Color.white)
						//									.glassEffect(.regular, in: shape)
						//							}
					}
				} else {
					shape.fill(.ultraThinMaterial)
				}
			}
		//.ignoresSafeArea()
		VStack {
			AppDetailContent(
				item: UemApplication(
					applicationName: "Omnissa Horizon Client",
					bundleId: "com.omnissa.horizon.client",
					appVersion: "8.16.0",
					actualFileVersion: "8.16.0",
					appType: "Internal",
					status: "Active",
					platform: 0,  // Preview: use an Int; UI maps Int to String with String.init
					supportedModels: SupportedModels(model: []),
					assignmentStatus: "Assigned",
					categoryList: nil,
					smartGroups: [
						SmartGroup(name: "Engineering"),
						SmartGroup(name: "Design"), SmartGroup(name: "QA"),
					],
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
		.frame(width: 400)
		.padding(10)
	}
	.frame(width: 500, height: 600)
}

struct ImportAppDetailContent: View {
	// MARK: - Inputs

	let item: ImportedApplication
	let onAddToQueue: (() -> Void)?
	let onClose: (() -> Void)?
	@StateObject private var focusObserver = WindowFocusObserver()

	@Environment(\.dismiss) private var dismiss
	@State private var overviewExpanded = true
	@State private var metadataExpanded = true
	@State private var catalogExpanded = false
	@State private var headerHeight: CGFloat = 0

	// MARK: - Body

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			ZStack(alignment: .top) {
					ScrollView {
					VStack(alignment: .leading, spacing: 12) {
						DisclosureGroup("Overview", isExpanded: $overviewExpanded) {
							detailGrid(rows: overviewRows)
						}
						.disclosureGroupStyle(DetailContentDisclosureStyle())

						if hasMetadataSection {
							DisclosureGroup("Metadata", isExpanded: $metadataExpanded) {
								detailGrid(rows: metadataRows)
							}
							.disclosureGroupStyle(DetailContentDisclosureStyle())
						}

						if item.macApplication != nil {
							DisclosureGroup("Catalog Details", isExpanded: $catalogExpanded) {
								detailGrid(rows: catalogRows)
							}
							.disclosureGroupStyle(DetailContentDisclosureStyle())
						}
					}
						.padding(.top, headerHeight + 2)
					}
					.panelContentScrollChrome(topInset: 0, bottomContentInset: 20)
					.contentMargins(.top, headerHeight + 2, for: .scrollIndicators)
					.contentMargins(.horizontal, 0, for: .scrollContent)
				.frame(maxHeight: .infinity, alignment: .top)
				.layoutPriority(1)

				VStack(spacing: 0) {
					header
				}
				.background(
					GeometryReader { proxy in
						Color.clear
							.preference(key: DetailContentHeaderHeightKey.self, value: proxy.size.height)
					}
				)
				}
					HStack {
						Spacer()
						Button {
							if let onClose {
								onClose()
							} else {
								dismiss()
							}
						} label: {
							Image(systemName: "xmark")
								.font(.system(size: 11, weight: .regular))
								.padding(.horizontal, -5)
								.padding(.vertical, 2)
						}
						.nativeActionButtonStyle(.secondary, controlSize: .large)
						.buttonBorderShape(.automatic)
						Button {
							onAddToQueue?()
							if onClose == nil {
								dismiss()
							}
						} label: {
							Image(systemName: "plus")
								.font(.system(size: 11, weight: .regular))
								.padding(.horizontal, -5)
								.padding(.vertical, 2)
						}
						.nativeActionButtonStyle(.primary, controlSize: .large)
						.buttonBorderShape(.automatic)
					}
				.padding(.horizontal, 12)
				.padding(.top, 4)
				.padding(.bottom, 12)
		}
		.padding(.top, 24)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.clipped()
		.background(WindowFocusReader { focusObserver.attach($0) })
		.frame(minHeight: 420, alignment: .top)
		.background(Color.clear)
		.presentationBackground(.clear)
		.onPreferenceChange(DetailContentHeaderHeightKey.self) { newValue in
			headerHeight = newValue
		}
	}

	private var header: some View {
		Group {
			if #available(macOS 26.0, iOS 16.0, *) {
				let shape = CustomRoundedCorners(radius: 20, corners: [.topLeft, .topRight])
				ZStack {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
					HStack(alignment: .top, spacing: 8) {
						ImportAppIconView(item: item)
							.frame(width: 32, height: 32)
						VStack(alignment: .leading, spacing: 4) {
							Text(item.displayTitle)
								.font(.system(.callout, weight: .semibold))
								.foregroundStyle(.primary)
								.lineLimit(2)
								.minimumScaleFactor(0.85)
							Text(item.queueSubtitle)
								.font(.footnote.weight(.regular))
								.foregroundStyle(.secondary)
							FlowLayout(spacing: 6, rowSpacing: 6) {
								if item.hasMetadata {
									Pill("Metadata", color: .green)
								}
								if item.macApplication != nil {
									Pill("Catalog", color: .blue)
								} else {
									Pill("Filesystem", color: .gray)
								}
								Pill(fileTypeLabel, color: .orange)
							}
						}
						Spacer()
						VStack(alignment: .trailing, spacing: 1) {
							Text("Version")
								.font(.caption.weight(.medium))
								.foregroundStyle(.secondary)
								.padding(.top, 2)
							Text(resolvedVersion ?? "Not available")
								.font(.footnote.weight(.regular))
								.lineLimit(1)
								.foregroundStyle(.secondary)
							Text("File Size")
								.font(.caption.weight(.medium))
								.foregroundStyle(.secondary)
							LocalFileSizeValueView(
								filePath: item.fullFilePath,
								cachedBytes: item.cachedFileSizeBytes,
								font: .footnote.weight(.semibold)
							)
						}
					}
					.padding(12)
				}
				.overlay(shape.strokeBorder(.white.opacity(0.15)))
				.clipShape(shape)
					.frame(maxHeight: 100)
			} else {
				let shape = CustomRoundedCorners(radius: 20, corners: [.topLeft, .topRight])
				HStack(alignment: .top, spacing: 8) {
					ImportAppIconView(item: item)
						.frame(width: 32, height: 32)
					VStack(alignment: .leading, spacing: 4) {
						Text(item.displayTitle)
							.font(.system(.callout, weight: .semibold))
							.foregroundStyle(.primary)
							.lineLimit(2)
							.minimumScaleFactor(0.85)
						Text(item.queueSubtitle)
							.font(.footnote.weight(.regular))
							.foregroundStyle(.secondary)
						FlowLayout(spacing: 6, rowSpacing: 6) {
							if item.hasMetadata {
								Pill("Metadata", color: .green)
							}
							if item.macApplication != nil {
								Pill("Catalog", color: .blue)
							} else {
								Pill("Filesystem", color: .gray)
							}
							Pill(fileTypeLabel, color: .orange)
						}
					}
					Spacer()
					VStack(alignment: .trailing, spacing: 1) {
						Text("Version")
							.font(.caption.weight(.medium))
							.foregroundStyle(.secondary)
							.padding(.top, 2)
						Text(resolvedVersion ?? "Not available")
							.font(.footnote.weight(.regular))
							.lineLimit(1)
							.foregroundStyle(.secondary)
						Text("File Size")
							.font(.caption.weight(.medium))
							.foregroundStyle(.secondary)
						LocalFileSizeValueView(
							filePath: item.fullFilePath,
							cachedBytes: item.cachedFileSizeBytes,
							font: .footnote.weight(.semibold)
						)
					}
				}
				.padding(12)
				.background(
					shape
						.fill(.ultraThinMaterial)
						.overlay(shape.strokeBorder(.white.opacity(0.15)))
				)
				.clipShape(shape)
				.shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
			}
		}
	}

	private var overviewRows: [DetailContentRow] {
		[
			DetailContentRow(label: "File Name", value: item.fileName),
			DetailContentRow(label: "File Extension", value: item.fileExtension),
			DetailContentRow(label: "Full Path", value: item.fullFilePath),
				DetailContentRow(label: "File Size") {
					LocalFileSizeValueView(
						filePath: item.fullFilePath,
						cachedBytes: item.cachedFileSizeBytes,
						font: .footnote.weight(.medium)
					)
				},
			DetailContentRow(label: "Type", value: fileTypeLabel),
			DetailContentRow(label: "Metadata Detected", value: item.hasMetadata ? "Yes" : "No"),
			DetailContentRow(label: "Bundle ID", value: bundleIdValue),
			DetailContentRow(label: "Version", value: resolvedVersion ?? "Not available")
		]
	}

	private var metadataRows: [DetailContentRow] {
		[
			DetailContentRow(label: "Installer File", value: item.munkiMetadata?.installerFile ?? "Not available"),
			DetailContentRow(label: "Installer Plist", value: item.munkiMetadata?.installerPlist ?? "Not available"),
			DetailContentRow(label: "Icon File", value: item.munkiMetadata?.iconFile ?? "Not available"),
			DetailContentRow(label: "Display Name", value: item.parsedMetadata?.display_name ?? "Not available"),
			DetailContentRow(label: "Developer", value: item.parsedMetadata?.developer ?? "Not available"),
			DetailContentRow(label: "Description", value: item.parsedMetadata?.description ?? "Not available")
		]
	}

	private var catalogRows: [DetailContentRow] {
		guard let app = item.macApplication else { return [] }
		var rows: [DetailContentRow] = [
			DetailContentRow(label: "Name", value: app.name.first ?? "Not available"),
			DetailContentRow(label: "Version", value: app.version),
			DetailContentRow(label: "Token", value: app.fullToken.isEmpty ? app.token : app.fullToken),
			DetailContentRow(label: "Description", value: app.desc ?? "Not available"),
			DetailContentRow(label: "URL", value: app.url)
		]
		if let homepage = app.homepage, !homepage.isEmpty {
			rows.insert(DetailContentRow(label: "Homepage", value: homepage), at: 4)
		}
		return rows
	}

	private var hasMetadataSection: Bool {
		item.hasMetadata
		|| item.munkiMetadata?.installerFile != nil
		|| item.munkiMetadata?.installerPlist != nil
		|| item.munkiMetadata?.iconFile != nil
		|| item.parsedMetadata != nil
	}

	private var resolvedVersion: String? {
		if let version = item.parsedMetadata?.version, !version.isEmpty {
			return version
		}
		if let version = item.macApplication?.version, !version.isEmpty {
			return version
		}
		if let version = item.parsedMetadata?.installs?.first?.cfBundleShortVersionString,
		   !version.isEmpty {
			return version
		}
		return item.parsedMetadata?.installs?.first?.cfBundleVersion
	}

	private var bundleIdValue: String {
		item.parsedMetadata?.installs?.first?.cfBundleIdentifier ?? "Not available"
	}

	private var fileTypeLabel: String {
		switch item.fileExtension.lowercased() {
		case ".app": return "App Bundle"
		case ".pkg": return "PKG"
		case ".dmg": return "DMG"
		case ".zip": return "ZIP"
		default: return "Installer"
		}
	}

	private func detailGrid(rows: [DetailContentRow]) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
				HStack(alignment: .top, spacing: 10) {
					Text(row.label)
						.font(.footnote.weight(.medium))
						.foregroundStyle(.secondary)
						.lineLimit(2)
						.frame(
							minWidth: 64,
							idealWidth: 78,
							maxWidth: 96,
							alignment: .leading
						)
					if let valueView = row.valueView {
						valueView
							.frame(maxWidth: .infinity, alignment: .leading)
					} else {
							Text(row.value ?? "")
								.font(.footnote.weight(.regular))
								.foregroundStyle(.primary)
								.frame(maxWidth: .infinity, alignment: .leading)
								.lineLimit(2)
					}
				}
				.padding(.vertical, 5)
				.padding(.horizontal, 8)
				.background(Color.clear)
			}
		}
	}
}
