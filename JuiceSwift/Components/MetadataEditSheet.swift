import SwiftUI
#if os(macOS)
import AppKit
#endif

// Modal metadata editor for downloaded/imported apps.
// Configuration ownership:
// - Header/grid: quick metadata summary.
// - Recipe/scripts sections: editable advanced values.
// - Footer: cancel/save actions.
struct MetadataEditSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme
	@State private var draft: ParsedMetadata
	@State private var selectedIconIndex: Int
	@State private var selectedRecipeKeys: Set<String> = []
	@State private var recipeExpanded: Bool = false
	@State private var scriptsExpanded: Bool = false
	@StateObject private var focusObserver = WindowFocusObserver()

	let download: EditableDownload
	let onSave: (EditableDownload) -> Void
	let onCancel: () -> Void

	init(
		download: EditableDownload,
		onSave: @escaping (EditableDownload) -> Void,
		onCancel: @escaping () -> Void
	) {
		self.download = download
		self.onSave = onSave
		self.onCancel = onCancel
		let initial = download.parsedMetadata ?? ParsedMetadata()
		_draft = State(initialValue: initial)
		if download.iconPaths.isEmpty {
			_selectedIconIndex = State(initialValue: download.selectedIconIndex)
		} else {
			_selectedIconIndex = State(initialValue: 0)
		}
	}

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
	}

	// MARK: - Body

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
		VStack(alignment: .leading, spacing: 16) {
			header
				.padding(.top, 10)
				.padding(.horizontal, 10)
			metadataHeaderGrid
				.padding(.horizontal, 10)
			Divider()
			ScrollView {
				// Editable sections are grouped to mirror queue-review flow.
				VStack(alignment: .leading, spacing: 16) {
					recipeSection
						.padding(.horizontal, 10)
					scriptsSection
						.padding(.horizontal, 10)
					//metadataForm
				}
				.padding(.vertical, 4)
			}
				footer
			}
			.padding(20)
			.frame(minWidth: 600, minHeight: 560)
			.glassCompatSurface(
				in: shape,
				style: .regular,
				context: glassState,
				fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
				fillOpacity: min(
					1,
					GlassThemeTokens.panelBaseTintOpacity(for: glassState)
						+ GlassThemeTokens.panelNeutralOverlayOpacity(for: glassState)
				),
				surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: glassState)
			)
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
			.glassCompatBorder(in: shape, context: glassState, role: .strong)
			.glassCompatShadow(context: glassState, elevation: .panel)
			.background(WindowFocusReader { focusObserver.attach($0) })
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(download.displayName)
				.font(.system(size: 18, weight: .semibold))
			Text("Edit metadata and icons")
				.font(.system(size: 12, weight: .medium))
				.foregroundStyle(.secondary)
		}
	}

	private var metadataHeaderGrid: some View {
		HStack(alignment: .top, spacing: 16) {
			VStack(alignment: .leading, spacing: 10) {
				fieldRow("Name", text: binding(\.name))
				fieldRow("Version", text: binding(\.version))
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			VStack(alignment: .leading, spacing: 8) {
				Text("Selected Icon")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.secondary)
				selectedIconPreview
				if !download.iconPaths.isEmpty {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 8) {
							ForEach(download.iconPaths.indices, id: \.self) { index in
								IconPickerButton(
									iconURL: download.iconPaths[index],
									isSelected: index == selectedIconIndex
								) {
									selectedIconIndex = index
								}
							}
						}
					}
				}
			}
			.frame(width: 220, alignment: .leading)
		}
	}

	private var selectedIconPreview: some View {
		let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
		return shape
			.stroke(GlassThemeTokens.borderColor(for: glassState, role: .standard))
			.background(
				shape
					.fill(GlassThemeTokens.overlayColor(for: glassState, role: .subtle))
			)
			.overlay(
				Group {
					#if os(macOS)
					let iconIndex = download.iconPaths.indices.contains(selectedIconIndex) ? selectedIconIndex : 0
					if download.iconPaths.indices.contains(iconIndex),
					   let image = NSImage(contentsOf: download.iconPaths[iconIndex]) {
						Image(nsImage: image)
							.resizable()
							.scaledToFit()
							.padding(10)
					} else {
						Text("No Icon")
							.font(.system(size: 12))
							.foregroundStyle(.secondary)
					}
					#else
					Text("No Icon")
						.font(.system(size: 12))
						.foregroundStyle(.secondary)
					#endif
				}
			)
			.frame(height: 120)
	}

	private var metadataForm: some View {
		VStack(alignment: .leading, spacing: 10) {
			fieldRow("Display Name", text: binding(\.display_name))
			fieldRow("Description", text: binding(\.description))
			fieldRow("Category", text: binding(\.category))
			fieldRow("Developer", text: binding(\.developer))
			fieldRow("Min OS", text: binding(\.minimum_os_version))
			fieldRow("Max OS", text: binding(\.maximum_os_version))
			fieldRow("Icon Name", text: binding(\.icon_name))
			fieldRow("Unattended Install", text: binding(\.unattended_install))
			fieldRow("Unattended Uninstall", text: binding(\.unattended_uninstall))
			fieldRow("Uninstall Method", text: binding(\.uninstall_method))
			fieldRow("Restart Action", text: binding(\.restart_action))
			fieldRow("Requires", text: arrayBinding(\.requires))
			fieldRow("Blocking Apps", text: arrayBinding(\.blocking_applications))
		}
	}

	private var recipeSection: some View {
		DisclosureGroup(isExpanded: $recipeExpanded) {
			if hasRecipe {
				recipePicker
			} else {
				Text("No recipe metadata available.")
					.font(.system(size: 12))
					.foregroundStyle(.secondary)
			}
		} label: {
			VStack(alignment: .leading, spacing: 2) {
				Text("Recipe Metadata")
					.font(.system(size: 13, weight: .semibold))
				if hasRecipe {
					let count = recipeFields.count
					Text("Configuration Items: \(count)")
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.secondary)
					if let source = download.recipeIdentifier {
						Text("Recipe Source: \(source)")
							.font(.system(size: 11))
							.foregroundStyle(.secondary)
					}
				} else {
					Text("This application has no recipe metadata.")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				}
			}
			}
			.background(
				RoundedRectangle(cornerRadius: 10, style: .continuous)
					.fill(GlassThemeTokens.overlayColor(for: glassState, role: .subtle))
			)
	}

	private var recipePicker: some View {
		let fields = recipeFields
		return VStack(alignment: .leading, spacing: 8) {
			ForEach(fields, id: \.key) { field in
				HStack {
					VStack(alignment: .leading, spacing: 2) {
						Text(field.key)
							.font(.system(size: 12, weight: .semibold))
						Text(field.value)
							.font(.system(size: 11))
							.foregroundStyle(.secondary)
							.lineLimit(2)
					}
					Spacer()
					Toggle("", isOn: Binding(
						get: { selectedRecipeKeys.contains(field.key) },
						set: { isOn in
							if isOn {
								selectedRecipeKeys.insert(field.key)
								field.apply(&draft)
							} else {
								selectedRecipeKeys.remove(field.key)
							}
						}
					))
					.labelsHidden()
				}
					.padding(8)
					.background(
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.fill(
								GlassThemeTokens.overlayColor(
									for: glassState,
									role: .subtle
								)
							)
					)
				}
			}
		.padding(.horizontal, 10)
	}

	private var scriptsSection: some View {
		DisclosureGroup(isExpanded: $scriptsExpanded) {
			VStack(alignment: .leading, spacing: 12) {
				Text("Install Scripts")
					.font(.system(size: 12, weight: .semibold))
				multilineField("Pre-Install Script", text: binding(\.preinstall_script))
				multilineField("Post-Install Script", text: binding(\.postinstall_script))
				Divider()
				Text("Uninstall Scripts")
					.font(.system(size: 12, weight: .semibold))
				multilineField("Pre-Uninstall Script", text: binding(\.preuninstall_script))
				multilineField("Post-Uninstall Script", text: binding(\.postuninstall_script))
				Divider()
				Text("Verification Scripts")
					.font(.system(size: 12, weight: .semibold))
				multilineField("Install Check Script", text: binding(\.installcheck_script))
				multilineField("Uninstall Check Script", text: binding(\.uninstallcheck_script))
			}
				.padding(.horizontal, 10)
				.padding(.top, 10)
		} label: {
			VStack(alignment: .leading, spacing: 2) {
				Text("Add/Edit Scripts")
					.font(.system(size: 13, weight: .semibold))
				Text("Expand to add or edit scripts")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}
		}
			.background(
				RoundedRectangle(cornerRadius: 10, style: .continuous)
					.fill(GlassThemeTokens.overlayColor(for: glassState, role: .subtle))
			)
	}

	private var footer: some View {
		HStack {
			Spacer()
			Button("Cancel") {
				onCancel()
				dismiss()
			}
			.nativeActionButtonStyle(.secondary, controlSize: .large)
			Button("Save") {
				save()
			}
			.nativeActionButtonStyle(.primary, controlSize: .large)
		}
	}

	private func save() {
		var updated = download
		updated.selectedIconIndex = selectedIconIndex
		updated.parsedMetadata = draft
		updated.metadataText = EditableDownload.encodeMetadata(draft)
		updated.metadataError = nil
		onSave(updated)
		dismiss()
	}

	private func binding(_ keyPath: WritableKeyPath<ParsedMetadata, String?>) -> Binding<String> {
		Binding(
			get: { draft[keyPath: keyPath] ?? "" },
			set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
		)
	}

	private func arrayBinding(_ keyPath: WritableKeyPath<ParsedMetadata, [String]?>) -> Binding<String> {
		Binding(
			get: { draft[keyPath: keyPath]?.joined(separator: ", ") ?? "" },
			set: { value in
				let parts = value
					.split(separator: ",")
					.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
					.filter { !$0.isEmpty }
				draft[keyPath: keyPath] = parts.isEmpty ? nil : parts
			}
		)
	}

	private func fieldRow(_ label: String, text: Binding<String>) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(label)
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.secondary)
			TextField(label, text: text)
				.textFieldStyle(.roundedBorder)
		}
	}

	private func multilineField(_ label: String, text: Binding<String>) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(label)
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.secondary)
				TextEditor(text: text)
					.font(.system(.caption, design: .monospaced))
					.frame(minHeight: 80)
					.overlay(
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.strokeBorder(
								GlassThemeTokens.borderColor(
									for: glassState,
									role: .standard
								)
							)
					)
			}
	}

	private var hasRecipe: Bool {
		download.parsedRecipe != nil
	}

	private struct RecipeField {
		let key: String
		let value: String
		let apply: (inout ParsedMetadata) -> Void
	}

	private var recipeFields: [RecipeField] {
		guard let recipe = download.parsedRecipe else { return [] }
		let pkg = recipe.pkgInfo ?? recipe.input?.pkgInfo
		guard let pkg else { return [] }

		var fields: [RecipeField] = []
		if let value = pkg.displayName {
			fields.append(.init(key: "display_name", value: value) { $0.display_name = value })
		}
		if let value = pkg.description {
			fields.append(.init(key: "description", value: value) { $0.description = value })
		}
		if let value = pkg.category {
			fields.append(.init(key: "category", value: value) { $0.category = value })
		}
		if let value = pkg.developer {
			fields.append(.init(key: "developer", value: value) { $0.developer = value })
		}
		if let value = pkg.minimumOsVersion {
			fields.append(.init(key: "minimum_os_version", value: value) { $0.minimum_os_version = value })
		}
		if let value = pkg.maximumOsVersion {
			fields.append(.init(key: "maximum_os_version", value: value) { $0.maximum_os_version = value })
		}
		if let value = pkg.unattendedInstall {
			fields.append(.init(key: "unattended_install", value: value) { $0.unattended_install = value })
		}
		if let value = pkg.unattendedUninstall {
			fields.append(.init(key: "unattended_uninstall", value: value) { $0.unattended_uninstall = value })
		}
		if let value = pkg.uninstallMethod {
			fields.append(.init(key: "uninstall_method", value: value) { $0.uninstall_method = value })
		}
		if let value = pkg.restartAction {
			fields.append(.init(key: "restart_action", value: value) { $0.restart_action = value })
		}
		if let value = pkg.iconName {
			fields.append(.init(key: "icon_name", value: value) { $0.icon_name = value })
		}
		if let value = pkg.requires {
			fields.append(.init(key: "requires", value: value.joined(separator: ", ")) { $0.requires = value })
		}
		if let value = pkg.blockingApplications {
			fields.append(.init(key: "blocking_applications", value: value.joined(separator: ", ")) { $0.blocking_applications = value })
		}
		return fields
	}
}

#Preview("Metadata Edit Sheet") {
	let sample = EditableDownload(
		id: UUID().uuidString,
		displayName: "Slack",
		baseDownload: SuccessfulDownload(
			fileName: "Slack.dmg",
			fileExtension: "dmg",
			fullFilePath: "/Users/pete/Juice/slack/4.46.104/Slack.dmg",
			fullFolderPath: "/Users/pete/Juice/slack/4.46.104"
		),
		iconPaths: [],
		selectedIconIndex: 0,
		parsedMetadata: ParsedMetadata(),
		metadataText: "{}",
		metadataError: nil,
		preparationError: nil,
		recipeIdentifier: "com.github.homebysix.munki.Slack",
		recipeText: nil,
		recipeError: nil,
		parsedRecipe: Recipe(
			id: nil,
			parentRecipe: nil,
			name: "Slack",
			displayName: "Slack",
			copyright: nil,
			identifier: "com.github.homebysix.munki.Slack",
			description: "Slack for teams",
			comment: nil,
			comments: nil,
			pkgInfo: PkgInfo(
				category: "Productivity",
				iconName: nil,
				requires: nil,
				minimumOsVersion: "13.0",
				developer: "Slack Technologies",
				unattendedInstall: "true",
				displayName: "Slack",
				description: "Slack for teams",
				name: "Slack",
				postinstallScript: nil,
				uninstallMethod: nil,
				blockingApplications: nil,
				uninstallScript: nil,
				unattendedUninstall: "true",
				maximumOsVersion: nil,
				postuninstallScript: nil,
				restartAction: nil,
				preinstallScript: nil,
				uninstallable: nil,
				unattendedUnnstall: nil,
				preuninstallScript: nil,
				installerChoicesXML: nil,
				installcheckScript: nil
			),
			input: nil,
			guid: nil
		),
		preinstallScript: "",
		postinstallScript: "",
		preuninstallScript: "",
		postuninstallScript: "",
		installcheckScript: "",
		uninstallcheckScript: nil
	)
		return ZStack {
			JuiceGradient()
				.ignoresSafeArea()
			MetadataEditSheet(
				download: sample,
				onSave: { _ in },
				onCancel: { }
			)
			.frame(width: 600, height: 700)
		}
	}
