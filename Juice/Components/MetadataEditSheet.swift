import SwiftUI

#if os(macOS)
	import AppKit
#endif

private struct ConditionalGlassEffectModifier: ViewModifier {
	func body(content: Content) -> some View {
		if #available(macOS 26.0, *) {
			content.glassEffect()
		} else {
			content
		}
	}
}

struct MetadataEditSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.colorScheme) private var colorScheme
	@State private var draft: ParsedMetadata
	@State private var selectedIconIndex: Int
	@State private var editorMode: EditorMode = .form
	@State private var plistText: String
	@State private var plistError: String?
	@State private var additionalFields: [String: AnyCodable] = [:]
	@State private var additionalExpansionState: [String: Bool] = [:]
	@State private var additionalFieldName: String = ""
	@State private var additionalFieldType: AdditionalFieldType = .string
	@State private var numericFieldDraft: [String: String] = [:]
	@State private var numericFieldError: [String: String] = [:]
	@State private var selectedRecipeId: String?
	@State private var activeRecipe: Recipe?
	@State private var recipeSelectionError: String?
	@State private var showRecipePreview: Bool = false
	@State private var isHeaderDetailsExpanded: Bool = true
	@State private var isInstallsSectionExpanded: Bool = true
	@State private var installItemExpansionState: [Int: Bool] = [:]
	@State private var isAdditionalFieldsExpanded: Bool = true
	@State private var isScriptsSectionExpanded: Bool = true
	@StateObject private var focusObserver = WindowFocusObserver()

	let download: EditableDownload
	let onSave: (EditableDownload) -> Void
	let onCancel: () -> Void
	let onSelectRecipe: ((String) -> Recipe?)?

	init(
		download: EditableDownload,
		onSave: @escaping (EditableDownload) -> Void,
		onCancel: @escaping () -> Void,
		onSelectRecipe: ((String) -> Recipe?)? = nil
	) {
		self.download = download
		self.onSave = onSave
		self.onCancel = onCancel
		self.onSelectRecipe = onSelectRecipe
		let initial = download.parsedMetadata ?? ParsedMetadata()
		_draft = State(initialValue: initial)

		let initialRecipeId =
			download.selectedRecipeId ?? download.recipeIdentifier
		_selectedRecipeId = State(initialValue: initialRecipeId)

		var initialRecipe = download.parsedRecipe
		if let rid = initialRecipeId, initialRecipe == nil {
			initialRecipe = onSelectRecipe?(rid)
		}
		_activeRecipe = State(initialValue: initialRecipe)

		if download.iconPaths.isEmpty {
			_selectedIconIndex = State(initialValue: download.selectedIconIndex)
		} else {
			_selectedIconIndex = State(initialValue: 0)
		}
		let initialPlist =
			download.plistText.isEmpty
			? EditableDownload.encodeMetadataPlist(initial)
			: download.plistText
		_plistText = State(initialValue: initialPlist)
		_plistError = State(initialValue: download.plistError)
		_additionalFields = State(
			initialValue: Self.additionalFields(from: initial)
		)
	}

	private enum EditorMode: String, CaseIterable, Identifiable {
		case form = "List"
		case raw = "Raw"
		var id: String { rawValue }

		var icon: String {
			switch self {
			case .form: return "list.bullet.indent"
			case .raw: return "chevron.left.forwardslash.chevron.right"
			}
		}
	}

	private enum AdditionalFieldType: String, CaseIterable, Identifiable {
		case string = "String"
		case number = "Number"
		case bool = "Bool"
		case array = "Array"
		case dictionary = "Dictionary"
		case null = "Null"
		var id: String { rawValue }

		var defaultValue: AnyCodable {
			switch self {
			case .string: return .string("")
			case .number: return .int(0)
			case .bool: return .bool(false)
			case .array: return .array([])
			case .dictionary: return .dictionary([:])
			case .null: return .null
			}
		}
	}

	private enum AdditionalPathComponent: Hashable {
		case key(String)
		case index(Int)
	}

	private typealias AdditionalPath = [AdditionalPathComponent]

	private static let curatedFieldKeys: Set<String> = [
		"name",
		"version",
		"display_name",
		"description",
		"category",
		"developer",
		"minimum_os_version",
		"maximum_os_version",
		"icon_name",
		"unattended_install",
		"unattended_uninstall",
		"uninstall_method",
		"restart_action",
		"requires",
		"blocking_applications",
		"installs",
		"preinstall_script",
		"postinstall_script",
		"preuninstall_script",
		"postuninstall_script",
		"installcheck_script",
		"uninstallcheck_script",
	]

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
		VStack(alignment: .leading, spacing: 16) {
			header
				.padding(.top, 10)
				.padding(.horizontal, 10)
			if isHeaderDetailsExpanded {
				metadataHeaderGrid
					.padding(.horizontal, 10)
					.transition(.move(edge: .top).combined(with: .opacity))
			}
			Divider()
			editorModePicker
				.padding(.horizontal, 10)
			Divider()
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					if editorMode == .form {
						metadataForm
							.padding(.horizontal, 10)
						Divider().padding(.horizontal, 10)
						scriptsSection
							.padding(.horizontal, 10)
						Divider().padding(.horizontal, 10)
						customKeysSection
							.padding(.horizontal, 10)
					} else {
						rawPlistSection
							.padding(.horizontal, 10)
					}
				}
				.padding(.vertical, 4)
			}
			.padding(.top, -8)
			.panelContentScrollChrome(topInset: 8, bottomContentInset: 20)
			footer
		}
		.padding(20)
		.frame(minWidth: 700, minHeight: 620)
		.glassCompatSurface(
			in: shape,
			style: .regular,
			context: glassState,
			fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
			fillOpacity: min(
				1,
				GlassThemeTokens.panelBaseTintOpacity(for: glassState)
					+ GlassThemeTokens.panelNeutralOverlayOpacity(
						for: glassState
					)
			),
			surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(
				for: glassState
			)
		)
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.glassCompatBorder(in: shape, context: glassState, role: .strong)
		.glassCompatShadow(context: glassState, elevation: .panel)
		.background(WindowFocusReader { focusObserver.attach($0) })
		.onChange(of: editorMode) { _, newMode in
			if newMode == .raw {
				plistText = EditableDownload.encodeMetadataPlist(draft)
			} else if let parsed = EditableDownload.decodeMetadataPlist(
				plistText
			) {
				draft = parsed
				refreshAdditionalFieldState(from: parsed)
				plistError = nil
			}
		}
		.animation(.easeInOut(duration: 0.2), value: isHeaderDetailsExpanded)
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top, spacing: 12) {
				VStack(alignment: .leading, spacing: 6) {
					Text(
						draft.display_name ?? draft.name ?? download.displayName
					)
					.font(.system(size: 18, weight: .semibold))
					Text("Edit metadata and icons")
						.font(.system(size: 12, weight: .medium))
						.foregroundStyle(.secondary)
				}
				Spacer()
				Text(isHeaderDetailsExpanded ? "Collapse" : "Expand")
					.font(.system(size: 10, weight: .medium))
					.foregroundStyle(.secondary)
				Button {
					withAnimation(.easeInOut(duration: 0.2)) {
						isHeaderDetailsExpanded.toggle()
					}
				} label: {
					Image(
						systemName: isHeaderDetailsExpanded
							? "chevron.up" : "chevron.down"
					)
					.font(.system(size: 12, weight: .semibold))
				}
				.roundedSecondaryGlassButtonStyle()
				.accessibilityLabel(
					isHeaderDetailsExpanded
						? "Collapse header details" : "Expand header details"
				)
				.help(
					isHeaderDetailsExpanded
						? "Collapse header details" : "Expand header details"
				)
			}
		}
	}

	private var metadataHeaderGrid: some View {
		HStack(alignment: .top, spacing: 16) {
			VStack(alignment: .leading, spacing: 10) {
				fieldRow("Name", id: "name", text: binding(\.name))
				fieldRow("Version", id: "version", text: binding(\.version))

				if !download.recipeCandidates.isEmpty {
					recipePicker
						.padding(.top, 4)
				}

				if let recipeSelectionError {
					Text(recipeSelectionError)
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.red)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			VStack(alignment: .leading, spacing: 8) {
				Text("Application Icons")
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(.secondary)

				iconSelectorGrid
			}
			.frame(width: 220, alignment: .leading)
		}
	}

	private var editorModePicker: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("Editing Mode")
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.secondary)

			HStack {
				//Spacer()
				if #available(macOS 26.0, iOS 16.0, *) {
					LiquidGlassSegmentedPicker(
						items: EditorMode.allCases.map { mode in
							.init(
								title: mode.rawValue,
								icon: mode.icon,
								tag: mode
							)
						},
						selection: $editorMode
					)
				} else {
					Picker("Editor", selection: $editorMode) {
						ForEach(EditorMode.allCases) { mode in
							HStack {
								Image(systemName: mode.icon)
								Text(mode.rawValue)
							}
							.tag(mode)
						}
					}
					.pickerStyle(.segmented)
					.frame(maxWidth: 300)
				}
				Spacer()
			}
		}
	}

	private var iconSelectorGrid: some View {
		let _ = RoundedRectangle(cornerRadius: 12, style: .continuous)
		return ScrollView {
			if download.iconPaths.isEmpty {
				VStack(spacing: 12) {
					Image(systemName: "photo.on.rectangle.angled")
						.font(.system(size: 24))
						.foregroundStyle(.secondary)
					Text("No icons available")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, minHeight: 120)
			} else {
				LazyVGrid(
					columns: [
						GridItem(
							.adaptive(minimum: 50, maximum: 50),
							spacing: 8
						)
					],
					spacing: 8
				) {
					ForEach(download.iconPaths.indices, id: \.self) { index in
						iconSelectionCell(index: index)
					}
				}
				.padding(8)
			}
		}
		.frame(height: 120)
		.glassPanelStyle(cornerRadius: 12)
	}

	private func iconSelectionCell(index: Int) -> some View {
		let isSelected = index == selectedIconIndex
		let url = download.iconPaths[index]

		return Button {
			selectedIconIndex = index
		} label: {
			ZStack {
				#if os(macOS)
					if let image = NSImage(contentsOf: url) {
						Image(nsImage: image)
							.resizable()
							.scaledToFit()
							.padding(4)
					}
				#endif

				if isSelected {
					RoundedRectangle(cornerRadius: 8)
						.stroke(
							JuiceStyleConfig.defaultAccentColor,
							lineWidth: 2
						)
						.background(
							JuiceStyleConfig.defaultAccentColor.opacity(0.1)
						)
				}
			}
			.frame(width: 50, height: 50)
			.background(Color.white.opacity(0.05))
			.cornerRadius(8)
		}
		.buttonStyle(.plain)
	}

	private var metadataForm: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Text("Application Metadata")
					.font(.system(size: 13, weight: .semibold))
				Spacer()
				if hasRecipe {
					Button("Import All Metadata from Recipe") {
						importAllRecipeFields()
					}
					.juiceGradientGlassProminentButtonStyle(controlSize: .small)
				}
			}

			fieldRow(
				"Display Name",
				id: "display_name",
				text: binding(\.display_name)
			)
			fieldRow(
				"Description",
				id: "description",
				text: binding(\.description)
			)
			fieldRow("Category", id: "category", text: binding(\.category))
			fieldRow("Developer", id: "developer", text: binding(\.developer))
			fieldRow(
				"Min OS",
				id: "minimum_os_version",
				text: binding(\.minimum_os_version)
			)
			fieldRow(
				"Max OS",
				id: "maximum_os_version",
				text: binding(\.maximum_os_version)
			)
			fieldRow("Icon Name", id: "icon_name", text: binding(\.icon_name))
			fieldRow(
				"Unattended Install",
				id: "unattended_install",
				text: binding(\.unattended_install)
			)
			fieldRow(
				"Unattended Uninstall",
				id: "unattended_uninstall",
				text: binding(\.unattended_uninstall)
			)
			fieldRow(
				"Uninstall Method",
				id: "uninstall_method",
				text: binding(\.uninstall_method)
			)
			fieldRow(
				"Restart Action",
				id: "restart_action",
				text: binding(\.restart_action)
			)
			fieldRow("Requires", id: "requires", text: arrayBinding(\.requires))
			fieldRow(
				"Blocking Apps",
				id: "blocking_applications",
				text: arrayBinding(\.blocking_applications)
			)

//			HStack {
//				if !hasDraftInstalls {
//					Button("Add Installs Array") { addInstallsArray() }
//						.roundedSecondaryGlassButtonStyle()
//				}
//				Spacer()
//			}
//			if hasRecipe && !hasRecipeInstalls && !hasDraftInstalls {
//				Text("No installs array available in the selected recipe.")
//					.font(.system(size: 11))
//					.foregroundStyle(.secondary)
//			}
			Divider().padding(.top, 10)
			installsSection
		}
	}
	
	private var installsSection: some View {
		DisclosureGroup(isExpanded: $isInstallsSectionExpanded) {
			VStack(alignment: .leading, spacing: 8) {
				if let installs = draft.installs, !installs.isEmpty {
					ForEach(Array(installs.indices), id: \.self) { index in
						DisclosureGroup(
							isExpanded: installItemExpansionBinding(for: index)
						) {
							VStack(alignment: .leading, spacing: 6) {
								installFieldRow(
									"Type",
									text: installBinding(
										at: index,
										keyPath: \.type
									)
								)
								installFieldRow(
									"Path",
									text: installBinding(
										at: index,
										keyPath: \.path
									)
								)
								installFieldRow(
									"CFBundleIdentifier",
									text: installBinding(
										at: index,
										keyPath: \.cfBundleIdentifier
									)
								)
								installFieldRow(
									"CFBundleName",
									text: installBinding(
										at: index,
										keyPath: \.cfBundleName
									)
								)
								installFieldRow(
									"CFBundleShortVersionString",
									text: installBinding(
										at: index,
										keyPath: \.cfBundleShortVersionString
									)
								)
								installFieldRow(
									"CFBundleVersion",
									text: installBinding(
										at: index,
										keyPath: \.cfBundleVersion
									)
								)
								installFieldRow(
									"Min OS Version",
									text: installBinding(
										at: index,
										keyPath: \.minosversion
									)
								)
								installFieldRow(
									"Version Comparison Key",
									text: installBinding(
										at: index,
										keyPath: \.version_comparison_key
									)
								)
							}
							.padding(.top, 6)
						} label: {
							HStack {
								Text("Install \(index + 1)")
									.font(.system(size: 11, weight: .semibold))
									.foregroundStyle(.secondary)
								Spacer()
								Button {
									removeInstall(at: index)
								} label: {
									Image(systemName: "trash")
								}
								.buttonStyle(.plain)
							}
						}
						.padding(10)
						.glassPanelStyle(cornerRadius: 10)
					}
				} else {
					Text(
						"No installs array defined. Use \"Add Installs Array\" to add one."
					)
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
					.padding(.top, 2)
				}
			}
		} label: {
			HStack(alignment: .top, spacing: 10) {
				VStack(alignment: .leading, spacing: 2) {
					HStack(spacing: 8) {
						Text("Installs Array")
							.font(.system(size: 13, weight: .semibold))
						if let count = draft.installs?.count, count > 0 {
							Text("\(count) item\(count == 1 ? "" : "s")")
								.font(.system(size: 11, weight: .medium))
								.foregroundStyle(.secondary)
						}
					}
					Text("Add or edit the entries of the Installs Array")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				}
				Spacer()
				Button("Import Installs") {
					importInstallsFromRecipe()
				}
				.roundedSecondaryGlassButtonStyle()
				.disabled(!hasRecipeInstalls)
				if !hasDraftInstalls {
					Button("Add Installs Array") { addInstallsArray() }
						.roundedSecondaryGlassButtonStyle()
				}
				if hasDraftInstalls {
					Button("Clear") {
						draft.installs = nil
						resetInstallItemExpansionState()
						syncDraftToPlist()
					}
					.roundedSecondaryGlassButtonStyle()
				}
			}
		}
	}

	private func installFieldRow(_ label: String, text: Binding<String>)
		-> some View
	{
		VStack(alignment: .leading, spacing: 3) {
			Text(label)
				.font(.system(size: 10, weight: .semibold))
				.foregroundStyle(.secondary)
			TextField(label, text: text)
				.textFieldStyle(.roundedBorder)
		}
	}

	private var customKeysSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text("Additional Plist Fields")
					.font(.system(size: 13, weight: .semibold))
				Spacer()
				TextField("Field Name", text: $additionalFieldName)
					.textFieldStyle(.roundedBorder)
					.frame(width: 180)
				Picker("Type", selection: $additionalFieldType) {
					ForEach(AdditionalFieldType.allCases) { type in
						Text(type.rawValue).tag(type)
					}
				}
				.frame(width: 120)
				Button("Add Field") {
					addAdditionalField()
					syncDraftToPlist()
				}
				.disabled(
					additionalFieldName.trimmingCharacters(
						in: .whitespacesAndNewlines
					).isEmpty
				)
				.roundedSecondaryGlassButtonStyle()
			}

			DisclosureGroup(isExpanded: $isAdditionalFieldsExpanded) {
				VStack(alignment: .leading, spacing: 8) {
					if sortedAdditionalKeys.isEmpty {
						Text("No additional fields in plist.")
							.font(.system(size: 11))
							.foregroundStyle(.secondary)
					} else {
						ForEach(sortedAdditionalKeys, id: \.self) { key in
							if let value = additionalFields[key] {
								additionalTopLevelFieldRow(
									key: key,
									value: value
								)
							}
						}
					}
				}
			} label: {
				HStack(alignment: .top, spacing: 10) {
					VStack(alignment: .leading, spacing: 2) {
						HStack(spacing: 8) {
							Text("Additional Fields")
								.font(.system(size: 12, weight: .semibold))
							Text(
								"\(sortedAdditionalKeys.count) field\(sortedAdditionalKeys.count == 1 ? "" : "s")"
							)
							.font(.system(size: 11, weight: .medium))
							.foregroundStyle(.secondary)
						}
						Text(
							"Expand to view or edit less commonly used or custom fields"
						)
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
					}
				}
			}
		}
	}

	private var sortedAdditionalKeys: [String] {
		additionalFields.keys.sorted()
	}

	private func addAdditionalField() {
		let trimmed = additionalFieldName.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		guard !trimmed.isEmpty else { return }
		let key = Self.uniqueDictionaryKey(
			base: trimmed,
			existing: Set(additionalFields.keys)
		)
		additionalFields[key] = additionalFieldType.defaultValue
		additionalFieldName = ""
		syncDraftToPlist()
	}

	private func addArrayItem(
		at path: AdditionalPath,
		type: AdditionalFieldType
	) {
		guard case .array(var currentArray)? = value(at: path) else { return }
		currentArray.append(type.defaultValue)
		setAdditionalValue(.array(currentArray), at: path)
	}

	private func addDictionaryEntry(
		at path: AdditionalPath,
		type: AdditionalFieldType
	) {
		guard case .dictionary(var currentDict)? = value(at: path) else {
			return
		}
		let key = Self.uniqueDictionaryKey(
			base: "new_key",
			existing: Set(currentDict.keys)
		)
		currentDict[key] = type.defaultValue
		setAdditionalValue(.dictionary(currentDict), at: path)
	}

	private func additionalTopLevelFieldRow(key: String, value: AnyCodable)
		-> some View
	{
		additionalValueEditor(
			path: [.key(key)],
			label: key,
			value: value,
			showRemove: true
		)
		.padding(10)
		.glassPanelStyle(cornerRadius: 10)
	}

	private func additionalValueEditor(
		path: AdditionalPath,
		label: String,
		value: AnyCodable,
		showRemove: Bool
	) -> AnyView {
		switch value {
		case .array(let items):
			return additionalArrayGroup(
				path: path,
				label: label,
				items: items,
				showRemove: showRemove
			)
		case .dictionary(let dictionary):
			return additionalDictionaryGroup(
				path: path,
				label: label,
				dictionary: dictionary,
				showRemove: showRemove
			)
		default:
			return additionalScalarRow(
				path: path,
				label: label,
				value: value,
				showRemove: showRemove
			)
		}
	}

	private func additionalScalarRow(
		path: AdditionalPath,
		label: String,
		value: AnyCodable,
		showRemove: Bool
	) -> AnyView {
		AnyView(
			VStack(alignment: .leading, spacing: 4) {
				HStack(alignment: .center, spacing: 8) {
					Text(label)
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.secondary)
						.frame(width: 190, alignment: .leading)
					scalarEditor(path: path, value: value)
					if showRemove {
						Button {
							removeAdditionalValue(at: path)
						} label: {
							Image(systemName: "trash")
						}
						.buttonStyle(.plain)
					}
				}
				if let message = numericFieldError[pathID(path)] {
					Text(message)
						.font(.system(size: 10, weight: .semibold))
						.foregroundStyle(.red)
						.padding(.leading, 198)
				}
			}
		)
	}

	@ViewBuilder
	private func scalarEditor(path: AdditionalPath, value: AnyCodable)
		-> some View
	{
		switch value {
		case .string:
			TextField(
				"Value",
				text: Binding(
					get: {
						if case .string(let current)? = self.value(at: path) {
							return current
						}
						return ""
					},
					set: { newValue in
						self.setAdditionalValue(.string(newValue), at: path)
					}
				)
			)
			.textFieldStyle(.roundedBorder)
		case .bool:
			Toggle(
				"",
				isOn: Binding(
					get: {
						if case .bool(let current)? = self.value(at: path) {
							return current
						}
						return false
					},
					set: { newValue in
						self.setAdditionalValue(.bool(newValue), at: path)
					}
				)
			)
			.toggleStyle(.switch)
			.labelsHidden()
		case .int:
			TextField("0", text: numericBinding(for: path, isInteger: true))
				.textFieldStyle(.roundedBorder)
		case .double:
			TextField("0.0", text: numericBinding(for: path, isInteger: false))
				.textFieldStyle(.roundedBorder)
		case .null:
			HStack(spacing: 8) {
				Text("null")
					.font(
						.system(size: 11, weight: .medium, design: .monospaced)
					)
					.foregroundStyle(.secondary)
				Menu("Set Type") {
					ForEach(AdditionalFieldType.allCases) { type in
						Button(type.rawValue) {
							setAdditionalValue(type.defaultValue, at: path)
						}
					}
				}
				.nativeActionButtonStyle(.secondary, controlSize: .small)
			}
		case .array, .dictionary:
			EmptyView()
		}
	}

	private func additionalArrayGroup(
		path: AdditionalPath,
		label: String,
		items: [AnyCodable],
		showRemove: Bool
	) -> AnyView {
		AnyView(
			DisclosureGroup(
				isExpanded: expansionBinding(for: path)
			) {
				VStack(alignment: .leading, spacing: 8) {
					ForEach(items.indices, id: \.self) { index in
						let itemPath = path + [.index(index)]
						additionalValueEditor(
							path: itemPath,
							label: "Item \(index + 1)",
							value: items[index],
							showRemove: true
						)
					}
					Menu("Add Item") {
						ForEach(AdditionalFieldType.allCases) { type in
							Button(type.rawValue) {
								addArrayItem(at: path, type: type)
							}
						}
					}
					.nativeActionButtonStyle(.secondary, controlSize: .small)
				}
				.padding(.top, 6)
			} label: {
				HStack(spacing: 8) {
					Text(label)
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.secondary)
					Text("Array (\(items.count))")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
					Spacer()
					if showRemove {
						Button {
							removeAdditionalValue(at: path)
						} label: {
							Image(systemName: "trash")
						}
						.buttonStyle(.plain)
					}
				}
			}
		)
	}

	private func additionalDictionaryGroup(
		path: AdditionalPath,
		label: String,
		dictionary: [String: AnyCodable],
		showRemove: Bool
	) -> AnyView {
		AnyView(
			DisclosureGroup(
				isExpanded: expansionBinding(for: path)
			) {
				VStack(alignment: .leading, spacing: 8) {
					ForEach(dictionary.keys.sorted(), id: \.self) { key in
						if let value = dictionary[key] {
							additionalValueEditor(
								path: path + [.key(key)],
								label: key,
								value: value,
								showRemove: true
							)
						}
					}
					Menu("Add Key") {
						ForEach(AdditionalFieldType.allCases) { type in
							Button(type.rawValue) {
								addDictionaryEntry(at: path, type: type)
							}
						}
					}
					.nativeActionButtonStyle(.secondary, controlSize: .small)
				}
				.padding(.top, 6)
			} label: {
				HStack(spacing: 8) {
					Text(label)
						.font(.system(size: 11, weight: .semibold))
						.foregroundStyle(.secondary)
					Text("Dictionary (\(dictionary.count))")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
					Spacer()
					if showRemove {
						Button {
							removeAdditionalValue(at: path)
						} label: {
							Image(systemName: "trash")
						}
						.buttonStyle(.plain)
					}
				}
			}
		)
	}

	private func numericBinding(for path: AdditionalPath, isInteger: Bool)
		-> Binding<String>
	{
		let id = pathID(path)
		return Binding(
			get: {
				if let draftValue = numericFieldDraft[id] {
					return draftValue
				}
				if let current = value(at: path) {
					switch current {
					case .int(let number):
						return String(number)
					case .double(let number):
						return String(number)
					default:
						return ""
					}
				}
				return ""
			},
			set: { newValue in
				numericFieldDraft[id] = newValue
				let trimmed = newValue.trimmingCharacters(
					in: .whitespacesAndNewlines
				)
				guard !trimmed.isEmpty else {
					numericFieldError[id] = "Enter a valid number."
					return
				}
				if isInteger {
					guard let intValue = Int(trimmed) else {
						numericFieldError[id] = "Enter a valid integer."
						return
					}
					numericFieldError[id] = nil
					setAdditionalValue(.int(intValue), at: path)
				} else {
					guard let doubleValue = Double(trimmed) else {
						numericFieldError[id] = "Enter a valid number."
						return
					}
					numericFieldError[id] = nil
					setAdditionalValue(.double(doubleValue), at: path)
				}
			}
		)
	}

	private func expansionBinding(for path: AdditionalPath) -> Binding<Bool> {
		let id = pathID(path)
		return Binding(
			get: { additionalExpansionState[id] ?? false },
			set: { additionalExpansionState[id] = $0 }
		)
	}

	private func pathID(_ path: AdditionalPath) -> String {
		var segments: [String] = ["root"]
		for component in path {
			switch component {
			case .key(let key):
				segments.append(".\(key)")
			case .index(let index):
				segments.append("[\(index)]")
			}
		}
		return segments.joined()
	}

	private func value(at path: AdditionalPath) -> AnyCodable? {
		Self.value(at: path, in: additionalFields)
	}

	private func setAdditionalValue(
		_ value: AnyCodable,
		at path: AdditionalPath
	) {
		Self.setValue(value, at: path, in: &additionalFields)
		syncDraftToPlist()
	}

	private func removeAdditionalValue(at path: AdditionalPath) {
		Self.removeValue(at: path, in: &additionalFields)
		let pathPrefix = pathID(path)
		additionalExpansionState = additionalExpansionState.filter { key, _ in
			!key.hasPrefix(pathPrefix)
		}
		numericFieldDraft = numericFieldDraft.filter { key, _ in
			!key.hasPrefix(pathPrefix)
		}
		numericFieldError = numericFieldError.filter { key, _ in
			!key.hasPrefix(pathPrefix)
		}
		syncDraftToPlist()
	}

	private var recipePicker: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				Text("Choose Recipe")
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(.secondary)
				if selectedRecipeId == nil || selectedRecipeId?.isEmpty == true
				{
					Text("(Required)")
						.font(.system(size: 10, weight: .bold))
						.foregroundStyle(JuiceStyleConfig.defaultAccentColor)
				}
			}

			HStack(spacing: 8) {
				Picker(
					"Recipe",
					selection: Binding(
						get: { selectedRecipeId ?? "" },
						set: { newValue in
							if newValue.isEmpty {
								selectedRecipeId = nil
								activeRecipe = nil
								return
							}
							selectedRecipeId = newValue
							recipeSelectionError = nil
							if let resolver = onSelectRecipe {
								if let recipe = resolver(newValue) {
									activeRecipe = recipe
									recipeSelectionError = nil
								} else {
									activeRecipe = nil
									recipeSelectionError =
										"Unable to load the selected recipe."
								}
							}
						}
					)
				) {
					Text("Select a recipe...")
						.tag("")
					ForEach(download.recipeCandidates) { candidate in
						Text(candidate.identifier)
							.tag(candidate.identifier)
					}
				}
				.labelsHidden()
				.overlay(
					RoundedRectangle(cornerRadius: 6)
						.stroke(
							selectedRecipeId == nil
								|| selectedRecipeId?.isEmpty == true
								? JuiceStyleConfig.defaultAccentColor.opacity(
									0.5
								) : Color.clear,
							lineWidth: 1
						)
				)

				if activeRecipe != nil {
					Button("Preview") {
						showRecipePreview = true
					}
					.nativeActionButtonStyle(.secondary, controlSize: .large)
					.help("Preview Recipe")
					.popover(isPresented: $showRecipePreview) {
						recipePreviewPopover
					}
				}
			}
		}
	}

	private var scriptsSection: some View {
		DisclosureGroup(isExpanded: $isScriptsSectionExpanded) {
			VStack(alignment: .leading, spacing: 12) {
				Text("Install Scripts")
					.font(.system(size: 12, weight: .semibold))
				multilineField(
					"Pre-Install Script",
					id: "preinstall_script",
					text: binding(\.preinstall_script)
				)
				multilineField(
					"Post-Install Script",
					id: "postinstall_script",
					text: binding(\.postinstall_script)
				)
				Divider()
				Text("Uninstall Scripts")
					.font(.system(size: 12, weight: .semibold))
				multilineField(
					"Pre-Uninstall Script",
					id: "preuninstall_script",
					text: binding(\.preuninstall_script)
				)
				multilineField(
					"Post-Uninstall Script",
					id: "postuninstall_script",
					text: binding(\.postuninstall_script)
				)
				Divider()
				Text("Verification Scripts")
					.font(.system(size: 12, weight: .semibold))
				multilineField(
					"Install Check Script",
					id: "installcheck_script",
					text: binding(\.installcheck_script)
				)
				multilineField(
					"Uninstall Check Script",
					id: "uninstallcheck_script",
					text: binding(\.uninstallcheck_script)
				)
			}
			.padding(.top, 6)
		} label: {
			VStack(alignment: .leading, spacing: 2) {
				Text("Add/Edit Scripts")
					.font(.system(size: 13, weight: .semibold))
				Text("Add or edit install, uninstall, and verification scripts")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}
		}
	}

	private func installItemExpansionBinding(for index: Int) -> Binding<Bool> {
		Binding(
			get: { installItemExpansionState[index] ?? false },
			set: { installItemExpansionState[index] = $0 }
		)
	}

	private func resetInstallItemExpansionState() {
		installItemExpansionState = [:]
	}

	private var rawPlistSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Raw metadata plist (XML)")
				.font(.system(size: 13, weight: .semibold))
			Text(
				"Edit raw XML directly. Save is disabled until the plist parses successfully."
			)
			.font(.system(size: 11))
			.foregroundStyle(.secondary)
			TextEditor(text: $plistText)
				.font(.system(.caption, design: .monospaced))
				.frame(minHeight: 360)
				.scrollContentBackground(.hidden)
				.background(Color.clear)
				.overlay(
					RoundedRectangle(cornerRadius: 8, style: .continuous)
						.strokeBorder(
							GlassThemeTokens.borderColor(
								for: glassState,
								role: .standard
							)
						)
				)
				.onChange(of: plistText) { _, newValue in
					parseRawPlist(newValue)
				}
			if let plistError {
				Text(plistError)
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(.red)
			}
		}
	}

	private var footer: some View {
		HStack {
			Spacer()
			Button("Cancel") {
				onCancel()
				dismiss()
			}
			.nativeActionButtonStyle(.secondary, controlSize: .large)
			Button("Save") { save() }
				.juiceGradientGlassProminentButtonStyle(controlSize: .large)
				.disabled(editorMode == .raw && plistError != nil)
		}
	}

	private func save() {
		if editorMode == .raw {
			guard let parsed = EditableDownload.decodeMetadataPlist(plistText)
			else {
				plistError =
					"Invalid XML property list. Fix syntax before saving."
				return
			}
			draft = parsed
			refreshAdditionalFieldState(from: parsed)
		}
		syncDraftToPlist()

		var updated = download
		updated.selectedIconIndex = selectedIconIndex
		updated.parsedMetadata = draft
		updated.metadataText = EditableDownload.encodeMetadata(draft)
		updated.metadataError = nil
		updated.plistText = plistText
		updated.plistError = plistError
		updated.isPlistDirty = false
		updated.selectedRecipeId = selectedRecipeId
		updated.recipeIdentifier = selectedRecipeId ?? updated.recipeIdentifier
		onSave(updated)
		dismiss()
	}

	private func parseRawPlist(_ raw: String) {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			plistError = "Metadata plist cannot be empty."
			return
		}
		if let parsed = EditableDownload.decodeMetadataPlist(raw) {
			draft = parsed
			refreshAdditionalFieldState(from: parsed)
			plistError = nil
		} else {
			plistError = "Invalid XML property list. Fix syntax before saving."
		}
	}

	private func refreshAdditionalFieldState(from metadata: ParsedMetadata) {
		additionalFields = Self.additionalFields(from: metadata)
		additionalExpansionState = [:]
		numericFieldDraft = [:]
		numericFieldError = [:]
	}

	private func syncDraftToPlist() {
		guard var mergedDictionary = Self.metadataDictionary(from: draft) else {
			plistError = "Unable to encode metadata plist."
			return
		}
		for key in mergedDictionary.keys
		where !Self.curatedFieldKeys.contains(key) {
			mergedDictionary.removeValue(forKey: key)
		}
		for (key, value) in additionalFields {
			if let plistValue = Self.propertyListValue(from: value) {
				mergedDictionary[key] = plistValue
			} else {
				mergedDictionary.removeValue(forKey: key)
			}
		}
		guard let rebuilt = Self.metadata(from: mergedDictionary) else {
			plistError = "Invalid additional fields. Fix values before saving."
			return
		}
		draft = rebuilt
		let encoded = EditableDownload.encodeMetadataPlist(rebuilt)
		plistText = encoded
		plistError = encoded.isEmpty ? "Unable to encode metadata plist." : nil
	}

	private func addInstallsArray() {
		if draft.installs == nil {
			draft.installs = [
				InstallItem(
					cfBundleIdentifier: nil,
					cfBundleName: nil,
					cfBundleShortVersionString: nil,
					cfBundleVersion: nil,
					minosversion: nil,
					path: nil,
					type: nil,
					version_comparison_key: nil,
					extra: nil
				)
			]
		} else {
			draft.installs?.append(
				InstallItem(
					cfBundleIdentifier: nil,
					cfBundleName: nil,
					cfBundleShortVersionString: nil,
					cfBundleVersion: nil,
					minosversion: nil,
					path: nil,
					type: nil,
					version_comparison_key: nil,
					extra: nil
				)
			)
		}
		resetInstallItemExpansionState()
		syncDraftToPlist()
	}

	private func removeInstall(at index: Int) {
		guard var installs = draft.installs, installs.indices.contains(index)
		else { return }
		installs.remove(at: index)
		draft.installs = installs.isEmpty ? nil : installs
		resetInstallItemExpansionState()
		syncDraftToPlist()
	}

	private func installBinding(
		at index: Int,
		keyPath: WritableKeyPath<InstallItem, String?>
	) -> Binding<String> {
		Binding(
			get: {
				guard let installs = draft.installs,
					installs.indices.contains(index)
				else { return "" }
				return installs[index][keyPath: keyPath] ?? ""
			},
			set: { newValue in
				guard var installs = draft.installs,
					installs.indices.contains(index)
				else { return }
				installs[index][keyPath: keyPath] =
					newValue.isEmpty ? nil : newValue
				draft.installs = installs
				syncDraftToPlist()
			}
		)
	}

	private func importInstallsFromRecipe() {
		guard let installs = recipeInstalls, !installs.isEmpty else { return }
		draft.installs = installs
		resetInstallItemExpansionState()
		syncDraftToPlist()
	}

	private func importAllRecipeFields() {
		importRecipeField("display_name") { value in
			draft.display_name = value
			draft.name = value
		}
		importRecipeField("description") { draft.description = $0 }
		importRecipeField("category") { draft.category = $0 }
		importRecipeField("developer") { draft.developer = $0 }
		importRecipeField("minimum_os_version") {
			draft.minimum_os_version = $0
		}
		importRecipeField("maximum_os_version") {
			draft.maximum_os_version = $0
		}
		importRecipeField("unattended_install") {
			draft.unattended_install = $0
		}
		importRecipeField("unattended_uninstall") {
			draft.unattended_uninstall = $0
		}
		importRecipeField("uninstall_method") { draft.uninstall_method = $0 }
		importRecipeField("restart_action") { draft.restart_action = $0 }
		importRecipeField("icon_name") { draft.icon_name = $0 }
		importRecipeField("requires") { draft.requires = parseCSVList($0) }
		importRecipeField("blocking_applications") {
			draft.blocking_applications = parseCSVList($0)
		}
		importRecipeField("preinstall_script") { draft.preinstall_script = $0 }
		importRecipeField("postinstall_script") {
			draft.postinstall_script = $0
		}
		importRecipeField("preuninstall_script") {
			draft.preuninstall_script = $0
		}
		importRecipeField("postuninstall_script") {
			draft.postuninstall_script = $0
		}
		importRecipeField("installcheck_script") {
			draft.installcheck_script = $0
		}
		importRecipeField("uninstallcheck_script") {
			draft.uninstallcheck_script = $0
		}

		syncDraftToPlist()
	}

	private func importRecipeField(_ key: String, assign: (String) -> Void) {
		guard let value = recipeValue(for: key) else { return }
		assign(value)
	}

	private func parseCSVList(_ value: String) -> [String]? {
		let parts: [String] =
			value
			.split(separator: ",")
			.map {
				String($0).trimmingCharacters(
					in: CharacterSet.whitespacesAndNewlines
				)
			}
			.filter { !$0.isEmpty }
		return parts.isEmpty ? nil : parts
	}

	private func binding(_ keyPath: WritableKeyPath<ParsedMetadata, String?>)
		-> Binding<String>
	{
		Binding(
			get: { draft[keyPath: keyPath] ?? "" },
			set: {
				let newValue = $0.isEmpty ? nil : $0
				draft[keyPath: keyPath] = newValue

				// Sync Name and Display Name
				if keyPath == \.name {
					draft.display_name = newValue
				} else if keyPath == \.display_name {
					draft.name = newValue
				}

				syncDraftToPlist()
			}
		)
	}

	private func arrayBinding(
		_ keyPath: WritableKeyPath<ParsedMetadata, [String]?>
	) -> Binding<String> {
		Binding(
			get: { draft[keyPath: keyPath]?.joined(separator: ", ") ?? "" },
			set: { value in
				let parts =
					value
					.split(separator: ",")
					.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
					.filter { !$0.isEmpty }
				draft[keyPath: keyPath] = parts.isEmpty ? nil : parts
				syncDraftToPlist()
			}
		)
	}

	private func fieldRow(_ label: String, id: String, text: Binding<String>)
		-> some View
	{
		VStack(alignment: .leading, spacing: 4) {
			Text(label)
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.secondary)

			TextField(label, text: text)
				.textFieldStyle(.roundedBorder)

			if let recipeVal = recipeValue(for: id), !recipeVal.isEmpty {
				HStack(spacing: 4) {
					Button {
						text.wrappedValue = recipeVal
					} label: {
						Image(systemName: "plus.circle.fill")
							.font(.system(size: 11))
					}
					.buttonStyle(.plain)
					.foregroundStyle(JuiceStyleConfig.defaultAccentColor)
					.help("Use recipe value")
					Text("Use Recipe Value:")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
						.lineLimit(1)
					Text(recipeVal)
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.secondary)
						.lineLimit(1)

				}
				.padding(.leading, 2)
			}
		}
	}

	private func multilineField(
		_ label: String,
		id: String,
		text: Binding<String>
	) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(label)
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.secondary)

			TextEditor(text: text)
				.font(.system(.caption, design: .monospaced))
				.frame(minHeight: 80)
				.scrollContentBackground(.hidden)
				.padding(.horizontal, 6)
				.padding(.vertical, 4)
				.background(
					RoundedRectangle(cornerRadius: 8, style: .continuous)
						.fill(Color(nsColor: .textBackgroundColor))
				)
				.overlay(
					RoundedRectangle(cornerRadius: 8, style: .continuous)
						.strokeBorder(
							Color(nsColor: .separatorColor),
							lineWidth: 1
						)
				)

			if let recipeVal = recipeValue(for: id), !recipeVal.isEmpty {
				HStack(spacing: 4) {
					Text("Recipe Script Available")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)

					Button {
						text.wrappedValue = recipeVal
					} label: {
						HStack(spacing: 2) {
							Image(systemName: "plus.circle.fill")
							Text("Use Recipe Script")
						}
						.font(.system(size: 11))
					}
					.buttonStyle(.plain)
					.foregroundStyle(JuiceStyleConfig.defaultAccentColor)
					.help("Replace with recipe script")
				}
				.padding(.leading, 2)
			}
		}
	}

	private var hasRecipe: Bool {
		activeRecipe != nil
	}

	private var hasRecipeInstalls: Bool {
		!(recipeInstalls?.isEmpty ?? true)
	}

	private var hasDraftInstalls: Bool {
		!(draft.installs?.isEmpty ?? true)
	}

	private func recipeValue(for key: String) -> String? {
		guard let pkg = activeRecipe?.pkgInfo ?? activeRecipe?.input?.pkgInfo
		else { return nil }
		switch key {
		case "display_name": return pkg.displayName
		case "description": return pkg.description
		case "category": return pkg.category
		case "developer": return pkg.developer
		case "minimum_os_version": return pkg.minimumOsVersion
		case "maximum_os_version": return pkg.maximumOsVersion
		case "unattended_install": return pkg.unattendedInstall
		case "unattended_uninstall": return pkg.unattendedUninstall
		case "uninstall_method": return pkg.uninstallMethod
		case "restart_action": return pkg.restartAction
		case "icon_name": return pkg.iconName
		case "requires": return pkg.requires?.joined(separator: ", ")
		case "blocking_applications":
			return pkg.blockingApplications?.joined(separator: ", ")
		case "preinstall_script": return pkg.preinstallScript
		case "postinstall_script": return pkg.postinstallScript
		case "preuninstall_script": return pkg.preuninstallScript
		case "postuninstall_script": return pkg.postuninstallScript
		case "installcheck_script": return pkg.installcheckScript
		case "uninstallcheck_script": return pkg.uninstallScript  // Munki's uninstall_script is used for check often or vice versa
		default: return nil
		}
	}

	private var recipeInstalls: [InstallItem]? {
		let pkg = activeRecipe?.pkgInfo ?? activeRecipe?.input?.pkgInfo
		return pkg?.installs
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

	private var recipePreviewPopover: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text("Recipe Content")
					.font(.system(size: 13, weight: .semibold))
				Spacer()
				Button("Copy") {
					if let recipe = activeRecipe {
						NSPasteboard.general.clearContents()
						NSPasteboard.general.setString(
							recipePrettyPrintedJSON(recipe),
							forType: .string
						)
					}
				}
				.nativeActionButtonStyle(.secondary, controlSize: .small)
			}
			.padding(.bottom, 4)

			if let recipe = activeRecipe {
				ScrollView {
					Text(recipePrettyPrintedJSON(recipe))
						.font(.system(.caption, design: .monospaced))
						.padding(8)
						.frame(maxWidth: .infinity, alignment: .leading)
						.textSelection(.enabled)
				}
				.background(Color.black.opacity(0.1))
				.cornerRadius(8)
			}
		}
		.padding(16)
		.frame(width: 480, height: 600)
	}

	private static func additionalFields(from metadata: ParsedMetadata)
		-> [String: AnyCodable]
	{
		guard let dictionary = metadataDictionary(from: metadata) else {
			return [:]
		}
		var result: [String: AnyCodable] = [:]
		for key in dictionary.keys.sorted() {
			guard !curatedFieldKeys.contains(key) else { continue }
			guard let converted = anyCodable(from: dictionary[key] as Any)
			else { continue }
			result[key] = converted
		}
		return result
	}

	private static func metadataDictionary(from metadata: ParsedMetadata)
		-> [String: Any]?
	{
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .xml
		guard
			let data = try? encoder.encode(metadata),
			let plist = try? PropertyListSerialization.propertyList(
				from: data,
				options: [],
				format: nil
			),
			let dictionary = plist as? [String: Any]
		else {
			return nil
		}
		return dictionary
	}

	private static func metadata(from dictionary: [String: Any])
		-> ParsedMetadata?
	{
		guard
			PropertyListSerialization.propertyList(dictionary, isValidFor: .xml)
		else {
			return nil
		}
		guard
			let data = try? PropertyListSerialization.data(
				fromPropertyList: dictionary,
				format: .xml,
				options: 0
			)
		else {
			return nil
		}
		return try? PropertyListDecoder().decode(
			ParsedMetadata.self,
			from: data
		)
	}

	private static func anyCodable(from value: Any) -> AnyCodable? {
		switch value {
		case let string as String:
			return .string(string)
		case let number as NSNumber:
			if CFGetTypeID(number) == CFBooleanGetTypeID() {
				return .bool(number.boolValue)
			}
			let doubleValue = number.doubleValue
			let intValue = number.intValue
			if Double(intValue) == doubleValue {
				return .int(intValue)
			}
			return .double(doubleValue)
		case let array as [Any]:
			return .array(array.compactMap { anyCodable(from: $0) })
		case let dictionary as [String: Any]:
			var converted: [String: AnyCodable] = [:]
			for (key, nestedValue) in dictionary {
				guard let nested = anyCodable(from: nestedValue) else {
					continue
				}
				converted[key] = nested
			}
			return .dictionary(converted)
		case let date as Date:
			return .string(ISO8601DateFormatter().string(from: date))
		case let data as Data:
			return .string(data.base64EncodedString())
		case is NSNull:
			return .null
		default:
			return nil
		}
	}

	private static func propertyListValue(from value: AnyCodable) -> Any? {
		switch value {
		case .string(let string):
			return string
		case .int(let intValue):
			return intValue
		case .double(let doubleValue):
			return doubleValue
		case .bool(let boolValue):
			return boolValue
		case .array(let values):
			return values.compactMap { propertyListValue(from: $0) }
		case .dictionary(let dictionary):
			var result: [String: Any] = [:]
			for (key, nestedValue) in dictionary {
				if let plistValue = propertyListValue(from: nestedValue) {
					result[key] = plistValue
				}
			}
			return result
		case .null:
			return nil
		}
	}

	private static func uniqueDictionaryKey(base: String, existing: Set<String>)
		-> String
	{
		if !existing.contains(base) {
			return base
		}
		var counter = 2
		while existing.contains("\(base)_\(counter)") {
			counter += 1
		}
		return "\(base)_\(counter)"
	}

	private static func value(
		at path: AdditionalPath,
		in root: [String: AnyCodable]
	) -> AnyCodable? {
		guard !path.isEmpty else { return nil }
		var current: AnyCodable = .dictionary(root)
		for component in path {
			switch (component, current) {
			case (.key(let key), .dictionary(let dictionary)):
				guard let next = dictionary[key] else { return nil }
				current = next
			case (.index(let index), .array(let array)):
				guard array.indices.contains(index) else { return nil }
				current = array[index]
			default:
				return nil
			}
		}
		return current
	}

	private static func setValue(
		_ value: AnyCodable,
		at path: AdditionalPath,
		in root: inout [String: AnyCodable]
	) {
		guard !path.isEmpty else { return }
		var node: AnyCodable = .dictionary(root)
		setValue(value, at: path[...], in: &node)
		if case .dictionary(let dictionary) = node {
			root = dictionary
		}
	}

	private static func setValue(
		_ value: AnyCodable,
		at path: ArraySlice<AdditionalPathComponent>,
		in node: inout AnyCodable
	) {
		guard let component = path.first else {
			node = value
			return
		}
		let remainder = path.dropFirst()
		switch component {
		case .key(let key):
			guard case .dictionary(var dictionary) = node else { return }
			if remainder.isEmpty {
				dictionary[key] = value
			} else {
				guard var child = dictionary[key] else { return }
				setValue(value, at: remainder, in: &child)
				dictionary[key] = child
			}
			node = .dictionary(dictionary)
		case .index(let index):
			guard case .array(var array) = node, array.indices.contains(index)
			else { return }
			if remainder.isEmpty {
				array[index] = value
			} else {
				var child = array[index]
				setValue(value, at: remainder, in: &child)
				array[index] = child
			}
			node = .array(array)
		}
	}

	private static func removeValue(
		at path: AdditionalPath,
		in root: inout [String: AnyCodable]
	) {
		guard !path.isEmpty else { return }
		var node: AnyCodable = .dictionary(root)
		removeValue(at: path[...], in: &node)
		if case .dictionary(let dictionary) = node {
			root = dictionary
		}
	}

	private static func removeValue(
		at path: ArraySlice<AdditionalPathComponent>,
		in node: inout AnyCodable
	) {
		guard let component = path.first else { return }
		let remainder = path.dropFirst()
		switch component {
		case .key(let key):
			guard case .dictionary(var dictionary) = node else { return }
			if remainder.isEmpty {
				dictionary.removeValue(forKey: key)
			} else if var child = dictionary[key] {
				removeValue(at: remainder, in: &child)
				dictionary[key] = child
			}
			node = .dictionary(dictionary)
		case .index(let index):
			guard case .array(var array) = node, array.indices.contains(index)
			else { return }
			if remainder.isEmpty {
				array.remove(at: index)
			} else {
				var child = array[index]
				removeValue(at: remainder, in: &child)
				array[index] = child
			}
			node = .array(array)
		}
	}
}

extension View {
	@ViewBuilder
	fileprivate func roundedSecondaryGlassButtonStyle() -> some View {
		if #available(macOS 26.0, *) {
			self
				.buttonStyle(.glass)
				.controlSize(.small)
				.clipShape(Capsule())
		} else {
			self.nativeActionButtonStyle(.secondary, controlSize: .small)
		}
	}
}

#Preview("Metadata Edit Sheet - Google Chrome") {
	let chromeRecipe = Recipe(
		identifier: "com.github.autopkg.munki.googlechrome",
		description:
			"Downloads the latest Google Chrome disk image and imports it into Munki.",
		pkgInfo: PkgInfo(
			category: "Web Browsers",
			iconName: nil,
			requires: nil,
			installs: nil,
			minimumOsVersion: "11.0",
			developer: "Google LLC",
			unattendedInstall: "true",
			displayName: "Google Chrome",
			description: "Google's web browser.",
			name: "GoogleChrome",
			postinstallScript: nil,
			uninstallMethod: nil,
			blockingApplications: nil,
			uninstallScript: nil,
			unattendedUninstall: nil,
			maximumOsVersion: nil,
			postuninstallScript: nil,
			restartAction: nil,
			preinstallScript: nil,
			uninstallable: nil,
			unattendedUnnstall: nil,
			preuninstallScript: nil,
			installerChoicesXML: nil,
			installcheckScript: nil
		)
	)

	let chromeMetadata: ParsedMetadata = {
		var metadata = ParsedMetadata()
		metadata.name = "GoogleChrome"
		metadata.display_name = "Google Chrome"
		metadata.version = "133.0.6943.127"
		metadata.description = "Web Browser"
		metadata.category = "Browsers"
		metadata.developer = "Google"
		metadata.minimum_os_version = "11.0"
		return metadata
	}()

	let sample = EditableDownload(
		id: UUID().uuidString,
		displayName: "Google Chrome",
		baseDownload: SuccessfulDownload(
			fileName: "googlechrome.dmg",
			fileExtension: "dmg",
			fullFilePath:
				"/Users/pete/Juice/googlechrome/133.0.6943.127/googlechrome.dmg",
			fullFolderPath: "/Users/pete/Juice/googlechrome/133.0.6943.127"
		),
		iconPaths: [],
		selectedIconIndex: 0,
		parsedMetadata: chromeMetadata,
		metadataText: "{}",
		metadataError: nil,
		preparationError: nil,
		recipeIdentifier: "com.github.autopkg.munki.googlechrome",
		recipeCandidates: [
			RecipeMatchCandidate(
				displayName: "Google Chrome (Munki)",
				identifier: "com.github.autopkg.munki.googlechrome",
				score: 100,
				matchedOn: "name"
			),
			RecipeMatchCandidate(
				displayName: "Google Chrome (Pkg)",
				identifier: "com.github.autopkg.pkg.googlechrome",
				score: 85,
				matchedOn: "token"
			),
		],
		selectedRecipeId: "com.github.autopkg.munki.googlechrome",
		recipeText: nil,
		recipeError: nil,
		parsedRecipe: chromeRecipe,
		plistText: "",
		plistError: nil,
		isPlistDirty: false,
		preinstallScript: "",
		postinstallScript: "",
		preuninstallScript: "",
		postuninstallScript: "",
		installcheckScript: "",
		uninstallcheckScript: nil
	)

	ZStack {
		JuiceGradient()
			.ignoresSafeArea()
		MetadataEditSheet(
			download: sample,
			onSave: { _ in },
			onCancel: {},
			onSelectRecipe: { id in
				if id == "com.github.autopkg.munki.googlechrome" {
					return chromeRecipe
				}
				return nil
			}
		)
		.frame(width: 700, height: 760)
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
		recipeCandidates: [
			RecipeMatchCandidate(
				displayName: "Slack",
				identifier: "com.github.homebysix.munki.Slack",
				score: 100,
				matchedOn: "name"
			)
		],
		selectedRecipeId: "com.github.homebysix.munki.Slack",
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
				installs: nil,
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
		plistText: "",
		plistError: nil,
		isPlistDirty: false,
		preinstallScript: "",
		postinstallScript: "",
		preuninstallScript: "",
		postuninstallScript: "",
		installcheckScript: "",
		uninstallcheckScript: nil
	)
	ZStack {
		JuiceGradient()
			.ignoresSafeArea()
		MetadataEditSheet(
			download: sample,
			onSave: { _ in },
			onCancel: {}
		)
		.frame(width: 700, height: 760)
	}
}
