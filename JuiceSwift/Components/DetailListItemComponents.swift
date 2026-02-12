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
	@Environment(\.colorScheme) private var colorScheme

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
		VStack(alignment: .leading, spacing: 4) {
			HStack(alignment: .top, spacing: 8) {
				ZStack(alignment: .bottomLeading) {
					IconByFiletype(applicationFileName: item.iconSource)
				}
				VStack(alignment: .leading, spacing: 2) {
					Text(item.displayName)
						.frame(maxWidth: .infinity, alignment: .leading)
						.clipped()
						.font(.system(.callout, weight: .semibold))
						.lineLimit(1)
					Text(item.desc ?? "")
						.frame(maxWidth: .infinity, alignment: .leading)
						.clipped()
						.font(.system(.footnote, weight: .regular))
						.foregroundStyle(.primary)
						.lineLimit(1)
					HStack(spacing: 4) {
						Text(item.version)
							.frame(alignment: .leading)
							.clipped()
							.lineLimit(1)
							.font(.system(.caption, weight: .medium))
							.foregroundStyle(.primary)
					}
					RemoteFileSizeInlineHorizontalView(
						urlString: item.url,
						label: "Size:",
						labelFont: .system(size: 10, weight: .medium),
						valueFont: .system(size: 10, weight: .medium)
					)
				}
				Spacer(minLength: 0)
			}
			ScrollView(.horizontal, showsIndicators: false) {
				LazyHStack(spacing: 6) {
					ForEach(pillDescriptors) { pill in
						Pill(pill.title, color: pill.color)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.frame(height: 24, alignment: .topLeading)
			.padding(.top, -4)
			.padding(.bottom, -4)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 14)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: true
		)
		let cardBaseColor: Color = colorScheme == .dark ? .black : .white
		let alwaysVisibleBorderColor = GlassThemeTokens.textPrimary(
			for: glassState
		)
		.opacity(colorScheme == .dark ? 0.14 : 0.10)
		let alwaysVisibleBorder = shape.strokeBorder(
			alwaysVisibleBorderColor,
			lineWidth: 0.7
		)
		let liquidBorder = shape.strokeBorder(
			LinearGradient(
				colors: [
					GlassThemeTokens.textPrimary(for: glassState)
						.opacity(colorScheme == .dark ? 0.12 : 0.085),
					GlassThemeTokens.textPrimary(for: glassState)
						.opacity(colorScheme == .dark ? 0.045 : 0.03),
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			),
			lineWidth: 0.75
		)
		let liquidInnerHighlight = shape.inset(by: 1.2).strokeBorder(
			GlassThemeTokens.textPrimary(for: glassState)
				.opacity(colorScheme == .dark ? 0.05 : 0.035),
			lineWidth: 0.55
		)

		return content
			.background(shape.fill(cardBaseColor))
			.overlay(alwaysVisibleBorder)
			.overlay(liquidBorder)
			.overlay(liquidInnerHighlight)
			.clipShape(shape)
			.contentShape(shape)
			.overlay(alignment: .topTrailing) {
				QueueRowEllipsisButton()
					.padding(.top, 8)
					.padding(.trailing, 8)
			}
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
	@Environment(\.colorScheme) private var colorScheme

	// MARK: - Content Layout

	private var content: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(alignment: .top, spacing: 8) {
				ImportAppIconView(item: item)
					.frame(width: 32, height: 32)
				VStack(alignment: .leading, spacing: 2) {
					Text(item.displayTitle)
						.frame(maxWidth: .infinity, alignment: .leading)
						.clipped()
						.font(.system(.callout, weight: .semibold))
						.lineLimit(1)
					Text(item.displaySubtitle)
						.frame(maxWidth: .infinity, alignment: .leading)
						.clipped()
						.lineLimit(1)
						.font(.system(.footnote, weight: .regular))
						.foregroundStyle(.primary)
					let hasVersion = (resolvedVersion ?? "").isEmpty == false
					let versionText =
						hasVersion
						? "Version \(resolvedVersion ?? "")" : "Version"
					Text(versionText)
						.font(.system(.caption, weight: .medium))
						.lineLimit(1)
						.foregroundStyle(.primary)
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
			ScrollView(.horizontal, showsIndicators: false) {
				LazyHStack(spacing: 6) {
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
					Pill(fileTypeLabel, color: .orange)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
			.frame(height: 24, alignment: .topLeading)
			.padding(.top, -4)
			.padding(.bottom, -4)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 14)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: true
		)
		let cardBaseColor: Color = colorScheme == .dark ? .black : .white
		let alwaysVisibleBorderColor = GlassThemeTokens.textPrimary(
			for: glassState
		)
		.opacity(colorScheme == .dark ? 0.14 : 0.10)
		let alwaysVisibleBorder = shape.strokeBorder(
			alwaysVisibleBorderColor,
			lineWidth: 0.7
		)
		let liquidBorder = shape.strokeBorder(
			LinearGradient(
				colors: [
					GlassThemeTokens.textPrimary(for: glassState)
						.opacity(colorScheme == .dark ? 0.12 : 0.085),
					GlassThemeTokens.textPrimary(for: glassState)
						.opacity(colorScheme == .dark ? 0.045 : 0.03),
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			),
			lineWidth: 0.75
		)
		let liquidInnerHighlight = shape.inset(by: 1.2).strokeBorder(
			GlassThemeTokens.textPrimary(for: glassState)
				.opacity(colorScheme == .dark ? 0.05 : 0.035),
			lineWidth: 0.55
		)

		return content
			.background(shape.fill(cardBaseColor))
			.overlay(alwaysVisibleBorder)
			.overlay(liquidBorder)
			.overlay(liquidInnerHighlight)
			.clipShape(shape)
			.contentShape(shape)
			.overlay(alignment: .topTrailing) {
				QueueRowEllipsisButton()
					.padding(.top, 8)
					.padding(.trailing, 8)
			}
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

private struct QueueRowEllipsisButton: View {
	@State private var isExpanded = false
	@State private var isAllExpanded = false

	var body: some View {
		Group {
			if #available(macOS 26.0, iOS 26.0, *) {
				HStack(spacing: 5) {
					if isExpanded {
						Button(action: { collapse() }) {
							Image(systemName: "magnifyingglass")
								.frame(width: 10, height: 10)
								.padding(2)
						}
						.buttonStyle(.glass(.clear))
						.controlSize(.mini)
						.buttonBorderShape(.circle)

						if isAllExpanded {
							Button(action: { collapse() }) {
								Image(systemName: "plus")
									.frame(width: 10, height: 10)
									.padding(2)
							}
							.buttonStyle(.glass(.clear))
							.controlSize(.mini)
							.buttonBorderShape(.circle)
						}
					} else {
						Button(action: { expand() }) {
							Image(systemName: "ellipsis")
								.frame(width: 10, height: 10)
								.padding(2)
						}
						.buttonStyle(.glass(.clear))
						.controlSize(.mini)
						.buttonBorderShape(.circle)
					}
				}
			} else {
				HStack(spacing: 5) {
					if isExpanded {
						Button(action: { collapse() }) {
							Image(systemName: "magnifyingglass")
								.frame(width: 10, height: 10)
								.padding(2)
						}
						.buttonStyle(.bordered)
						.controlSize(.mini)
						.buttonBorderShape(.circle)

						if isAllExpanded {
							Button(action: { collapse() }) {
								Image(systemName: "plus")
									.frame(width: 10, height: 10)
									.padding(2)
							}
							.buttonStyle(.bordered)
							.controlSize(.mini)
							.buttonBorderShape(.circle)
						}
					} else {
						Button(action: { expand() }) {
							Image(systemName: "ellipsis")
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
		.frame(
			width: isExpanded ? (isAllExpanded ? 56 : 30) : 26,
			height: 26,
			alignment: .trailing
		)
		.animation(.bouncy(duration: 0.22, extraBounce: 0.08), value: isExpanded)
		.animation(.bouncy(duration: 0.22, extraBounce: 0.08), value: isAllExpanded)
	}

	private func expand() {
		withAnimation(.bouncy(duration: 0.22, extraBounce: 0.08)) {
			isExpanded = true
			isAllExpanded = true
		}
	}

	private func collapse() {
		withAnimation(.bouncy(duration: 0.2, extraBounce: 0.04)) {
			isExpanded = false
			isAllExpanded = false
		}
	}
}
