import SwiftUI

#if os(macOS)
	import AppKit
#endif

enum AddEnvironmentStep: String, CaseIterable, Identifiable {
	case basics
	case credentials

	var id: String { rawValue }

	var title: String {
		switch self {
		case .basics: return "Basics"
		case .credentials: return "Credentials"
		}
	}
}

struct SettingsView: View {
	let model: PageViewData
	@State private var activeEnvironmentIndex: Int
	@State private var selectedEnvironmentIndex: Int
	@State private var storedEnvironments: [UemEnvironment]
	@State private var draftEnvironments: [UemEnvironment]
	@State private var editingEnvironmentIndex: Int?
	@State private var showClientSecret: Bool = false
	@State private var orgGroups: [OrganizationGroup] = []
	@State private var infoBarState: SettingsInfoBarState? = nil
	@State private var settingsStore: SettingsStore
	@State private var settingsState: SettingsStore.SettingsState
	@State private var showAdvancedDbSettings: Bool = false
	@State private var databaseServerOverride: String
	@State private var databaseVersionEndpointOverride: String
	@State private var databaseDownloadEndpointOverride: String
	@State private var showResetConfirmation: Bool = false
	@State private var showRemoveEnvironmentConfirmation: Bool = false
	@State private var showAddEnvironmentWizard: Bool = false
	@State private var newEnvironmentDraft: UemEnvironment = UemEnvironment()
	@State private var wizardStep: AddEnvironmentStep = .basics
	@State private var wizardErrorMessage: String? = nil

	private let oauthRegions: [String] = [
		"https://apac.uemauth.workspaceone.com",
		"https://uat.uemauth.workspaceone.com",
		"https://na.uemauth.workspaceone.com",
		"https://emea.uemauth.workspaceone.com",
	]

	init(model: PageViewData) {
		self.model = model
		let store = SettingsStore()
		let loadedState = store.load()
		let seededEnvs = SettingsView.seededEnvironments(
			from: loadedState,
			fallback: model
		)
		let activeIndex = SettingsView.activeIndex(
			for: loadedState.activeEnvironmentUuid
				?? model.settings.activeEnvironmentUuid,
			in: seededEnvs
		)
		_activeEnvironmentIndex = State(initialValue: activeIndex)
		_selectedEnvironmentIndex = State(initialValue: activeIndex)
		_storedEnvironments = State(initialValue: seededEnvs)
		_draftEnvironments = State(initialValue: seededEnvs)
		_editingEnvironmentIndex = State(initialValue: nil)
		_settingsStore = State(initialValue: store)
		_settingsState = State(initialValue: loadedState)
		_showAdvancedDbSettings = State(initialValue: false)
		_databaseServerOverride = State(initialValue: "")
		_databaseVersionEndpointOverride = State(initialValue: "")
		_databaseDownloadEndpointOverride = State(initialValue: "")
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			SettingsGlassPanel {
				VStack(alignment: .leading, spacing: 12) {
					VStack(alignment: .leading, spacing: 4) {
						Text("Settings")
							.font(.title2.weight(.semibold))
					}

					if let infoBarState {
						SettingsInfoBar(state: infoBarState)
					}

					singlePageContent
						.padding(.top, 2)
				}
				.frame(maxWidth: .infinity, alignment: .topLeading)
				.padding(.top, 14)
			}
		}
		.padding(.horizontal, 14)
		.padding(.bottom, 14)
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.buttonStyle(GlassButtonStyle())
		.alert("Reset App Configuration?", isPresented: $showResetConfirmation)
		{
			Button("Reset", role: .destructive) {
				resetAppConfiguration()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text(
				"This clears saved settings and secrets. This can’t be undone."
			)
		}
		.alert(
			"Remove Environment?",
			isPresented: $showRemoveEnvironmentConfirmation
		) {
			Button("Remove", role: .destructive) {
				removeEnvironment()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This will delete the selected environment configuration.")
		}
		.sheet(isPresented: $showAddEnvironmentWizard) {
			AddEnvironmentWizard(
				step: $wizardStep,
				draft: $newEnvironmentDraft,
				errorMessage: $wizardErrorMessage,
				orgGroupOptions: orgGroupOptions,
				oauthRegions: oauthRegions,
				onLookupOrgGroupUuid: lookupWizardOrgGroupUuid,
				onCancel: cancelAddEnvironmentWizard,
				onBack: wizardStepBack,
				onNext: wizardStepForward,
				onSave: commitNewEnvironment
			)
			.frame(minWidth: 520, minHeight: 420)
		}
		.task {
			await loadSettingsFromDisk()
			await importLegacySettingsIfNeeded()
		}
	}

	private var singlePageContent: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				if !isConfigured {
					SettingsInfoBar(
						state: .warning(
							title: "Configuration Required",
							message: "Add your first UEM Environment to finish setup."
						)
					)
				}

				DisclosureGroup("Environments") {
					VStack(alignment: .leading, spacing: 12) {
						SettingRow(title: "Selected Environment") {
							Picker("Selected Environment", selection: $selectedEnvironmentIndex) {
								ForEach(draftEnvironments.indices, id: \.self) { index in
									Text(environmentTitle(for: index)).tag(index)
								}
							}
							.pickerStyle(.menu)
							.labelsHidden()
						}

						HStack(spacing: 12) {
							Button("Add Environment") { beginAddEnvironmentWizard() }
							Button("Remove Environment") { showRemoveEnvironmentConfirmation = true }
								.disabled(!canRemoveEnvironment)
							Button("Reimport Legacy Settings") { reimportLegacySettings() }
						}
					}
					.padding(.top, 8)
				}

				DisclosureGroup("Status") {
					VStack(alignment: .leading, spacing: 10) {
						HStack {
							Text("Active Environment")
							Spacer()
							Text(environmentTitle(for: activeEnvironmentIndex))
								.foregroundStyle(.secondary)
						}
						if !isActiveSelectedEnvironment {
							Button("Set Active Environment") {
								setActiveEnvironment(at: selectedEnvironmentIndex)
							}
						}
					}
					.padding(.top, 8)
				}

				DisclosureGroup("Environment Details") {
					VStack(alignment: .leading, spacing: 12) {
						TextField("Friendly Name", text: selectedEnvironmentBinding.friendlyName)
							.textFieldStyle(.roundedBorder)
							.disabled(!isEditingSelectedEnvironment)
						TextField("UEM URL", text: selectedEnvironmentBinding.uemUrl)
							.textFieldStyle(.roundedBorder)
							.disabled(!isEditingSelectedEnvironment)
						TextField("Client ID", text: selectedEnvironmentBinding.clientId)
							.textFieldStyle(.roundedBorder)
							.disabled(!isEditingSelectedEnvironment)

						if showClientSecret {
							TextField("Client Secret", text: selectedEnvironmentBinding.clientSecret)
								.textFieldStyle(.roundedBorder)
								.disabled(!isEditingSelectedEnvironment)
						} else {
							SecureField("Client Secret", text: selectedEnvironmentBinding.clientSecret)
								.textFieldStyle(.roundedBorder)
								.disabled(!isEditingSelectedEnvironment)
						}
						Toggle("Show Client Secret", isOn: $showClientSecret)

						Picker("OAuth Region", selection: selectedEnvironmentBinding.oauthRegion) {
							ForEach(normalizedOptions(oauthRegions, current: selectedEnvironmentBinding.wrappedValue.oauthRegion), id: \.self) { option in
								Text(option).tag(option)
							}
						}
						.disabled(!isEditingSelectedEnvironment)

						Picker("Organization Group", selection: selectedEnvironmentBinding.orgGroupName) {
							ForEach(normalizedOptions(orgGroupOptions, current: selectedEnvironmentBinding.wrappedValue.orgGroupName), id: \.self) { option in
								Text(option).tag(option)
							}
						}
						.disabled(!isEditingSelectedEnvironment)
						.onChange(of: selectedEnvironmentBinding.wrappedValue.orgGroupName) { _, newValue in
							handleOrgGroupSelection(newValue)
						}

						Button("Reload Org Groups") { reloadOrgGroups() }
							.disabled(!isEditingSelectedEnvironment)

						TextField("Org Group ID", text: selectedEnvironmentBinding.orgGroupId)
							.textFieldStyle(.roundedBorder)
							.disabled(true)
						TextField("Org Group UUID", text: selectedEnvironmentBinding.orgGroupUuid)
							.textFieldStyle(.roundedBorder)
							.disabled(true)

						HStack {
							Spacer()
							if isEditingSelectedEnvironment {
								Button("Cancel") { cancelEnvironmentEdits() }
								Button("Clear") { clearSelectedEnvironment() }
								Button("Save") { saveEnvironmentEdits() }
									.buttonStyle(.borderedProminent)
							} else {
								Button("Edit") { beginEnvironmentEditing() }
							}
						}
					}
					.padding(.top, 8)
				}

				DisclosureGroup("Validation") {
					Button("Run Validation") { runValidation() }
						.padding(.top, 8)
				}

				DisclosureGroup("Database") {
					VStack(alignment: .leading, spacing: 12) {
						HStack {
							Text("Database Version")
							Spacer()
							Text(model.settings.databaseVersion)
								.foregroundStyle(.secondary)
						}

						HStack(spacing: 12) {
							Button("Update Database") { updateDatabase() }
							Button("Show Logs Window") { showLogsWindow() }
							Button("Delete All Apps") { deleteAllApps() }
						}

						DisclosureGroup("Advanced", isExpanded: $showAdvancedDbSettings) {
							VStack(alignment: .leading, spacing: 12) {
								TextField("Database Server URL", text: $databaseServerOverride, prompt: Text(settingsState.databaseServerUrl ?? "https://example.com"))
									.textFieldStyle(.roundedBorder)
								TextField("Database Version Endpoint", text: $databaseVersionEndpointOverride, prompt: Text(settingsState.databaseVersionEndpoint ?? "/version"))
									.textFieldStyle(.roundedBorder)
								TextField("Database Download Endpoint", text: $databaseDownloadEndpointOverride, prompt: Text(settingsState.databaseDownloadEndpoint ?? "https://example.com/manifest.json"))
									.textFieldStyle(.roundedBorder)

								HStack {
									Button("Save Advanced Settings") { applyAdvancedDatabaseSettings() }
										.buttonStyle(.borderedProminent)
									Button("Reset App Configuration") {
										showResetConfirmation = true
									}
								}
							}
							.padding(.top, 8)
						}
					}
					.padding(.top, 8)
				}

				DisclosureGroup("About") {
					VStack(alignment: .leading, spacing: 10) {
						HStack {
							Text("App Version")
							Spacer()
							Text(model.settings.appVersion)
								.foregroundStyle(.secondary)
						}
						HStack {
							Text("Database Version")
							Spacer()
							Text(model.settings.databaseVersion)
								.foregroundStyle(.secondary)
						}
					}
					.padding(.top, 8)
				}
			}
			.padding(.bottom, 8)
		}
	}

	private var canRemoveEnvironment: Bool {
		draftEnvironments.count > 1
	}

	private var isConfigured: Bool {
		draftEnvironments.contains {
			!$0.uemUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		}
	}

	private var isEditingSelectedEnvironment: Bool {
		editingEnvironmentIndex == selectedEnvironmentIndex
	}

	private var isActiveSelectedEnvironment: Bool {
		activeEnvironmentIndex == selectedEnvironmentIndex
	}

	private func environmentTitle(for index: Int) -> String {
		let env = draftEnvironments[safe: index] ?? UemEnvironment()
		if !env.friendlyName.trimmingCharacters(in: .whitespacesAndNewlines)
			.isEmpty
		{
			return env.friendlyName
		}
		if index == 0 { return "Primary" }
		if index == 1 { return "Secondary" }
		return "Environment \(index + 1)"
	}

	private var selectedEnvironmentBinding: Binding<UemEnvironment> {
		Binding(
			get: {
				draftEnvironments[safe: selectedEnvironmentIndex]
					?? UemEnvironment()
			},
			set: { updated in
				guard
					draftEnvironments.indices.contains(selectedEnvironmentIndex)
				else { return }
				draftEnvironments[selectedEnvironmentIndex] = updated
			}
		)
	}

	private var orgGroupOptions: [String] {
		let names = orgGroups.compactMap {
			$0.name?.trimmingCharacters(in: .whitespacesAndNewlines)
		}
		return names.isEmpty ? [] : names
	}

	private var settingsUemDetail: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				if !isConfigured {
					SettingsInfoBar(
						state: .warning(
							title: "Configuration Required",
							message:
								"Add your first UEM Environment to finish setup."
						)
					)
				}

				SettingsGroup(title: "Status") {
					HStack {
						Text("Active Environment")
						Spacer()
						Text(environmentTitle(for: activeEnvironmentIndex))
							.foregroundStyle(.secondary)
					}
					if !isActiveSelectedEnvironment {
						Button("Set Active Environment") {
							setActiveEnvironment(at: selectedEnvironmentIndex)
						}
					}
				}

				SettingsGroup(title: "Environments") {
					SettingRow(title: "Selected Environment") {
						Picker(
							"Selected Environment",
							selection: $selectedEnvironmentIndex
						) {
							ForEach(draftEnvironments.indices, id: \.self) {
								index in
								Text(environmentTitle(for: index)).tag(index)
							}
						}
						.pickerStyle(.menu)
						.labelsHidden()
					}

					HStack(spacing: 12) {
						Button("Add Environment") {
							beginAddEnvironmentWizard()
						}
						Button("Remove Environment") {
							showRemoveEnvironmentConfirmation = true
						}
						.disabled(!canRemoveEnvironment)
						Button("Reimport Legacy Settings") {
							reimportLegacySettings()
						}
					}
				}

				SettingsGroup(title: "Environment Details") {
					TextField(
						"Friendly Name",
						text: selectedEnvironmentBinding.friendlyName
					)
					.textFieldStyle(.roundedBorder)
					.disabled(!isEditingSelectedEnvironment)
					TextField(
						"UEM URL",
						text: selectedEnvironmentBinding.uemUrl
					)
					.textFieldStyle(.roundedBorder)
					.disabled(!isEditingSelectedEnvironment)
					TextField(
						"Client ID",
						text: selectedEnvironmentBinding.clientId
					)
					.textFieldStyle(.roundedBorder)
					.disabled(!isEditingSelectedEnvironment)

					if showClientSecret {
						TextField(
							"Client Secret",
							text: selectedEnvironmentBinding.clientSecret
						)
						.textFieldStyle(.roundedBorder)
						.disabled(!isEditingSelectedEnvironment)
					} else {
						SecureField(
							"Client Secret",
							text: selectedEnvironmentBinding.clientSecret
						)
						.textFieldStyle(.roundedBorder)
						.disabled(!isEditingSelectedEnvironment)
					}
					Toggle("Show Client Secret", isOn: $showClientSecret)

					Picker(
						"OAuth Region",
						selection: selectedEnvironmentBinding.oauthRegion
					) {
						ForEach(
							normalizedOptions(
								oauthRegions,
								current: selectedEnvironmentBinding.wrappedValue
									.oauthRegion
							),
							id: \.self
						) { option in
							Text(option).tag(option)
						}
					}
					.disabled(!isEditingSelectedEnvironment)

					Picker(
						"Organization Group",
						selection: selectedEnvironmentBinding.orgGroupName
					) {
						ForEach(
							normalizedOptions(
								orgGroupOptions,
								current: selectedEnvironmentBinding.wrappedValue
									.orgGroupName
							),
							id: \.self
						) { option in
							Text(option).tag(option)
						}
					}
					.disabled(!isEditingSelectedEnvironment)
					.onChange(
						of: selectedEnvironmentBinding.wrappedValue.orgGroupName
					) { _, newValue in
						handleOrgGroupSelection(newValue)
					}

					Button("Reload Org Groups") { reloadOrgGroups() }
						.disabled(!isEditingSelectedEnvironment)

					TextField(
						"Org Group ID",
						text: selectedEnvironmentBinding.orgGroupId
					)
					.textFieldStyle(.roundedBorder)
					.disabled(true)
					TextField(
						"Org Group UUID",
						text: selectedEnvironmentBinding.orgGroupUuid
					)
					.textFieldStyle(.roundedBorder)
					.disabled(true)
				}

				HStack {
					Spacer()
					if isEditingSelectedEnvironment {
						Button("Cancel") { cancelEnvironmentEdits() }
						Button("Clear") { clearSelectedEnvironment() }
						Button("Save") { saveEnvironmentEdits() }
							.buttonStyle(.borderedProminent)
					} else {
						Button("Edit") { beginEnvironmentEditing() }
					}
				}

				SettingsGroup(title: "Validation") {
					Button("Run Validation") { runValidation() }
				}
			}
			.padding(.bottom, 8)
		}
		.background(Color.clear)
	}

	private var settingsDatabaseDetail: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				SettingsGroup(title: "Status") {
					HStack {
						Text("Database Version")
						Spacer()
						Text(model.settings.databaseVersion)
							.foregroundStyle(.secondary)
					}
				}

				SettingsGroup(title: "Actions") {
					HStack(spacing: 12) {
						Button("Update Database") { updateDatabase() }
						Button("Show Logs Window") { showLogsWindow() }
						Button("Delete All Apps") { deleteAllApps() }
					}
				}

				SettingsGroup {
					DisclosureGroup(
						"Advanced",
						isExpanded: $showAdvancedDbSettings
					) {
						TextField(
							"Database Server URL",
							text: $databaseServerOverride,
							prompt: Text(
								settingsState.databaseServerUrl
									?? "https://example.com"
							)
						)
						.textFieldStyle(.roundedBorder)
						TextField(
							"Database Version Endpoint",
							text: $databaseVersionEndpointOverride,
							prompt: Text(
								settingsState.databaseVersionEndpoint
									?? "/version"
							)
						)
						.textFieldStyle(.roundedBorder)
						TextField(
							"Database Download Endpoint",
							text: $databaseDownloadEndpointOverride,
							prompt: Text(
								settingsState.databaseDownloadEndpoint
									?? "https://example.com/manifest.json"
							)
						)
						.textFieldStyle(.roundedBorder)

						HStack {
							Button("Save Advanced Settings") {
								applyAdvancedDatabaseSettings()
							}
							.buttonStyle(.borderedProminent)
							Button("Reset App Configuration") {
								showResetConfirmation = true
							}
						}
					}
				}
			}
			.padding(.bottom, 8)
		}
		.background(Color.clear)
	}

	private var settingsAboutDetail: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				SettingsGroup(title: "App") {
					HStack {
						Text("App Version")
						Spacer()
						Text(model.settings.appVersion)
							.foregroundStyle(.secondary)
					}
					HStack {
						Text("Database Version")
						Spacer()
						Text(model.settings.databaseVersion)
							.foregroundStyle(.secondary)
					}
				}
			}
			.padding(.bottom, 8)
		}
		.background(Color.clear)
	}

	private func normalizedOptions(_ options: [String], current: String)
		-> [String]
	{
		var combined = options
		let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
		if !trimmed.isEmpty && !combined.contains(trimmed) {
			combined.insert(trimmed, at: 0)
		}
		if combined.isEmpty {
			return trimmed.isEmpty ? ["No options available"] : [trimmed]
		}
		return combined
	}

	private func setActiveEnvironment(at index: Int) {
		guard draftEnvironments.indices.contains(index) else { return }
		activeEnvironmentIndex = index
		persistSettings(activeIndex: index)
	}

	private func beginEnvironmentEditing() {
		editingEnvironmentIndex = selectedEnvironmentIndex
	}

	private func cancelEnvironmentEdits() {
		guard storedEnvironments.indices.contains(selectedEnvironmentIndex)
		else { return }
		draftEnvironments[selectedEnvironmentIndex] =
			storedEnvironments[selectedEnvironmentIndex]
		editingEnvironmentIndex = nil
	}

	private func saveEnvironmentEdits() {
		guard draftEnvironments.indices.contains(selectedEnvironmentIndex)
		else { return }
		storedEnvironments[selectedEnvironmentIndex] =
			draftEnvironments[selectedEnvironmentIndex]
		if storedEnvironments[selectedEnvironmentIndex].orgGroupUuid.isEmpty {
			storedEnvironments[selectedEnvironmentIndex].orgGroupUuid =
				UUID().uuidString
			draftEnvironments[selectedEnvironmentIndex].orgGroupUuid =
				storedEnvironments[selectedEnvironmentIndex].orgGroupUuid
		}
		editingEnvironmentIndex = nil
		persistSettings(activeIndex: activeEnvironmentIndex)
		showInfoBar(
			.success(
				title: "Settings Saved",
				message: "Environment configuration saved."
			)
		)
	}

	private func clearSelectedEnvironment() {
		guard draftEnvironments.indices.contains(selectedEnvironmentIndex)
		else { return }
		draftEnvironments[selectedEnvironmentIndex] = UemEnvironment()
		storedEnvironments[selectedEnvironmentIndex] = UemEnvironment()
		if activeEnvironmentIndex == selectedEnvironmentIndex {
			activeEnvironmentIndex = 0
		}
		editingEnvironmentIndex = nil
		persistSettings(activeIndex: activeEnvironmentIndex)
	}

	private func addEnvironment() {
		storedEnvironments.append(UemEnvironment())
		draftEnvironments.append(UemEnvironment())
		selectedEnvironmentIndex = draftEnvironments.count - 1
		persistSettings(activeIndex: activeEnvironmentIndex)
	}

	private func beginAddEnvironmentWizard() {
		wizardStep = .basics
		newEnvironmentDraft = UemEnvironment()
		wizardErrorMessage = nil
		showAddEnvironmentWizard = true
	}

	private func cancelAddEnvironmentWizard() {
		showAddEnvironmentWizard = false
		wizardErrorMessage = nil
	}

	private func wizardStepBack() {
		wizardErrorMessage = nil
		switch wizardStep {
		case .basics:
			break
		case .credentials:
			wizardStep = .basics
		}
	}

	private func wizardStepForward() {
		wizardErrorMessage = nil
		switch wizardStep {
		case .basics:
			let url = newEnvironmentDraft.uemUrl.trimmingCharacters(
				in: .whitespacesAndNewlines
			)
			let name = newEnvironmentDraft.friendlyName.trimmingCharacters(
				in: .whitespacesAndNewlines
			)
			if url.isEmpty || name.isEmpty {
				wizardErrorMessage = "Friendly Name and UEM URL are required."
				return
			}
			wizardStep = .credentials
		case .credentials:
			break
		}
	}

	private func commitNewEnvironment() {
		wizardErrorMessage = nil
		let env = newEnvironmentDraft
		let missing = [
			env.friendlyName.trimmingCharacters(in: .whitespacesAndNewlines)
				.isEmpty ? "Friendly Name" : nil,
			env.uemUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
				? "UEM URL" : nil,
			env.clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
				? "Client ID" : nil,
			env.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
				.isEmpty ? "Client Secret" : nil,
			env.oauthRegion.trimmingCharacters(in: .whitespacesAndNewlines)
				.isEmpty ? "OAuth Region" : nil,
			env.orgGroupId.trimmingCharacters(in: .whitespacesAndNewlines)
				.isEmpty ? "Org Group ID" : nil,
		].compactMap { $0 }

		guard missing.isEmpty else {
			wizardErrorMessage = "Missing: \(missing.joined(separator: ", "))."
			return
		}

		Task {
			var finalized = env
			if finalized.orgGroupUuid.trimmingCharacters(
				in: .whitespacesAndNewlines
			).isEmpty {
				if let uuid = await UEMService.instance.getOrgGroupUuid(
					id: finalized.orgGroupId
				),
					!uuid.isEmpty
				{
					finalized.orgGroupUuid = uuid
				} else {
					await MainActor.run {
						wizardErrorMessage =
							"Could not verify Org Group UUID. Check Org Group ID."
					}
					return
				}
			}

			await MainActor.run {
				storedEnvironments.append(finalized)
				draftEnvironments.append(finalized)
				selectedEnvironmentIndex = draftEnvironments.count - 1
				persistSettings(activeIndex: activeEnvironmentIndex)
				showAddEnvironmentWizard = false
				showInfoBar(
					.success(
						title: "Environment Added",
						message: "New environment saved."
					)
				)
			}
		}
	}

	private func lookupWizardOrgGroupUuid() {
		wizardErrorMessage = nil
		let id = newEnvironmentDraft.orgGroupId.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		guard !id.isEmpty else {
			wizardErrorMessage = "Org Group ID is required."
			return
		}
		Task {
			let uuid = await UEMService.instance.getOrgGroupUuid(id: id)
			await MainActor.run {
				if let uuid, !uuid.isEmpty {
					newEnvironmentDraft.orgGroupUuid = uuid
				} else {
					wizardErrorMessage =
						"Could not verify Org Group UUID. Check Org Group ID."
				}
			}
		}
	}

	private func removeEnvironment() {
		guard canRemoveEnvironment else { return }
		storedEnvironments.removeLast()
		draftEnvironments.removeLast()
		selectedEnvironmentIndex = 0
		if activeEnvironmentIndex > 0 {
			activeEnvironmentIndex = 0
		}
		persistSettings(activeIndex: activeEnvironmentIndex)
	}

	private func reloadOrgGroups() {
		Task {
			let groups = await UEMService.instance.getAllOrgGroups() ?? []
			await MainActor.run {
				orgGroups = groups
			}
		}
	}

	private func handleOrgGroupSelection(_ selection: String) {
		guard var env = draftEnvironments[safe: selectedEnvironmentIndex] else {
			return
		}
		env.orgGroupName = selection
		if let group = orgGroups.first(where: { $0.name == selection }) {
			if let groupId = group.groupId { env.orgGroupId = groupId }
		}
		draftEnvironments[selectedEnvironmentIndex] = env
		Task {
			if let uuid = await UEMService.instance.getOrgGroupUuid(
				id: env.orgGroupId
			) {
				await MainActor.run {
					draftEnvironments[selectedEnvironmentIndex].orgGroupUuid =
						uuid
				}
			}
		}
	}

	private func runValidation() {
		guard let environment = draftEnvironments[safe: activeEnvironmentIndex]
		else { return }
		let missing = [
			environment.uemUrl.isEmpty ? "UEM URL" : nil,
			environment.clientId.isEmpty ? "Client ID" : nil,
			environment.clientSecret.isEmpty ? "Client Secret" : nil,
			environment.oauthRegion.isEmpty ? "OAuth Region" : nil,
			environment.orgGroupId.isEmpty ? "Org Group ID" : nil,
		].compactMap { $0 }
		guard missing.isEmpty else {
			showInfoBar(
				.error(
					title: "Validation Failed",
					message: "Missing: \(missing.joined(separator: ", "))."
				)
			)
			return
		}

		Task {
			let uuid = await UEMService.instance.getOrgGroupUuid(
				id: environment.orgGroupId
			)
			await MainActor.run {
				if let uuid, !uuid.isEmpty {
					draftEnvironments[activeEnvironmentIndex].orgGroupUuid =
						uuid
					showInfoBar(
						.success(
							title: "Validation OK",
							message: "Org Group UUID verified."
						)
					)
				} else {
					showInfoBar(
						.error(
							title: "Validation Failed",
							message: "Could not verify Org Group UUID."
						)
					)
				}
			}
		}
	}

	private func updateDatabase() {
		guard let manifestURL = databaseManifestURL else {
			showInfoBar(
				.error(
					title: "Update Failed",
					message: "Database endpoint not configured."
				)
			)
			return
		}
		Task {
			do {
				let cache = LocalCatalogCache(manifestURL: manifestURL)
				try await cache.refreshIfNeeded()
				showInfoBar(
					.success(
						title: "Database Updated",
						message: "Catalog refreshed from server."
					)
				)
			} catch {
				showInfoBar(
					.error(
						title: "Update Failed",
						message: error.localizedDescription
					)
				)
			}
		}
	}

	private func showLogsWindow() {
		#if os(macOS)
			if let consoleURL = URL(
				string: "/System/Applications/Utilities/Console.app"
			) {
				let configuration = NSWorkspace.OpenConfiguration()
				NSWorkspace.shared.openApplication(
					at: consoleURL,
					configuration: configuration
				) { _, _ in }
			}
			showInfoBar(
				.success(title: "Logs Window", message: "Opened Console.app.")
			)
		#endif
	}

	private func deleteAllApps() {
		let cacheDir = FileManager.default.urls(
			for: .cachesDirectory,
			in: .userDomainMask
		)[0]
		.appendingPathComponent("JuiceCatalog", isDirectory: true)
		do {
			if FileManager.default.fileExists(atPath: cacheDir.path) {
				try FileManager.default.removeItem(at: cacheDir)
			}
			showInfoBar(
				.success(
					title: "Local Cache Cleared",
					message: "Local catalog cache removed."
				)
			)
		} catch {
			showInfoBar(
				.error(
					title: "Delete Failed",
					message: error.localizedDescription
				)
			)
		}
	}

	private var databaseManifestURL: URL? {
		if let endpoint = effectiveDatabaseDownloadEndpoint,
			let url = URL(string: endpoint)
		{
			return url
		}
		if let server = effectiveDatabaseServerUrl,
			let url = URL(string: server)?.appendingPathComponent(
				"manifest.json"
			)
		{
			return url
		}
		return nil
	}

	private var effectiveDatabaseServerUrl: String? {
		let trimmed = databaseServerOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		return trimmed.isEmpty ? settingsState.databaseServerUrl : trimmed
	}

	private var effectiveDatabaseVersionEndpoint: String? {
		let trimmed = databaseVersionEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		return trimmed.isEmpty ? settingsState.databaseVersionEndpoint : trimmed
	}

	private var effectiveDatabaseDownloadEndpoint: String? {
		let trimmed = databaseDownloadEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		return trimmed.isEmpty
			? settingsState.databaseDownloadEndpoint : trimmed
	}

	private func applyAdvancedDatabaseSettings() {
		var updated = settingsState
		let server = databaseServerOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let version = databaseVersionEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let download = databaseDownloadEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)

		if !server.isEmpty { updated.databaseServerUrl = server }
		if !version.isEmpty { updated.databaseVersionEndpoint = version }
		if !download.isEmpty { updated.databaseDownloadEndpoint = download }

		settingsState = updated
		persistSettings(activeIndex: activeEnvironmentIndex)
		showInfoBar(
			.success(
				title: "Advanced Settings Saved",
				message: "Database endpoints updated."
			)
		)
	}

	private func resetAppConfiguration() {
		settingsStore.reset()
		let fresh = SettingsStore.SettingsState()
		let defaultEnvs = SettingsView.seededEnvironments(
			from: fresh,
			fallback: model
		)
		settingsState = fresh
		storedEnvironments = defaultEnvs
		draftEnvironments = defaultEnvs
		activeEnvironmentIndex = 0
		selectedEnvironmentIndex = 0
		databaseServerOverride = ""
		databaseVersionEndpointOverride = ""
		databaseDownloadEndpointOverride = ""
		showInfoBar(
			.warning(
				title: "Configuration Reset",
				message: "Settings have been cleared."
			)
		)
		Task { await Runtime.Config.applySettings(fresh) }
	}

	private func persistSettings(activeIndex: Int) {
		let activeUuid = storedEnvironments[safe: activeIndex]?.orgGroupUuid
		let updated = SettingsStore.SettingsState(
			activeEnvironmentUuid: activeUuid,
			uemEnvironments: storedEnvironments,
			databaseServerUrl: settingsState.databaseServerUrl,
			databaseVersionEndpoint: settingsState.databaseVersionEndpoint,
			databaseDownloadEndpoint: settingsState.databaseDownloadEndpoint,
			storagePath: settingsState.storagePath
		)
		settingsState = updated
		do {
			try settingsStore.save(updated)
			Task {
				await Runtime.Config.updateEnvironments(
					storedEnvironments,
					activeUuid: activeUuid
				)
			}
		} catch {
			showInfoBar(
				.error(
					title: "Save Failed",
					message: error.localizedDescription
				)
			)
		}
	}

	private func showInfoBar(_ state: SettingsInfoBarState) {
		infoBarState = state
		Task { @MainActor in
			try? await Task.sleep(for: .seconds(5))
			if infoBarState?.id == state.id {
				infoBarState = nil
			}
		}
	}

	private func loadSettingsFromDisk() async {
		let loaded = settingsStore.load()
		let seededEnvs = SettingsView.seededEnvironments(
			from: loaded,
			fallback: model
		)
		await MainActor.run {
			settingsState = loaded
			storedEnvironments = seededEnvs
			draftEnvironments = seededEnvs
			activeEnvironmentIndex = SettingsView.activeIndex(
				for: loaded.activeEnvironmentUuid
					?? model.settings.activeEnvironmentUuid,
				in: seededEnvs
			)
			selectedEnvironmentIndex = activeEnvironmentIndex
		}
		await Runtime.Config.applySettings(loaded)
	}

	private func importLegacySettingsIfNeeded() async {
		let legacyURL = URL(
			fileURLWithPath: "/Users/pete/.juice/LocalSettings.json"
		)
		guard let imported = settingsStore.importLegacyIfNeeded(from: legacyURL)
		else { return }
		let seededEnvs = SettingsView.seededEnvironments(
			from: imported,
			fallback: model
		)
		await MainActor.run {
			settingsState = imported
			storedEnvironments = seededEnvs
			draftEnvironments = seededEnvs
			activeEnvironmentIndex = SettingsView.activeIndex(
				for: imported.activeEnvironmentUuid
					?? model.settings.activeEnvironmentUuid,
				in: seededEnvs
			)
			selectedEnvironmentIndex = activeEnvironmentIndex
		}
		await Runtime.Config.applySettings(imported)
		showInfoBar(
			.success(
				title: "Settings Imported",
				message: "Imported settings from LocalSettings.json."
			)
		)
	}

	private func reimportLegacySettings() {
		let legacyURL = URL(
			fileURLWithPath: "/Users/pete/.juice/LocalSettings.json"
		)
		guard let imported = settingsStore.importLegacy(from: legacyURL) else {
			showInfoBar(
				.error(
					title: "Import Failed",
					message: "No legacy settings found to import."
				)
			)
			return
		}
		let seededEnvs = SettingsView.seededEnvironments(
			from: imported,
			fallback: model
		)
		settingsState = imported
		storedEnvironments = seededEnvs
		draftEnvironments = seededEnvs
		activeEnvironmentIndex = SettingsView.activeIndex(
			for: imported.activeEnvironmentUuid
				?? model.settings.activeEnvironmentUuid,
			in: seededEnvs
		)
		selectedEnvironmentIndex = activeEnvironmentIndex
		Task { await Runtime.Config.applySettings(imported) }
		showInfoBar(
			.success(
				title: "Settings Reimported",
				message: "Reimported settings from LocalSettings.json."
			)
		)
	}

	private static func seededEnvironments(
		from settings: SettingsStore.SettingsState,
		fallback model: PageViewData
	) -> [UemEnvironment] {
		if !settings.uemEnvironments.isEmpty {
			return settings.uemEnvironments
		}
		return model.settings.uemEnvironments.isEmpty
			? [UemEnvironment()] : model.settings.uemEnvironments
	}

	private static func activeIndex(
		for uuid: String?,
		in environments: [UemEnvironment]
	) -> Int {
		guard let uuid, !uuid.isEmpty else { return 0 }
		return environments.firstIndex(where: { $0.orgGroupUuid == uuid }) ?? 0
	}
}

private struct SettingsInfoBarState: Identifiable, Equatable {
	let id = UUID()
	let title: String
	let message: String
	let severity: SettingsInfoBarSeverity

	static func success(title: String, message: String) -> SettingsInfoBarState
	{
		SettingsInfoBarState(title: title, message: message, severity: .success)
	}

	static func warning(title: String, message: String) -> SettingsInfoBarState
	{
		SettingsInfoBarState(title: title, message: message, severity: .warning)
	}

	static func error(title: String, message: String) -> SettingsInfoBarState {
		SettingsInfoBarState(title: title, message: message, severity: .error)
	}
}

private enum SettingsInfoBarSeverity {
	case success
	case warning
	case error

	var tint: Color {
		switch self {
		case .success: return Color.green
		case .warning: return Color.orange
		case .error: return Color.red
		}
	}

	var background: Color {
		switch self {
		case .success: return Color.green.opacity(0.12)
		case .warning: return Color.orange.opacity(0.12)
		case .error: return Color.red.opacity(0.12)
		}
	}
}

private struct SettingsInfoBar: View {
	let state: SettingsInfoBarState

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(state.severity.tint)
				.font(.system(size: 14, weight: .semibold))
			VStack(alignment: .leading, spacing: 4) {
				Text(state.title)
					.font(.system(size: 13, weight: .semibold))
				Text(state.message)
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(.secondary)
			}
			Spacer(minLength: 0)
		}
		.padding(12)
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(state.severity.background)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.strokeBorder(state.severity.tint.opacity(0.3))
		)
	}
}

extension Array {
	fileprivate subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

private struct GlassButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
		return configuration.label
			.font(.system(size: 12, weight: .semibold))
			.padding(.horizontal, 12)
			.padding(.vertical, 6)
			.background {
				if #available(macOS 26.0, iOS 26.0, *) {
					ZStack {
						shape.fill(
							Color.white.opacity(
								configuration.isPressed ? 0.25 : 0.18
							)
						)
						GlassEffectContainer {
							shape
								.fill(Color.clear)
								.glassEffect(.regular, in: shape)
						}
					}
				} else {
					shape
						.fill(.ultraThinMaterial)
						.opacity(configuration.isPressed ? 0.8 : 0.95)
				}
			}
			.overlay(shape.strokeBorder(.white.opacity(0.12)))
	}
}

private struct SettingsGlassPanel<Content: View>: View {
	let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		content
			.padding(14)
			.background {
				if #available(macOS 26.0, iOS 26.0, *) {
					ZStack {
						shape.fill(Color.white.opacity(0.18))
						GlassEffectContainer {
							shape
								.fill(Color.clear)
								.glassEffect(.regular, in: shape)
						}
					}
				} else {
					shape
						.fill(.ultraThinMaterial)
						.opacity(0.9)
				}
			}
			.overlay(shape.strokeBorder(.white.opacity(0.12)))
	}
}

private struct AddEnvironmentWizard: View {
	@Binding var step: AddEnvironmentStep
	@Binding var draft: UemEnvironment
	@Binding var errorMessage: String?
	let orgGroupOptions: [String]
	let oauthRegions: [String]
	let onLookupOrgGroupUuid: () -> Void
	let onCancel: () -> Void
	let onBack: () -> Void
	let onNext: () -> Void
	let onSave: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Text("Add Environment")
					.font(.title3.weight(.semibold))
				Spacer()
				Text(step.title)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			if let errorMessage {
				SettingsInfoBar(
					state: .error(title: "Missing Info", message: errorMessage)
				)
			}

			switch step {
			case .basics:
				VStack(alignment: .leading, spacing: 12) {
					TextField("Friendly Name", text: $draft.friendlyName)
						.textFieldStyle(.roundedBorder)
					TextField("UEM URL", text: $draft.uemUrl)
						.textFieldStyle(.roundedBorder)
				}
			case .credentials:
				VStack(alignment: .leading, spacing: 12) {
					TextField("Client ID", text: $draft.clientId)
						.textFieldStyle(.roundedBorder)
					SecureField("Client Secret", text: $draft.clientSecret)
						.textFieldStyle(.roundedBorder)
					Picker("OAuth Region", selection: $draft.oauthRegion) {
						ForEach(
							normalizedOptions(
								oauthRegions,
								current: draft.oauthRegion
							),
							id: \.self
						) { option in
							Text(option).tag(option)
						}
					}
					Picker("Organization Group", selection: $draft.orgGroupName)
					{
						ForEach(
							normalizedOptions(
								orgGroupOptions,
								current: draft.orgGroupName
							),
							id: \.self
						) { option in
							Text(option).tag(option)
						}
					}
					TextField("Org Group ID", text: $draft.orgGroupId)
						.textFieldStyle(.roundedBorder)
					TextField("Org Group UUID", text: $draft.orgGroupUuid)
						.textFieldStyle(.roundedBorder)
					Button("Lookup Org Group UUID") { onLookupOrgGroupUuid() }
				}
			}

			Spacer()

			HStack {
				Button("Cancel") { onCancel() }
				Spacer()
				if step == .credentials {
					Button("Back") { onBack() }
					Button("Save") { onSave() }
						.buttonStyle(.borderedProminent)
				} else {
					Button("Next") { onNext() }
						.buttonStyle(.borderedProminent)
				}
			}
		}
		.padding(16)
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.buttonStyle(GlassButtonStyle())
	}

	private func normalizedOptions(_ options: [String], current: String)
		-> [String]
	{
		var combined = options
		let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
		if !trimmed.isEmpty && !combined.contains(trimmed) {
			combined.insert(trimmed, at: 0)
		}
		if combined.isEmpty {
			return trimmed.isEmpty ? ["No options available"] : [trimmed]
		}
		return combined
	}
}

private struct SettingsGroup<Content: View>: View {
	let title: String?
	let content: Content

	init(title: String? = nil, @ViewBuilder content: () -> Content) {
		self.title = title
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if let title {
				Text(title)
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.secondary)
			}
			content
		}
		.padding(12)
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(Color.white.opacity(0.05))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.strokeBorder(.white.opacity(0.08))
		)
	}
}

private struct SettingRow<Content: View>: View {
	let title: String
	let content: Content

	init(title: String, @ViewBuilder content: () -> Content) {
		self.title = title
		self.content = content()
	}

	var body: some View {
		HStack(alignment: .center, spacing: 12) {
			Text(title)
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(.secondary)
			Spacer(minLength: 0)
			content
		}
	}
}

#Preview {
	SettingsView(model: .sample)
		.frame(width: 700, height: 600)
		.background(JuiceGradient())
}
