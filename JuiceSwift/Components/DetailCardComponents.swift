//
//  AppDetailCard.swift
//  Juice
//
//  Created by Pete Lindley on 28/1/2026.
//

import SwiftUI

#if canImport(AppKit)
	import AppKit
#endif

// Consolidated detail card components for UEM and imported apps.
// Used by: SearchView, UpdatesView, ImportView.

#if canImport(AppKit)
	@MainActor private func applyPreviewWindowChromeTweaks() {
		// In previews, the hosting window is often created *after* the view appears.
		// Run on the next runloop tick (and again shortly after) to catch it reliably.
		@MainActor func apply() {
			for window in NSApp.windows {
				// Make the titlebar visually disappear.
				window.titleVisibility = .hidden
				window.titlebarAppearsTransparent = true

				// Hide traffic-light buttons (Preview-only; may still reappear on hover in some Xcode versions).
				window.standardWindowButton(.closeButton)?.isHidden = true
				window.standardWindowButton(.miniaturizeButton)?.isHidden = true
				window.standardWindowButton(.zoomButton)?.isHidden = true

				// Optional: remove titled style so the titlebar chrome is gone.
				// Comment this out if it affects resizing/dragging in your preview.
				window.styleMask.remove(.titled)
			}
		}
		DispatchQueue.main.async(execute: apply)
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: apply)
	}
#endif

private func softenedDetailBadgeShadow(
	for glassState: GlassStateContext
) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
	_ = glassState
	return (color: .clear, radius: 0, x: 0, y: 0)
}

@MainActor
@ViewBuilder
private func cardActionsButtons(
	onDetails: (() -> Void)?,
	onAddToQueue: (() -> Void)?
	
) -> some View {
//
		if #available(macOS 26.0, *) {
			@State var hoverGlassSpacing:CGFloat = 0
			ZStack {
				GlassEffectContainer(spacing: hoverGlassSpacing) {
					HStack(spacing: 4) {
						if let onDetails {
							Button(action: onDetails) {
								Image(systemName: "magnifyingglass")
									.frame(width: 10, height: 10)
									.padding(2)
							}
							.controlSize(.mini)
							.buttonBorderShape(.circle)
						}
						if let onAddToQueue {
							Button(action: onAddToQueue) {
								Image(systemName: "plus")
									.frame(width: 10, height: 10)
									.padding(2)
							}
							.controlSize(.mini)
							.buttonBorderShape(.circle)
						}
					}
				}
			}
		} else {
			HStack(spacing: 4) {
				if let onDetails {
					Button(action: onDetails) {
						Image(systemName: "magnifyingglass")
							.frame(width: 10, height: 10)
							.padding(2)
					}
					.buttonStyle(.bordered)
					.controlSize(.mini)
					.buttonBorderShape(.circle)
				}
				if let onAddToQueue {
					Button(action: onAddToQueue) {
						Button(action: {}) {
							Image(systemName: "plus")
								.frame(width: 10, height: 10)
								.padding(2)
						}
						.buttonStyle(.bordered)
						.controlSize(.mini)
						.buttonBorderShape(.circle)
					}
				}
			}
		}
	}
//}

struct AppDetailCard: View {
	// MARK: - Inputs

	let item: UemApplication
	let isSelected: Bool
	let onToggleSelect: (() -> Void)?
	let onDetails: (() -> Void)?
	let onAddToQueue: (() -> Void)?
	@Environment(\.colorScheme) private var colorScheme

	@State private var isHovered: Bool = false

	init(
		item: UemApplication,
		isSelected: Bool = false,
		onToggleSelect: (() -> Void)? = nil,
		onDetails: (() -> Void)? = nil,
		onAddToQueue: (() -> Void)? = nil
	) {
		self.item = item
		self.isSelected = isSelected
		self.onToggleSelect = onToggleSelect
		self.onDetails = onDetails
		self.onAddToQueue = onAddToQueue
	}

	// MARK: - Content Layout

	private var content: some View {
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: true
		)
		let badgeShadow = softenedDetailBadgeShadow(for: glassState)
		return VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top, spacing: 8) {
				ZStack(alignment: .topTrailing) {
					IconByFiletype(
						applicationFileName: item.applicationFileName
					)
					if isSelected {
						Image(systemName: "checkmark.circle.fill")
							.font(.system(size: 14, weight: .semibold))
							.foregroundStyle(.green)
							.background(
								Circle()
									.fill(
										GlassThemeTokens.windowBackgroundBase(
											for: glassState
										)
									)
									.frame(width: 14, height: 14)
									.shadow(
										color: badgeShadow.color,
										radius: badgeShadow.radius,
										x: badgeShadow.x,
										y: badgeShadow.y
									)
							)
							.offset(x: 6, y: -6)
							.accessibilityHidden(true)
					}
				}
				VStack(alignment: .leading, spacing: 2) {
					Text(item.applicationName)
						.frame(maxWidth: .infinity, alignment: .leading)
						.clipped()
						.font(.system(.callout, weight: .semibold))

					Text(item.rootLocationGroupName ?? "")
						.frame(maxWidth: .infinity, alignment: .leading)
						.clipped()
						.font(.system(.footnote, weight: .regular))
						.foregroundStyle(.tertiary)
					HStack(spacing: 4) {
						Text(item.appVersion)
							.frame(alignment: .leading)
							.clipped()
							.lineLimit(1)
							.font(.system(.caption, weight: .medium))
							.foregroundStyle(
								(item.hasUpdate ?? false)
									? .tertiary : .secondary
							)
							.strikethrough(item.hasUpdate ?? false)
						if item.hasUpdate ?? false {
							Image(systemName: "arrow.forward")
								.frame(alignment: .leading)
								.font(.system(.caption, weight: .semibold))
								.foregroundColor(.secondary)
							if let newVersion = item.updatedApplication?
								.version, !newVersion.isEmpty
							{
								Text(newVersion)
									.frame(alignment: .leading)
									.clipped()
									.lineLimit(1)
									.font(.system(.caption, weight: .semibold))
									.foregroundStyle(.secondary)
							}
						}
					}
					RemoteFileSizeInlineHorizontalView(
						urlString: item.updatedApplication?.url,
						label: "Size:",
						labelFont: .system(size: 10, weight: .medium),
						valueFont: .system(size: 10, weight: .medium)
					)
				}
				Spacer(minLength: 0)
			}
			FlowLayout(spacing: 6, rowSpacing: 6) {
				if item.wasMatched ?? false {
					if item.hasUpdate ?? false {
						Pill("Has Update", color: .orange)
					} else {
						Pill("Up To Date", color: .green).onAppearUnlessPreview
						{
							printStruct(item)
						}
					}
				} else {
					if item.wasMatched == false {
						Pill("No Matches", color: .gray)
					}
				}
				if item.status != "Active" {
					Pill("Inactive", color: .gray)
				}

				let installedCount = item.installedDeviceCount ?? 0
				if installedCount == 0 {
					Pill("Installs: \(installedCount)", color: .blue)
				}
				let assignedCount = item.assignedDeviceCount ?? 0
				if assignedCount == 0 {
					Pill("Assigned: \(assignedCount)", color: .blue)
				}
				let smartGroupCount = item.smartGroups?.count ?? 0
				if smartGroupCount > 0 {
					Pill("Smart Groups: \(smartGroupCount)", color: .blue)
				}
			}
			Spacer(minLength: 0)
		}
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: true
		)
		//let badgeShadow = softenedDetailBadgeShadow(for: glassState)
		let cardBaseColor = GlassThemeTokens.controlBackgroundBase(
			for: glassState
		)
		let cardFillOpacity = GlassThemeTokens.panelBaseTintOpacity(
			for: glassState
		)
		let hoverBorder = shape.strokeBorder(
			LinearGradient.juice,
			lineWidth: 1.5,
		).opacity(0.4)
		let selectedBorder = shape.strokeBorder(
			LinearGradient.juice,
			lineWidth: 2
		)

		// Container styling is centralized here so inner content stays data-focused.
		return
			content
			.padding(.horizontal, 12)
			.padding(.vertical, 14)
			.glassCompatSurface(
				in: shape,
				style: .clear,
				context: glassState,
				fillColor: cardBaseColor,
				fillOpacity: cardFillOpacity,
				surfaceOpacity: 1
			)
			.glassCompatBorder(in: shape, context: glassState, role: .standard)
			.glassCompatShadow(context: glassState, elevation: .card)
			.clipShape(shape)
			.overlay(
				Group {
					if isSelected {
						selectedBorder
					} else if isHovered {
						hoverBorder
					}
				}
			)
			.frame(minWidth: 250)
			.frame(idealWidth: 275)
			.frame(maxWidth: 400)
			.contentShape(shape)
			.gesture(
				TapGesture().onEnded {
					onToggleSelect?()
				},
				including: .gesture
			)
			.overlay(alignment: .topTrailing) {
				if onDetails != nil || onAddToQueue != nil {
					cardActionsButtons(
						onDetails: (item.hasUpdate ?? false) ? onDetails : nil,
						onAddToQueue: (item.hasUpdate ?? false)
							? onAddToQueue : nil
					)
					.padding(.top, 8)
					.padding(.trailing, 8)
					//.border(.red, width: 1)
				}
			}
			.onHover { hovering in
				withAnimation(.easeOut(duration: 0.15)) {
					isHovered = hovering
				}
			}
			.frame(height: 150)
			.onAppearUnlessPreview {

				//			let v = ProcessInfo.processInfo.operatingSystemVersion
				//			print(
				//				"[AppDetailCard] OS version: \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
				//			)

				#if canImport(AppKit)
					if ProcessInfo.isRunningForPreviews {
						applyPreviewWindowChromeTweaks()
					}
				#endif
			}
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

extension View {
	@ViewBuilder
	fileprivate func ifAvailableSymbolDrawOn() -> some View {
		if #available(macOS 26.0, iOS 26.0, *) {
			// iOS 26.0 also supports .drawOn; using iOS 26.0 keeps iOS builds compiling while no-op below handles older OSes.
			self.symbolEffect(.drawOn)
		} else {
			self
		}
	}
}

struct ImportAppDetailCard: View {
	// MARK: - Inputs

	let item: ImportedApplication
	let isSelected: Bool
	let onToggleSelect: (() -> Void)?
	let onDetails: (() -> Void)?
	let onAddToQueue: (() -> Void)?
	@Environment(\.colorScheme) private var colorScheme

	@State private var isHovered: Bool = false

	init(
		item: ImportedApplication,
		isSelected: Bool = false,
		onToggleSelect: (() -> Void)? = nil,
		onDetails: (() -> Void)? = nil,
		onAddToQueue: (() -> Void)? = nil
	) {
		self.item = item
		self.isSelected = isSelected
		self.onToggleSelect = onToggleSelect
		self.onDetails = onDetails
		self.onAddToQueue = onAddToQueue
	}

	// MARK: - Content Layout

	private var content: some View {
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: true
		)
		let badgeShadow = softenedDetailBadgeShadow(for: glassState)
		return VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top, spacing: 8) {
				ZStack(alignment: .topTrailing) {
					ImportAppIconView(item: item)
						.frame(width: 32, height: 32)
					if isSelected {
						Image(systemName: "checkmark.circle.fill")
							.font(.system(size: 14, weight: .semibold))
							.foregroundStyle(.green)
							.background(
								Circle()
									.fill(
										GlassThemeTokens.windowBackgroundBase(
											for: glassState
										)
									)
									.frame(width: 14, height: 14)
									.shadow(
										color: badgeShadow.color,
										radius: badgeShadow.radius,
										x: badgeShadow.x,
										y: badgeShadow.y
									)
							)
							.offset(x: 6, y: -6)
							.accessibilityHidden(true)
					}
				}
				VStack(alignment: .leading, spacing: 2) {
					Text(item.displayTitle)
						.frame(maxWidth: .infinity, alignment: .leading)
						.clipped()
						.font(.system(.callout, weight: .semibold))
					Text(item.displaySubtitle)
						.frame(maxWidth: .infinity, alignment: .leading)
						.clipped()
						.lineLimit(1)
						.font(.system(.footnote, weight: .regular))
						.foregroundStyle(.tertiary)
					let hasVersion = (resolvedVersion ?? "").isEmpty == false
					let versionText =
						hasVersion
						? "Version \(resolvedVersion ?? "")" : "Version"
					Text(versionText)
						.font(.system(.caption, weight: .medium))
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.opacity(hasVersion ? 1 : 0)
					LocalFileSizeInlineView(
						filePath: item.fullFilePath,
						cachedBytes: item.cachedFileSizeBytes,
						label: "Size:",
						labelFont: .system(size: 10, weight: .medium),
						valueFont: .system(size: 10, weight: .medium)
					)
				}
				Spacer(minLength: 0)
			}
			FlowLayout(spacing: 6, rowSpacing: 6) {
				if item.hasMetadata {
					Pill("Metadata", color: .green)
				}
				if (item.matchingRecipeId ?? "").isEmpty == false
					|| (item.macApplication?.matchingRecipeId ?? "").isEmpty
						== false
				{
					Pill("Recipe", color: .orange)
				}
				if item.macApplication != nil {
					Pill("Catalog", color: .blue)
				} else {
					Pill("Filesystem", color: .gray)
				}
				Pill(fileTypeLabel, color: .orange)
			}
			Spacer(minLength: 0)
		}
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: true
		)
		//let badgeShadow = softenedDetailBadgeShadow(for: glassState)
		let cardBaseColor = GlassThemeTokens.controlBackgroundBase(
			for: glassState
		)
		let cardFillOpacity = GlassThemeTokens.panelBaseTintOpacity(
			for: glassState
		)
		let hoverBorder = shape.strokeBorder(
			LinearGradient.juice,
			lineWidth: 1.5
		).opacity(0.4)
		let selectedBorder = shape.strokeBorder(
			LinearGradient.juice,
			lineWidth: 2
		)

		// Container styling is centralized here so inner content stays data-focused.
		return
			content
			.padding(.horizontal, 12)
			.padding(.vertical, 14)
			.glassCompatSurface(
				in: shape,
				style: .clear,
				context: glassState,
				fillColor: cardBaseColor,
				fillOpacity: cardFillOpacity,
				surfaceOpacity: 1
			)
			.glassCompatBorder(in: shape, context: glassState, role: .standard)
			.glassCompatShadow(context: glassState, elevation: .card)
			.clipShape(shape)
			.overlay(
				Group {
					if isSelected {
						selectedBorder
					} else if isHovered {
						hoverBorder
					}
				}
			)
			.frame(minWidth: 250)
			.frame(idealWidth: 275)
			.frame(maxWidth: 400)
			.contentShape(shape)
			.onTapGesture {
				onToggleSelect?()
			}
			.overlay(alignment: .topTrailing) {
				if onDetails != nil || onAddToQueue != nil {
					cardActionsButtons(
						onDetails: onDetails,
						onAddToQueue: onAddToQueue
					)
					.padding(.top, 8)
					.padding(.trailing, 8)
				}
			}
			.onHover { hovering in
				withAnimation(.easeOut(duration: 0.15)) {
					isHovered = hovering
				}
			}
			.frame(height: 135)
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

	private var fileTypeLabel: String {
		switch item.fileExtension.lowercased() {
		case ".app": return "App Bundle"
		case ".pkg": return "PKG"
		case ".dmg": return "DMG"
		case ".zip": return "ZIP"
		default: return "Installer"
		}
	}
}


#Preview {
	let exampleAppItem = UemApplication(
		applicationName: "Microsoft Outlook",
		bundleId: "com.ws1.macos.Microsoft-Outlook",
		appVersion: "16.96.25041326.0",
		actualFileVersion: "16.96.25041326",
		appType: "Internal",
		status: "Inactive",
		platform: 10,
		supportedModels: SupportedModels(
			model: [
				Model(
					applicationId: 2312,
					modelId: 14,
					modelName: "MacBook Pro"
				),
				Model(
					applicationId: 2312,
					modelId: 15,
					modelName: "MacBook Air"
				),
				Model(applicationId: 2312, modelId: 16, modelName: "Mac Mini"),
				Model(applicationId: 2312, modelId: 30, modelName: "iMac"),
				Model(applicationId: 2312, modelId: 31, modelName: "Mac Pro"),
				Model(applicationId: 2312, modelId: 35, modelName: "MacBook"),
				Model(
					applicationId: 2312,
					modelId: 113,
					modelName: "Mac Studio"
				),
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
		largeIconUri:
			"https://ds1831.awmdm.com/DeviceServices/publicblob/4315ee8c-0bfa-4b63-a500-4706d9043514/BlobHandler.pblob",
		mediumIconUri:
			"https://ds1831.awmdm.com/DeviceServices/publicblob/d96dec40-5d7f-4ea2-b936-83b041779b40/BlobHandler.pblob",
		smallIconUri:
			"https://ds1831.awmdm.com/DeviceServices/publicblob/9828cd4c-94b2-4c08-a8fa-1258a0c21ed3/BlobHandler.pblob",
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
		applicationFileName:
			"Microsoft_Outlook_16.96.25041326_Installer-16.96.25041326.pkg",
		metadataFileName: "Microsoft_Outlook-16.96.25041326.plist",
		numericId: Id(value: 2312),
		uuid: "211da721-e637-4751-9f23-7f0b8ddfbdac",
		isSelected: false,
		hasUpdate: true,
		isLatest: nil,
		wasMatched: false,
		updatedApplicationGuid: nil,
		updatedApplication: nil
	)
	let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
	ZStack {
		if #available(macOS 26.0, iOS 26.0, *) {
			GlassEffectContainer {
				shape
					.fill(Color.clear)
					.glassEffect(.regular, in: shape)
			}
			AppDetailCard(item: exampleAppItem, onDetails: {}, onAddToQueue: {})
		}
	}
	.frame(width: 400)
	.background {
		JuiceGradient()
			.frame(maxWidth: .infinity)
			.frame(height: 500)
			.mask(
				LinearGradient(
					stops: JuiceBackgroundStyle.v1.legacyTopGradientMaskStops,
					startPoint: .top,
					endPoint: .bottom
				)
			)
			.ignoresSafeArea(edges: .top)
	}
}

