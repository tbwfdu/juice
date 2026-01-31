import SwiftUI

private func supportsLiquidGlass() -> Bool {
	if #available(macOS 26.0, iOS 26.0, *) {
		return true
	}
	return false
}

struct SearchResultCard: View {
	@State private var isHovered = false

	let selectedApplication: CaskApplication
	let title: String
	let subtitle: String
	let token: String
	let version: String
	let fileType: String
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
		.autoUpdates,
		.deprecated,
		.disabled
	]

	init(
		selectedApplication: CaskApplication,
		title: String,
		subtitle: String,
		token: String,
		version: String,
		fileType: String,
		actionTitle: String = "Add",
		action: @escaping () -> Void = {}
	) {
		self.selectedApplication = selectedApplication
		self.title = title
		self.subtitle = subtitle
		self.token = token
		self.version = version
		self.fileType = fileType
		self.actionTitle = actionTitle
		self.action = action
	}

	private var content: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .top, spacing: 16) {
				IconByFiletype(applicationFileName: selectedApplication.url)
				VStack(alignment: .leading, spacing: 6) {
					Text(title)
						.font(.system(.title3, weight: .semibold))
						.lineLimit(1)
					Text(subtitle)
						.font(.system(size: 13, weight: .medium))
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				JuiceButtons.primary(actionTitle, action: action)
					.controlSize(.large)
			}

			Divider()
				.opacity(0.6)

			HStack(spacing: 24) {
				JuiceTypography.metaLabel("Token", value: displayToken)
					.lineLimit(1)
					.truncationMode(.middle)
				JuiceTypography.metaLabel("Version", value: version)
					.lineLimit(1)
				JuiceTypography.metaLabel("Filetype", value: displayFileType)
					.lineLimit(1)
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

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		return Group {
		    if #available(macOS 26.0, iOS 26.0, *), supportsLiquidGlass() {
		        // Liquid Glass (OS 26+)
		        GlassEffectContainer {
		            content
		                .padding(16)
						.glassEffect(.regular, in: shape)
		        }
				.shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
				.clipShape(shape)
		    } else {
		        // Fallback for older OS versions
		        content
		            .padding(16)
		            .background(.ultraThinMaterial, in: shape)
		            .overlay(
		                shape.strokeBorder(.white.opacity(0.12))
		            )
				.shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
				.clipShape(shape)
		    }
		}
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
