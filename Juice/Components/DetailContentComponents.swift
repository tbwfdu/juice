//
//  AppDetailSheet.swift
//  Juice
//
//  Created by Pete Lindley on 28/1/2026.
//

import SwiftUI

// Consolidated inspector detail content sheets for UEM/imported applications.
// Used by: SearchView, UpdatesView, ImportView inspector panels.

private struct DetailPinnedGlassSection<Content: View>: View {
	let corners: CustomRoundedCorners.Corner
	var cornerRadius: CGFloat = 20
	var effectIsRegular: Bool = true
	@ViewBuilder let content: () -> Content

	var body: some View {
		let shape = CustomRoundedCorners(radius: cornerRadius, corners: corners)
		if #available(macOS 26.0, iOS 16.0, *) {
			content()
				.background {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(
								effectIsRegular ? .regular : .clear,
								in: shape
							)
					}
				}
				.overlay(shape.strokeBorder(.white.opacity(0.15)))
				.clipShape(shape)
		} else {
			content()
				.background(
					Group {
						if effectIsRegular {
							shape.fill(.ultraThinMaterial)
						} else {
							shape.fill(Color.clear)
						}
					}
					.overlay(shape.strokeBorder(.white.opacity(0.15)))
				)
				.clipShape(shape)
		}
	}
}

private enum DetailPanelLayout {
	static let headerHeight: CGFloat = 158
	static let bottomBarHeight: CGFloat = 64
	static let horizontalContentInset: CGFloat = 10
	static let bottomButtonVerticalPadding: CGFloat = 10
	static let scrollIndicatorTrailingInset: CGFloat = 8
	static let headerClearanceTopInset: CGFloat = 32
	static let headerBottomInset: CGFloat = 10
	static let scrollTopContentInset: CGFloat = 152
	static let scrollBackgroundTopInset: CGFloat = 141
	static let scrollBackgroundBottomInset: CGFloat = 47
	static let bottomRevealExtra: CGFloat = 16
	static let bottomOverlayCompensation: CGFloat =
		bottomBarHeight + bottomRevealExtra
}

private struct DetailScrollGlassBackground: View {
	let topInset: CGFloat
	let bottomInset: CGFloat
	private let borderColor = Color.white.opacity(0.15)

	var body: some View {
		let shape = Rectangle()
		if #available(macOS 26.0, iOS 16.0, *) {
			GlassEffectContainer {
				shape
					.fill(Color.clear)
					.glassEffect(.regular, in: shape)
			}
			.mask {
				VStack(spacing: 0) {
					Color.clear.frame(height: max(0, topInset))
					Rectangle().fill(Color.white)
					Color.clear.frame(height: max(0, bottomInset))
				}
			}
			.overlay {
				HStack(spacing: 0) {
					Rectangle().fill(borderColor).frame(width: 1)
					Spacer(minLength: 0)
					Rectangle().fill(borderColor).frame(width: 1)
				}
					.mask {
						VStack(spacing: 0) {
							Color.clear.frame(height: max(0, topInset))
							Rectangle().fill(Color.white)
							Color.clear.frame(height: max(0, bottomInset))
						}
					}
			}
		} else {
			shape
				.fill(.ultraThinMaterial)
				.overlay {
					HStack(spacing: 0) {
						Rectangle().fill(borderColor).frame(width: 1)
						Spacer(minLength: 0)
						Rectangle().fill(borderColor).frame(width: 1)
					}
				}
				.mask {
					VStack(spacing: 0) {
						Color.clear.frame(height: max(0, topInset))
						Rectangle().fill(Color.white)
						Color.clear.frame(height: max(0, bottomInset))
					}
				}
		}
	}
}

struct AppDetailContent: View {
	// MARK: - Inputs

	let item: UemApplication
	let onAddToQueue: (() -> Void)?
	let onClose: (() -> Void)?
	@StateObject private var focusObserver = WindowFocusObserver()
	@EnvironmentObject private var catalog: LocalCatalog

	@Environment(\.dismiss) private var dismiss
	@State private var overviewExpanded = true
	@State private var smartGroupsExpanded = false
	@State private var matchedExpanded = false
	@State private var recipeDetailsExpanded = false
	@State private var rawRecipeExpanded = false

	// MARK: - Body

	var body: some View {
		ZStack(alignment: .top) {
			ScrollView {
				VStack(alignment: .leading, spacing: 12) {
					DisclosureGroup(
						"Details",
						isExpanded: $overviewExpanded
					) {
						detailGrid(rows: overviewRows)
					}
					.disclosureGroupStyle(
						DetailContentDisclosureStyle()
					)

					if !smartGroupNames.isEmpty {
						DisclosureGroup(
							"Smart Groups",
							isExpanded: $smartGroupsExpanded
						) {
							FlowLayout(spacing: 8, rowSpacing: 8) {
								ForEach(smartGroupNames, id: \.self) {
									name in
									Pill(name, color: .blue)
								}
							}
						}
						.disclosureGroupStyle(
							DetailContentDisclosureStyle()
						)
					}

					if let matchedApp = item.updatedApplication {
						DisclosureGroup(
							"Matching Update",
							isExpanded: $matchedExpanded
						) {
							VStack(alignment: .leading, spacing: 5) {
								Text(
									matchedApp.name.first
										?? matchedApp.token
								)
								.font(
									.system(
										.headline,
										weight: .semibold
									)
								)
								.padding(.top, 5)
								matchedCatalogDetails(for: matchedApp)
							}
						}
						.disclosureGroupStyle(
							DetailContentDisclosureStyle()
						)

						if hasMatchedRecipe {
							DisclosureGroup(
								"Recipe Details",
								isExpanded: $recipeDetailsExpanded
							) {
								recipeDetails(for: matchedApp)
							}
							.disclosureGroupStyle(
								DetailContentDisclosureStyle()
							)
						}
					}
				}
				//.padding(.top, DetailPanelLayout.headerHeight)
				//.padding(.bottom, DetailPanelLayout.bottomBarHeight)
				.padding(.top, DetailPanelLayout.scrollTopContentInset)
				.padding(.bottom, DetailPanelLayout.bottomOverlayCompensation)
			}
			.background {
				DetailScrollGlassBackground(
//					topInset: DetailPanelLayout.headerHeight,
//					bottomInset: DetailPanelLayout.bottomBarHeight
					topInset: DetailPanelLayout.scrollBackgroundTopInset - 4,
					bottomInset: DetailPanelLayout.scrollBackgroundBottomInset
				)
			}
			.frame(maxHeight: .infinity, alignment: .top)
			.contentMargins(
				.trailing,
				DetailPanelLayout.scrollIndicatorTrailingInset,
				for: .scrollIndicators
			)
			.contentMargins(
				.top,
				DetailPanelLayout.headerHeight,
				for: .scrollIndicators
			)
			.contentMargins(
				.bottom,
				DetailPanelLayout.bottomOverlayCompensation,
				for: .scrollIndicators
			)
			.contentMargins(
				.leading,
				DetailPanelLayout.horizontalContentInset,
				for: .scrollContent
			)
			.contentMargins(
				.trailing,
				DetailPanelLayout.horizontalContentInset,
				for: .scrollContent
			)
			.contentMargins(
				.bottom,
				DetailPanelLayout.bottomOverlayCompensation,
				for: .scrollContent
			)
			
			.layoutPriority(1)

			VStack(spacing: 0) {
				header
					.frame(height: DetailPanelLayout.headerHeight, alignment: .top)
				Spacer(minLength: 0)
				bottomActionBar
					.frame(height: DetailPanelLayout.bottomBarHeight, alignment: .bottom)
			}
		}
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.clipped()
		.background(WindowFocusReader { focusObserver.attach($0) })
		.frame(minHeight: 420, alignment: .top)
		.background(Color.clear)
		.presentationBackground(.clear)
	}

	@ViewBuilder
	private var bottomActionBar: some View {
		DetailPinnedGlassSection(
			corners: [.bottomLeft, .bottomRight],
			cornerRadius: 14,
			effectIsRegular: true
		) {
			bottomActionButtons
		}
	}

	private var bottomActionButtons: some View {
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
					.padding(.horizontal, 2)
					.padding(.vertical, 2)
			}
			.frame(width: 36, height: 36)
			.nativeActionButtonStyle(.secondary, controlSize: .large)
			Button {
				if let onClose {
					onClose()
				} else {
					dismiss()
				}
				onAddToQueue?()
			} label: {
				Image(systemName: "plus")
					.font(.system(size: 11, weight: .regular))
					.padding(.horizontal, 2)
					.padding(.vertical, 2)
			}
			.juiceGradientGlassProminentButtonStyle(controlSize: .large)
			.frame(width: 36, height: 36)
		}
		.padding(.horizontal, DetailPanelLayout.horizontalContentInset)
		.padding(.vertical, DetailPanelLayout.bottomButtonVerticalPadding)
	}

	private var header: some View {
		DetailPinnedGlassSection(corners: [.topLeft, .topRight]) {
			VStack(alignment: .leading, spacing: 4) {
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

				ScrollView(.horizontal, showsIndicators: false) {
					LazyHStack(spacing: 6) {
						if hasMatchedRecipe {
							Pill("Recipe", style: .juiceGradient)
						}
						if item.hasLaterVersionInConsole ?? false {
							Pill("Later Version Added", color: .gray)
						}
						if item.hasUpdate ?? false && !(item.hasLaterVersionInConsole ?? false) {
							Pill("Has Update", color: .orange)
						}
						if item.status != "Active" {
							Pill("Inactive", color: .gray)
						}
						if item.wasMatched == false {
							Pill("No Matches", color: .gray)
						}
						if item.wasMatched == true && item.hasUpdate == false
							&& !(item.hasLaterVersionInConsole ?? false)
						{
							Pill("Up To Date", color: .green)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.frame(height: 24, alignment: .topLeading)
			}
			.padding(.horizontal, DetailPanelLayout.horizontalContentInset)
			.padding(.top, DetailPanelLayout.headerClearanceTopInset + 10)
			.padding(.bottom, DetailPanelLayout.headerBottomInset)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}

	private var overviewRows: [DetailContentRow] {
		var rows: [DetailContentRow] = [
			DetailContentRow(
				label: "Assignment",
				value: item.assignmentStatus ?? "Not available"
			),
			DetailContentRow(
				label: "Organization Group",
				value: item.rootLocationGroupName ?? "Not available"
			),
			DetailContentRow(label: "Update Size") {
				RemoteFileSizeValueView(
					urlString: item.updatedApplication?.url,
					font: .footnote.weight(.medium)
				)
			},
		]

		if let assigned = item.assignedDeviceCount {
			rows.append(
				DetailContentRow(
					label: "Assigned Devices",
					value: String(assigned)
				)
			)
		}
		if let installed = item.installedDeviceCount {
			rows.append(
				DetailContentRow(
					label: "Installed Devices",
					value: String(installed)
				)
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

		return rows
	}

	private var smartGroupNames: [String] {
		item.smartGroups?
			.compactMap { $0.name }
			.filter { !$0.isEmpty } ?? []
	}

	private var hasMatchedRecipe: Bool {
		((item.updatedApplication?.matchingRecipeId ?? "").isEmpty == false)
	}

	private var matchedRecipeId: String? {
		let id = item.updatedApplication?.matchingRecipeId?
			.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		return id.isEmpty ? nil : id
	}

	private var matchedRecipe: Recipe? {
		guard let recipeId = matchedRecipeId else { return nil }
		let normalizedNeedle = normalizeRecipeIdentifier(recipeId)
		return catalog.recipes.first { recipe in
			normalizeRecipeIdentifier(recipe.identifier) == normalizedNeedle
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

	private func matchedCatalogRows(for app: CaskApplication)
		-> [DetailContentRow]
	{
		var rows: [DetailContentRow] = [
			DetailContentRow(label: "Version", value: app.version),
			DetailContentRow(
				label: "Token",
				value: app.fullToken.isEmpty ? app.token : app.fullToken
			),
			DetailContentRow(
				label: "Description",
				value: app.desc ?? "Not available"
			),
			DetailContentRow(label: "URL", value: app.url),
		]

		if let homepage = app.homepage, !homepage.isEmpty {
			rows.insert(
				DetailContentRow(label: "Homepage", value: homepage),
				at: 3
			)
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

	private func recipeDetails(for app: CaskApplication) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			detailGrid(rows: recipeMatchRows(for: app))

			Group {
				if !catalog.isLoaded {
					Text("Loading recipe catalog...")
						.font(.footnote.weight(.regular))
						.foregroundStyle(.secondary)
						.padding(.horizontal, 8)
						.padding(.vertical, 6)
				} else if let recipe = matchedRecipe {
					VStack(alignment: .leading, spacing: 6) {
						Text("Recipe Content")
							.font(.footnote.weight(.semibold))
							.foregroundStyle(.primary)
							.padding(.horizontal, 8)
						detailGrid(rows: recipeSummaryRows(recipe))
						DisclosureGroup(
							"Raw Recipe JSON",
							isExpanded: $rawRecipeExpanded
						) {
							ScrollView(.horizontal, showsIndicators: true) {
								Text(recipePrettyPrintedJSON(recipe))
									.font(.system(.caption, design: .monospaced))
									.textSelection(.enabled)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
							.padding(.horizontal, 8)
							.padding(.vertical, 6)
						}
						.disclosureGroupStyle(DetailContentDisclosureStyle())
					}
				} else {
					Text(
						"Recipe not found for ID: \(matchedRecipeId ?? app.matchingRecipeId ?? "unknown")"
					)
					.font(.footnote.weight(.regular))
					.foregroundStyle(.secondary)
					.padding(.horizontal, 8)
					.padding(.vertical, 6)
				}
			}
		}
	}

	private func recipeMatchRows(for app: CaskApplication) -> [DetailContentRow] {
		[
			DetailContentRow(
				label: "Recipe ID",
				value: app.matchingRecipeId ?? "Not available"
			),
			DetailContentRow(label: "Matched On") {
				Pill(app.matchedOn ?? "Not available", color: .blue)
			},
			DetailContentRow(label: "Match Score") {
				Pill(
					app.matchedScore.map(String.init) ?? "Not available",
					color: matchScoreColor(score: app.matchedScore ?? 85)
				)
			},
		]
	}

	private func recipeSummaryRows(_ recipe: Recipe) -> [DetailContentRow] {
		var rows: [DetailContentRow] = []
		appendRecipeRow(&rows, "Identifier", recipe.identifier)
		appendRecipeRow(&rows, "Display Name", recipe.displayName)
		appendRecipeRow(&rows, "Name", recipe.name)
		appendRecipeRow(&rows, "Description", recipe.description)
		appendRecipeRow(&rows, "Parent Recipe", recipe.parentRecipe)
		appendRecipeRow(
			&rows,
			"Comment",
			(recipe.comment?.isEmpty == false ? recipe.comment : recipe.comments)
		)

		if let pkg = recipe.pkgInfo {
			appendRecipeRow(&rows, "PkgInfo Name", pkg.name)
			appendRecipeRow(&rows, "PkgInfo Display Name", pkg.displayName)
			appendRecipeRow(&rows, "PkgInfo Category", pkg.category)
			appendRecipeRow(&rows, "PkgInfo Developer", pkg.developer)
			appendRecipeRow(&rows, "PkgInfo Min OS", pkg.minimumOsVersion)
			appendRecipeRow(&rows, "PkgInfo Unattended Install", pkg.unattendedInstall)
			appendRecipeRow(
				&rows,
				"PkgInfo Unattended Uninstall",
				pkg.unattendedUninstall
			)
		}

		if let input = recipe.input {
			appendRecipeRow(&rows, "Input Name", input.name)
			appendRecipeRow(&rows, "Input Display Name", input.displayName)
			appendRecipeRow(&rows, "Input Download URL", input.downloadUrl)
			appendRecipeRow(&rows, "Input Download URL Alt", input.downloadUrlAlt)
			appendRecipeRow(&rows, "Input Version", input.version)
			appendRecipeRow(&rows, "Input ID", input.id)
			appendRecipeRow(&rows, "Input Installer Type", input.installerType)
			appendRecipeRow(&rows, "Input Munki Name", input.munkiName)
			appendRecipeRow(
				&rows,
				"Input Munki Display Name",
				input.munkiDisplayName
			)
			appendRecipeRow(&rows, "Input Munki Category", input.munkiCategory)
			appendRecipeRow(&rows, "Input Supported Arch", input.supportedArch)
			appendRecipeRow(&rows, "Input Supported OS", input.supportedOs)
			appendRecipeRow(&rows, "Input Minimum OS", input.minimumOsVersion)
		}
		return rows
	}

	private func appendRecipeRow(
		_ rows: inout [DetailContentRow],
		_ label: String,
		_ value: String?
	) {
		let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		guard !trimmed.isEmpty else { return }
		rows.append(DetailContentRow(label: label, value: trimmed))
	}

	private func normalizeRecipeIdentifier(_ value: String?) -> String {
		(value ?? "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased()
	}

	private func recipePrettyPrintedJSON(_ recipe: Recipe) -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		guard let data = try? encoder.encode(recipe),
			let text = String(data: data, encoding: .utf8)
		else {
			return "Unable to render recipe JSON."
		}
		return text
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
					.transition(.opacity)
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

struct ImportAppDetailContent: View {
	// MARK: - Inputs

	let item: ImportedApplication
	let onAddToQueue: (() -> Void)?
	let onClose: (() -> Void)?
	@StateObject private var focusObserver = WindowFocusObserver()
	@EnvironmentObject private var catalog: LocalCatalog

	@Environment(\.dismiss) private var dismiss
	@State private var detailsExpanded = true
	@State private var matchingUpdateExpanded = false
	@State private var recipeDetailsExpanded = false
	@State private var rawRecipeExpanded = false

	// MARK: - Body

	var body: some View {
		ZStack(alignment: .top) {
			ScrollView {
				VStack(alignment: .leading, spacing: 12) {
					DisclosureGroup(
						"Details",
						isExpanded: $detailsExpanded
					) {
						detailGrid(rows: detailsRows)
					}
					.disclosureGroupStyle(
						DetailContentDisclosureStyle()
					)

					if item.macApplication != nil {
						DisclosureGroup(
							"Matching App",
							isExpanded: $matchingUpdateExpanded
						) {
							detailGrid(rows: catalogRows)
						}
						.disclosureGroupStyle(
							DetailContentDisclosureStyle()
						)
					}

					if hasMatchedRecipe {
						DisclosureGroup(
							"Recipe Details",
							isExpanded: $recipeDetailsExpanded
						) {
							recipeDetails
						}
						.disclosureGroupStyle(
							DetailContentDisclosureStyle()
						)
					}
				}
				//.padding(.top, DetailPanelLayout.headerHeight)
				//.padding(.bottom, DetailPanelLayout.bottomBarHeight)
				.padding(.top, DetailPanelLayout.scrollTopContentInset)
				.padding(.bottom, DetailPanelLayout.bottomOverlayCompensation)
			}
			.background {
				DetailScrollGlassBackground(
//					topInset: DetailPanelLayout.headerHeight,
//					bottomInset: DetailPanelLayout.bottomBarHeight
					topInset: DetailPanelLayout.scrollBackgroundTopInset - 4,
					bottomInset: DetailPanelLayout.scrollBackgroundBottomInset
				)
			}
			.contentMargins(
				.trailing,
				DetailPanelLayout.scrollIndicatorTrailingInset,
				for: .scrollIndicators
			)
			.contentMargins(
				.top,
				DetailPanelLayout.headerHeight,
				for: .scrollIndicators
			)
			.contentMargins(
				.bottom,
				DetailPanelLayout.bottomOverlayCompensation,
				for: .scrollIndicators
			)
			.contentMargins(
				.leading,
				DetailPanelLayout.horizontalContentInset,
				for: .scrollContent
			)
			.contentMargins(
				.trailing,
				DetailPanelLayout.horizontalContentInset,
				for: .scrollContent
			)
			.contentMargins(
				.bottom,
				DetailPanelLayout.bottomOverlayCompensation,
				for: .scrollContent
			)
			.frame(maxHeight: .infinity, alignment: .top)
			.layoutPriority(1)

			VStack(spacing: 0) {
				header
					.frame(height: DetailPanelLayout.headerHeight, alignment: .top)
				Spacer(minLength: 0)
				bottomActionBar
					.frame(height: DetailPanelLayout.bottomBarHeight, alignment: .bottom)
			}
		}
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.clipped()
		.background(WindowFocusReader { focusObserver.attach($0) })
		.frame(minHeight: 420, alignment: .top)
		.background(Color.clear)
		.presentationBackground(.clear)
	}

	@ViewBuilder
	private var bottomActionBar: some View {
		DetailPinnedGlassSection(
			corners: [.bottomLeft, .bottomRight],
			cornerRadius: 14,
			effectIsRegular: true
		) {
			bottomActionButtons
		}
	}

	private var bottomActionButtons: some View {
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
					.padding(.horizontal, 2)
					.padding(.vertical, 2)
			}
			.frame(width: 36, height: 36)
			.nativeActionButtonStyle(.secondary, controlSize: .large)
			Button {
				if let onClose {
					onClose()
				} else {
					dismiss()
				}
				onAddToQueue?()
			} label: {
				Image(systemName: "plus")
					.font(.system(size: 11, weight: .regular))
					.padding(.horizontal, 2)
					.padding(.vertical, 2)
			}
			.juiceGradientGlassProminentButtonStyle(controlSize: .large)
			.frame(width: 36, height: 36)
		}
		.padding(.horizontal, DetailPanelLayout.horizontalContentInset)
		.padding(.vertical, DetailPanelLayout.bottomButtonVerticalPadding)
	}

	private var header: some View {
		DetailPinnedGlassSection(corners: [.topLeft, .topRight]) {
			VStack(alignment: .leading, spacing: 4) {
				HStack(alignment: .top, spacing: 8) {
					ImportAppIconView(item: item)
						.frame(width: 40, height: 40)
					VStack(alignment: .leading, spacing: 4) {
						Text(item.displayTitle)
							.font(.system(.callout, weight: .semibold))
							.foregroundStyle(.primary)
							.lineLimit(2)
							.minimumScaleFactor(0.85)
						Text(item.queueSubtitle)
							.font(.footnote.weight(.regular))
							.foregroundStyle(.secondary)
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
				ScrollView(.horizontal, showsIndicators: false) {
					LazyHStack(spacing: 6) {
						if hasMatchedRecipe {
							Pill("Recipe", style: .juiceGradient)
						}
						if item.hasMetadata {
							Pill("Metadata", color: .green)
						}
						if item.macApplication != nil {
							Pill("Catalog", color: .blue)
						} else {
							Pill("Filesystem", color: .gray)
						}
						Pill(fileTypeLabel, color: .orange)
						if item.macApplication == nil && !hasMatchedRecipe {
							Pill("No Matches", color: .gray)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.frame(height: 24, alignment: .topLeading)
			}
			.padding(.horizontal, DetailPanelLayout.horizontalContentInset)
			.padding(.top, DetailPanelLayout.headerClearanceTopInset + 10)
			.padding(.bottom, DetailPanelLayout.headerBottomInset)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}

	private var detailsRows: [DetailContentRow] {
		[
			DetailContentRow(
				label: "Version",
				value: resolvedVersion ?? "Not available"
			),
			DetailContentRow(label: "File Size") {
				LocalFileSizeValueView(
					filePath: item.fullFilePath,
					cachedBytes: item.cachedFileSizeBytes,
					font: .footnote.weight(.medium)
				)
			},
			DetailContentRow(
				label: "File Extension",
				value: item.fileExtension
			),
			DetailContentRow(label: "Full Path", value: item.fullFilePath),
			DetailContentRow(
				label: "Metadata Detected",
				value: item.hasMetadata ? "Yes" : "No"
			),
		]
	}

	private var catalogRows: [DetailContentRow] {
		guard let app = item.macApplication else { return [] }
		var rows: [DetailContentRow] = [
			DetailContentRow(
				label: "Name",
				value: app.name.first ?? "Not available"
			),
			DetailContentRow(label: "Version", value: app.version),
			DetailContentRow(
				label: "Token",
				value: app.fullToken.isEmpty ? app.token : app.fullToken
			),
			DetailContentRow(
				label: "Description",
				value: app.desc ?? "Not available"
			),
			DetailContentRow(label: "URL", value: app.url),
		]
		if let homepage = app.homepage, !homepage.isEmpty {
			rows.insert(
				DetailContentRow(label: "Homepage", value: homepage),
				at: 4
			)
		}
		return rows
	}

	private var hasMatchedRecipe: Bool {
		!(matchedRecipeId?.isEmpty ?? true)
	}

	private var matchedRecipeId: String? {
		let primary = item.matchingRecipeId?
			.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		if !primary.isEmpty { return primary }
		let fallback = item.macApplication?.matchingRecipeId?
			.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		return fallback.isEmpty ? nil : fallback
	}

	private var matchedRecipe: Recipe? {
		guard let recipeId = matchedRecipeId else { return nil }
		let normalizedNeedle = normalizeRecipeIdentifier(recipeId)
		return catalog.recipes.first { recipe in
			normalizeRecipeIdentifier(recipe.identifier) == normalizedNeedle
		}
	}

	private var recipeDetails: some View {
		VStack(alignment: .leading, spacing: 8) {
			detailGrid(rows: recipeMatchRows)
			Group {
				if !catalog.isLoaded {
					Text("Loading recipe catalog...")
						.font(.footnote.weight(.regular))
						.foregroundStyle(.secondary)
						.padding(.horizontal, 8)
						.padding(.vertical, 6)
				} else if let recipe = matchedRecipe {
					VStack(alignment: .leading, spacing: 6) {
						Text("Recipe Content")
							.font(.footnote.weight(.semibold))
							.foregroundStyle(.primary)
							.padding(.horizontal, 8)
						detailGrid(rows: recipeSummaryRows(recipe))
						DisclosureGroup(
							"Raw Recipe JSON",
							isExpanded: $rawRecipeExpanded
						) {
							ScrollView(.horizontal, showsIndicators: true) {
								Text(recipePrettyPrintedJSON(recipe))
									.font(.system(.caption, design: .monospaced))
									.textSelection(.enabled)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
							.padding(.horizontal, 8)
							.padding(.vertical, 6)
						}
						.disclosureGroupStyle(DetailContentDisclosureStyle())
					}
				} else {
					Text(
						"Recipe not found for ID: \(matchedRecipeId ?? "unknown")"
					)
					.font(.footnote.weight(.regular))
					.foregroundStyle(.secondary)
					.padding(.horizontal, 8)
					.padding(.vertical, 6)
				}
			}
		}
	}

	private var recipeMatchRows: [DetailContentRow] {
		[
			DetailContentRow(
				label: "Recipe ID",
				value: matchedRecipeId ?? "Not available"
			),
			DetailContentRow(label: "Matched On") {
				Pill(
					item.matchedOn ?? item.macApplication?.matchedOn
						?? "Not available",
					color: .blue
				)
			},
			DetailContentRow(label: "Match Score") {
				Pill(
					(item.matchedScore ?? item.macApplication?.matchedScore)
						.map(String.init) ?? "Not available",
					color: matchScoreColor(
						score: item.matchedScore ?? item.macApplication?.matchedScore
							?? 85
					)
				)
			},
		]
	}

	private func recipeSummaryRows(_ recipe: Recipe) -> [DetailContentRow] {
		var rows: [DetailContentRow] = []
		appendRecipeRow(&rows, "Identifier", recipe.identifier)
		appendRecipeRow(&rows, "Display Name", recipe.displayName)
		appendRecipeRow(&rows, "Name", recipe.name)
		appendRecipeRow(&rows, "Description", recipe.description)
		appendRecipeRow(&rows, "Parent Recipe", recipe.parentRecipe)
		appendRecipeRow(
			&rows,
			"Comment",
			(recipe.comment?.isEmpty == false ? recipe.comment : recipe.comments)
		)

		if let pkg = recipe.pkgInfo {
			appendRecipeRow(&rows, "PkgInfo Name", pkg.name)
			appendRecipeRow(&rows, "PkgInfo Display Name", pkg.displayName)
			appendRecipeRow(&rows, "PkgInfo Category", pkg.category)
			appendRecipeRow(&rows, "PkgInfo Developer", pkg.developer)
			appendRecipeRow(&rows, "PkgInfo Min OS", pkg.minimumOsVersion)
			appendRecipeRow(&rows, "PkgInfo Unattended Install", pkg.unattendedInstall)
			appendRecipeRow(
				&rows,
				"PkgInfo Unattended Uninstall",
				pkg.unattendedUninstall
			)
		}

		if let input = recipe.input {
			appendRecipeRow(&rows, "Input Name", input.name)
			appendRecipeRow(&rows, "Input Display Name", input.displayName)
			appendRecipeRow(&rows, "Input Download URL", input.downloadUrl)
			appendRecipeRow(&rows, "Input Download URL Alt", input.downloadUrlAlt)
			appendRecipeRow(&rows, "Input Version", input.version)
			appendRecipeRow(&rows, "Input ID", input.id)
			appendRecipeRow(&rows, "Input Installer Type", input.installerType)
			appendRecipeRow(&rows, "Input Munki Name", input.munkiName)
			appendRecipeRow(
				&rows,
				"Input Munki Display Name",
				input.munkiDisplayName
			)
			appendRecipeRow(&rows, "Input Munki Category", input.munkiCategory)
			appendRecipeRow(&rows, "Input Supported Arch", input.supportedArch)
			appendRecipeRow(&rows, "Input Supported OS", input.supportedOs)
			appendRecipeRow(&rows, "Input Minimum OS", input.minimumOsVersion)
		}

		return rows
	}

	private func appendRecipeRow(
		_ rows: inout [DetailContentRow],
		_ label: String,
		_ value: String?
	) {
		let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		guard !trimmed.isEmpty else { return }
		rows.append(DetailContentRow(label: label, value: trimmed))
	}

	private func normalizeRecipeIdentifier(_ value: String?) -> String {
		(value ?? "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased()
	}

	private func recipePrettyPrintedJSON(_ recipe: Recipe) -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		guard let data = try? encoder.encode(recipe),
			let text = String(data: data, encoding: .utf8)
		else {
			return "Unable to render recipe JSON."
		}
		return text
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

	private var resolvedVersion: String? {
		if let version = item.parsedMetadata?.version, !version.isEmpty {
			return version
		}
		if let version = item.macApplication?.version, !version.isEmpty {
			return version
		}
		if let version = item.parsedMetadata?.installs?.first?
			.cfBundleShortVersionString,
			!version.isEmpty
		{
			return version
		}
		return item.parsedMetadata?.installs?.first?.cfBundleVersion
	}

	private var bundleIdValue: String {
		item.parsedMetadata?.installs?.first?.cfBundleIdentifier
			?? "Not available"
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

#Preview {

	ZStack {
		JuiceGradient()
			.ignoresSafeArea()
//		LeftPanel()
//			.frame(width: 450)
//
//			.background {
//				let shape = RoundedRectangle(
//					cornerRadius: 16,
//					style: .continuous
//				)
//				if #available(macOS 26.0, iOS 26.0, *) {
//					ZStack {
//						shape.fill(Color.white.opacity(0.5))
//						//							GlassEffectContainer {
//						//								shape
//						//									.fill(Color.white)
//						//									.glassEffect(.regular, in: shape)
//						//							}
//					}
//				} else {
//					shape.fill(.ultraThinMaterial)
//				}
//			}
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
			.environmentObject(LocalCatalog())
		}
		.frame(width: 400)
		.padding(10)
	}
	.frame(width: 500)
}

#Preview("Import App Detail") {
	ZStack {
		JuiceGradient()
			.ignoresSafeArea()
//		LeftPanel()
//			.frame(width: 450)
//			.background {
//				let shape = RoundedRectangle(
//					cornerRadius: 16,
//					style: .continuous
//				)
//				if #available(macOS 26.0, iOS 26.0, *) {
//					ZStack {
//						shape.fill(Color.white.opacity(0.5))
//					}
//				} else {
//					shape.fill(.ultraThinMaterial)
//				}
//			}
		VStack {
				ImportAppDetailContent(
				item: ImportedApplication(
					fileName: "Omnissa-Horizon-Client.pkg",
					fileExtension: ".pkg",
					fullFilePath:
						"/Users/pete/Downloads/Omnissa-Horizon-Client.pkg",
					hasMetadata: true,
					isSelected: false,
					munkiMetadata: MunkiMetadata(
						installerFile: "Omnissa-Horizon-Client.pkg",
						installerPlist: "OmnissaHorizon.plist",
						iconFile: "OmnissaHorizon.png"
					),
					macApplication: sampleCask,
					matchingRecipeId:
						"com.github.dataJAR-recipes.munki.Omnissa Horizon Client",
					matchedOn: "name",
					matchedScore: 100,
					selectedIconIndex: nil,
					selectedIconPath: nil,
					cachedFileSizeBytes: 198_765_432,
					uploadProgress: UploadProgress(),
					metadataProgress: MetadataProgress(),
					shouldCloseFlyout: false,
					parsedMetadata: nil,
					proposedMetadata: nil
				),
					onAddToQueue: {},
					onClose: {}
				)
				.environmentObject(LocalCatalog())
			}
		.frame(width: 400)
		.padding(10)
	}
	.frame(width: 500)
}
