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

nonisolated private func isRunningForPreviews() -> Bool {
	ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

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

struct AppDetailCard: View {
	let item: UemApplication
	let isSelected: Bool
	let onToggleSelect: (() -> Void)?
	let onDetails: (() -> Void)?

	@State private var isHovered: Bool = false

	init(
		item: UemApplication,
		isSelected: Bool = false,
		onToggleSelect: (() -> Void)? = nil,
		onDetails: (() -> Void)? = nil
	) {
		self.item = item
		self.isSelected = isSelected
		self.onToggleSelect = onToggleSelect
		self.onDetails = onDetails
	}

	private var content: some View {
		VStack(alignment: .leading, spacing: 8) {
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
									.fill(Color.white)
									.frame(width: 14, height: 14)
									.shadow(
										color: Color.black.opacity(0.15),
										radius: 1,
										x: 0,
										y: 0
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
				}
				Spacer(minLength: 0)
				if item.hasUpdate ?? false {
					JuiceButtons.smlRoundClear(
						"arrow.up.left.and.arrow.down.right",
						title: "",
						action: { onDetails?() }
					)
					.rotationEffect(Angle(degrees: 180))
				}

			}
			FlowLayout(spacing: 6, rowSpacing: 6) {
				if item.wasMatched ?? false {
					if item.hasUpdate ?? false {
						Pill("Has Update", color: .orange)
					} else {
						Pill("Up To Date", color: .green).onAppear {
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
		let hoverBorder = shape.strokeBorder(
			LinearGradient.juice,
			lineWidth: 1.5,
		).opacity(0.4)
		let selectedBorder = shape.strokeBorder(
			LinearGradient.juice,
			lineWidth: 2
		)

		return Group {
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer {
					content
						.padding(.horizontal, 10)
						.padding(.vertical, 15)
						.glassEffect(.clear, in: shape)
				}
				.background(
					shape.fill(Color.white.opacity(0.8))
				)
				.overlay(
					shape.fill(Color.white.opacity(0.0))
				)
				.opacity(1)
				.shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
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
				.onAppear {
					print("[AppDetailCard] Using Liquid Glass path (macOS 26+)")
				}
			} else {
				// Fallback for older OS versions.
				content
					.padding(.horizontal, 16)
					.padding(.vertical, 12)
					.background(.ultraThinMaterial, in: shape)
					.overlay(
						shape.strokeBorder(.white.opacity(0.12))
					)
					.shadow(
						color: Color.black.opacity(0.10),
						radius: 3,
						x: 0,
						y: 1
					)
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
					.onAppear {
						print(
							"[AppDetailCard] Using fallback path (pre-macOS 26)"
						)
					}
			}
		}
		.frame(maxWidth: 280)
		.contentShape(shape)
		.gesture(
			TapGesture().onEnded {
				onToggleSelect?()
			},
			including: .gesture
		)
		.onHover { hovering in
			withAnimation(.easeOut(duration: 0.15)) {
				isHovered = hovering
			}
		}
		.frame(height: 135)
		.onAppear {

			//			let v = ProcessInfo.processInfo.operatingSystemVersion
			//			print(
			//				"[AppDetailCard] OS version: \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
			//			)

			#if canImport(AppKit)
				if isRunningForPreviews() {
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
	ZStack(){
		if #available(macOS 26.0, iOS 26.0, *) {
			GlassEffectContainer {
				shape
					.fill(Color.clear)
					.glassEffect(.regular, in: shape)
			}
			.overlay {
				shape
					.fill(Color.white.opacity(0))
					.opacity(1)
			}
			AppDetailCard(item: exampleAppItem)
		}
	}
	.frame(width: 300)
		.background(){
			JuiceGradient()
				.frame(maxWidth: .infinity)
				.frame(height: 500)
				.mask(
					LinearGradient(
						stops: [
							.init(color: Color.white, location: 0.0),
							.init(color: Color.white, location: 0.55),
							.init(color: Color.white.opacity(0.7), location: 0.7),
							.init(color: Color.white.opacity(0.3), location: 0.82),
							.init(color: Color.white.opacity(0.0), location: 1.0)
						],
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.ignoresSafeArea(edges: .top)
		}
}
