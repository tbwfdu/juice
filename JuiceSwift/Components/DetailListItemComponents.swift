//
//  AppRowView.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 25/1/2026.
//
import SwiftUI

// Consolidated list-row components for queued/detail app items.
// Used by: QueuePanelComponents and inspector queue views.

struct AppDetailListItem: View {
	// MARK: - Inputs

	let item: CaskApplication
	let label: String

	private enum PillKey: String, CaseIterable {
		case recipe
		case token
		case filetype
	}

	// Add/remove keys here to control which pills appear.
	private let enabledPillKeys: [PillKey] = [
		.recipe,
		.token,
		.filetype
	]

	// MARK: - Content Layout

	private var content: some View {
		VStack{ 
			HStack(alignment: .top, spacing: 12) {
				ZStack(alignment: .bottomLeading) {
					IconByFiletype(applicationFileName: item.iconSource)
				}
				VStack(alignment: .leading, spacing: 0) {
					Text(item.displayName)
						.font(.title3.weight(.semibold))
						.lineLimit(1)
					Text(item.desc ?? "")
						.font(.body)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
				Spacer()
				VStack(alignment: .listRowSeparatorTrailing, spacing: 0) {
					Text(label)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.trailing)
						.padding(.vertical, 2)
					Text(item.version)
						.font(.body.weight(.regular))
						.lineLimit(1)
						.multilineTextAlignment(.trailing)

					RemoteFileSizeInlineView(
						urlString: item.url,
						label: "Size",
						labelFont: .subheadline.weight(.semibold),
						valueFont: .callout.weight(.regular)
					)
				}
				.frame(minWidth: 80, alignment: .trailing)
				.frame(maxWidth: 100, alignment: .trailing)
			}
			if !pillDescriptors.isEmpty {
				FlowLayout(spacing: 6, rowSpacing: 6) {
					ForEach(pillDescriptors) { pill in
						Pill(pill.title, color: pill.color)
					}
				}
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		return Group {
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer {
					content
						.glassEffect(.regular, in: shape)
				}
				.clipShape(shape)
				.shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
			} else {
				content
					.background(.ultraThinMaterial, in: shape)
					.overlay(
						shape.strokeBorder(.white.opacity(0.08))
					)
					.clipShape(shape)
					.shadow(
						color: Color.black.opacity(0.06),
						radius: 2,
						x: 0,
						y: 1
					)
			}
		}
		.contentShape(shape)
	}

	private struct PillDescriptor: Identifiable {
		let id = UUID()
		let title: String
		let color: Color
	}

	private var pillDescriptors: [PillDescriptor] {
		enabledPillKeys.compactMap { key in
			switch key {
			case .recipe:
				guard item.hasRecipe else { return nil }
				return PillDescriptor(title: "Recipe", color: .green)
			case .token:
				guard item.token.isEmpty == false else { return nil }
				return PillDescriptor(title: item.token, color: .blue)
			case .filetype:
				guard item.url.isEmpty == false else { return nil }
				let ext = URL(fileURLWithPath: item.url).pathExtension.lowercased()
				return PillDescriptor(title: ".\(ext)", color: .blue)
			}
		}
	}
}
#Preview {
	AppDetailListItem(
		item: CaskApplication(
			token: "omnissa-horizon-client",
			fullToken: "omnissa-horizon-client",
			name: ["Omnissa Horizon Client"],
			desc: "Virtual machine client for macOS",
			url: "https://download3.omnissa.com/Omnissa-Horizon-Client.pkg",
			version: "8.16.0",
			autoUpdates: true,
			matchingRecipeId:
				"com.github.dataJAR-recipes.munki.Omnissa Horizon Client"
		),
		label: "Version"
	)
	.padding(20)
	.background(JuiceGradient())
	.frame(width: 420)
}

struct ImportAppDetailListItem: View {
	// MARK: - Inputs

	let item: ImportedApplication
	let label: String

	// MARK: - Content Layout

	private var content: some View {
		VStack {
			HStack(alignment: .top, spacing: 12) {
				ImportAppIconView(item: item)
					.frame(width: 32, height: 32)
				VStack(alignment: .leading, spacing: 0) {
					Text(item.displayTitle)
						.font(.title3.weight(.semibold))
						.lineLimit(1)
					Text(item.queueSubtitle)
						.font(.body)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
				Spacer()
				VStack(alignment: .listRowSeparatorTrailing, spacing: 0) {
					Text(label)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.trailing)
						.padding(.vertical, 2)
					let hasVersion = (resolvedVersion ?? "").isEmpty == false
					let versionText = hasVersion ? (resolvedVersion ?? "") : "Not available"
					Text(versionText)
						.font(.body.weight(.regular))
						.lineLimit(1)
						.multilineTextAlignment(.trailing)
						.opacity(hasVersion ? 1 : 0)
					LocalFileSizeInlineView(
						filePath: item.fullFilePath,
						cachedBytes: item.cachedFileSizeBytes,
						label: "Size",
						labelFont: .subheadline.weight(.semibold),
						valueFont: .callout.weight(.regular)
					)
				}
				.frame(minWidth: 80, alignment: .trailing)
				.frame(maxWidth: 100, alignment: .trailing)
			}
			FlowLayout(spacing: 6, rowSpacing: 6) {
				if item.hasMetadata {
					Pill("Metadata", color: .green)
				}
				if (item.matchingRecipeId ?? "").isEmpty == false || (item.macApplication?.matchingRecipeId ?? "").isEmpty == false {
					Pill("Recipe", color: .orange)
				}
				if item.macApplication != nil {
					Pill("Catalog", color: .blue)
				} else {
					Pill("Filesystem", color: .gray)
				}
				Pill(fileTypeLabel, color: .blue)
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		return Group {
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer {
					content
						.glassEffect(.regular, in: shape)
				}
				.clipShape(shape)
				.shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
			} else {
				content
					.background(.ultraThinMaterial, in: shape)
					.overlay(shape.strokeBorder(.white.opacity(0.08)))
					.clipShape(shape)
					.shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
			}
		}
		.contentShape(shape)
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

	private var fileTypeLabel: String {
		switch item.fileExtension.lowercased() {
		case ".app": return ".app"
		case ".pkg": return ".pkg"
		case ".dmg": return ".dmg"
		case ".zip": return ".zip"
		default: return "file"
		}
	}
}
