import SwiftUI
#if os(macOS)
import AppKit
#endif

// Primary selected-search-result card used in SearchView.
struct SearchResultCard: View {
	@Environment(\.colorScheme) private var colorScheme

	let selectedApplication: CaskApplication
	let title: String
	let subtitle: String
	let token: String
	let version: String
	let fileType: String
	let fileSizeText: String?
	let isFileSizeLoading: Bool
	let isFileSizeUnavailable: Bool
	let actionTitle: String
	let action: () -> Void

	private enum PillKey: String, CaseIterable {
		case recipe
		case autoUpdates
		case deprecated
		case disabled
	}

	// Add/remove keys here to control which pills appear.
	private let enabledPillKeys: [PillKey] = [
		.recipe,
		.disabled
	]

		init(
			selectedApplication: CaskApplication,
			title: String,
			subtitle: String,
			token: String,
			version: String,
			fileType: String,
			fileSizeText: String? = nil,
			isFileSizeLoading: Bool = false,
			isFileSizeUnavailable: Bool = false,
			actionTitle: String = "+",
			action: @escaping () -> Void = {}
		) {
		self.selectedApplication = selectedApplication
		self.title = title
		self.subtitle = subtitle
		self.token = token
		self.version = version
		self.fileType = fileType
		self.fileSizeText = fileSizeText
		self.isFileSizeLoading = isFileSizeLoading
		self.isFileSizeUnavailable = isFileSizeUnavailable
		self.actionTitle = actionTitle
		self.action = action
	}

	// MARK: - Content Layout

	private var content: some View {
		VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .top, spacing: 16) {
					IconByFiletype(applicationFileName: selectedApplication.url)
					VStack(alignment: .leading, spacing: 0) {
					Text(title)
						.font(.title3.weight(.semibold))
						.lineLimit(1)
					Text(subtitle)
						.font(.body)
						.foregroundStyle(.secondary)
						.lineLimit(2)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
						Button(action: action) {
							Image(systemName: "plus")
								.font(.system(size: 11, weight: .regular))
						}
						.juiceGradientGlassProminentButtonStyle(controlSize: .large)
						.frame(width: 32, height: 32)
						.accessibilityLabel(actionTitle)
					}

			Divider()
				.opacity(0.6)

			HStack(spacing: 24) {
				JuiceTypography.metaLabel("Token", value: displayToken)
					.lineLimit(1)
					.truncationMode(.middle)
					.juiceFullValueHelp(fullValue: displayToken)
				JuiceTypography.metaLabel("Version", value: version)
					.lineLimit(1)
				JuiceTypography.metaLabel("Filetype", value: displayFileType)
					.lineLimit(1)
				sizeMetaView
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			if !pillDescriptors.isEmpty {
				FlowLayout(spacing: 6, rowSpacing: 6) {
					ForEach(pillDescriptors) { pill in
						Pill(pill.title, color: pill.color)
					}
				}
			}
		}
	}

	private var sizeMetaView: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("Size")
				.font(.body.weight(.semibold))
			Group {
				if isFileSizeLoading {
					ProgressView()
						.controlSize(.mini)
				} else if let fileSizeText {
					Text(fileSizeText)
						.font(.body)
						.foregroundStyle(.secondary)
				} else if isFileSizeUnavailable {
					Text("")
						.font(.body)
						.foregroundStyle(.secondary)
				} else {
					Text(" ")
						.font(.body)
						.foregroundStyle(.secondary)
				}
			}
			.font(.system(size: 13, weight: .medium))
			.lineLimit(1)
			.frame(height: 16, alignment: .leading)
		}
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		let glassState = GlassStateContext(
			colorScheme: colorScheme,
			isFocused: true
		)
		let panelGlassOpacity = GlassThemeTokens.panelSurfaceOpacity(for: glassState)
		let panelBaseTintColor = GlassThemeTokens.controlBackgroundBase(for: glassState)
		let panelBaseOpacity = GlassThemeTokens.panelBaseTintOpacity(for: glassState)
		let panelBorderColor = GlassThemeTokens.borderColor(for: glassState, role: .standard)
		let panelNeutralOverlayOpacity = GlassThemeTokens.panelNeutralOverlayOpacity(for: glassState)
		return content
			.padding(16)
			.background {
				Color.clear
					.glassCompatSurface(
						in: shape,
						style: .regular,
						context: glassState,
						fillColor: panelBaseTintColor,
						fillOpacity: min(
							1,
							panelBaseOpacity + (panelNeutralOverlayOpacity * 0.45)
						),
						surfaceOpacity: panelGlassOpacity
					)
			}
			.overlay(
				shape.strokeBorder(panelBorderColor.opacity(0.9))
			)
			.clipShape(shape)
			.glassCompatShadow(
				context: glassState,
				elevation: .small
			)
			.contentShape(shape)
	}

	private var displayToken: String {
		if !token.isEmpty { return token }
		if !selectedApplication.fullToken.isEmpty { return selectedApplication.fullToken }
		return selectedApplication.token
	}

	private var displayFileType: String {
		let resolved = fileType.isEmpty ? selectedApplication.fileType : fileType
		return resolved.uppercased()
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
				guard selectedApplication.hasRecipe else { return nil }
				return PillDescriptor(title: "Recipe", color: .green)
			case .autoUpdates:
				guard selectedApplication.autoUpdates == true else { return nil }
				return PillDescriptor(title: "Auto Updates", color: .blue)
			case .deprecated:
				guard selectedApplication.deprecated == true else { return nil }
				return PillDescriptor(title: "Deprecated", color: .gray)
			case .disabled:
				guard selectedApplication.disabled == true else { return nil }
				return PillDescriptor(title: "Disabled", color: .gray)
			}
		}
	}

//    private var iconName: String {
//		if fileType.lowercased() == "zip" {
//			"zipper.page"
//		}
//		else if fileType.lowercased() == "dmg" {
//			"externaldrive.fill"
//		}
//		else if fileType.lowercased() == "pkg" {
//			"document.badge.gearshape.fill"
//		}
//		else {
//			"app.fill"
//		}
//    }
	
	private var iconAsset: String {
		if fileType.lowercased() == "zip" {
			"zipIcon"
		}
		else if fileType.lowercased() == "dmg" {
			"dmgIcon"
		}
		else if fileType.lowercased() == "pkg" {
			"pkgIcon"
		}
		else {
			"documentIcon"
		}
	}
}
