import SwiftUI

#if os(macOS)
	import AppKit
#endif

enum AddEnvironmentStep: String, CaseIterable, Identifiable {
	case configureEnvironment
	case selectOrganizationGroup

	var id: String { rawValue }

	var title: String {
		switch self {
		case .configureEnvironment: return "Configure Environment"
		case .selectOrganizationGroup: return "Select Org Group"
		}
	}
}

struct SettingsView: View {
	let model: PageViewData
	@Environment(\.colorScheme) private var colorScheme
	@EnvironmentObject private var catalog: LocalCatalog
	@AppStorage("juice.debugThemeOverride") private var debugThemeOverrideRaw: String = "system"
	@ObservedObject private var styleConfig = JuiceStyleConfig.shared
	@ObservedObject private var appUpdater = AppUpdaterService.shared
	@State private var activeEnvironmentIndex: Int
	@State private var selectedEnvironmentIndex: Int
	@State private var storedEnvironments: [UemEnvironment]
	@State private var draftEnvironments: [UemEnvironment]
	@State private var editingEnvironmentIndex: Int?
	@State private var orgGroups: [OrganizationGroup] = []
	@State private var infoBarState: SettingsInfoBarState? = nil
	@State private var settingsStore: SettingsStore
	@State private var settingsState: SettingsStore.SettingsState
	@State private var showAdvancedDbSettings: Bool = false
	@State private var databaseAppsEndpointOverride: String
	@State private var databaseRecipesEndpointOverride: String
	@State private var databaseVersionEndpointOverride: String
	@State private var showResetConfirmation: Bool = false
	@State private var showRemoveEnvironmentConfirmation: Bool = false
	@State private var showAddEnvironmentWizard: Bool = false
	@State private var showEditEnvironmentSheet: Bool = false
	@State private var showAdvancedConfigurationSheet: Bool = false
	@State private var showValidationFailureDialog: Bool = false
	@State private var validationFailureDialogMessage: String = ""
	@State private var newEnvironmentDraft: UemEnvironment = UemEnvironment()
	@State private var editEnvironmentDraft: UemEnvironment = UemEnvironment()
	@State private var editingEnvironmentTargetIndex: Int? = nil
	@State private var wizardStep: AddEnvironmentStep = .configureEnvironment
	@State private var editWizardStep: AddEnvironmentStep =
		.configureEnvironment
	@State private var wizardErrorMessage: String? = nil
	@State private var editWizardErrorMessage: String? = nil
	@State private var addWizardOrgGroups: [OrganizationGroup] = []
	@State private var editWizardOrgGroups: [OrganizationGroup] = []
	@State private var isLoadingAddWizardOrgGroups: Bool = false
	@State private var isLoadingEditWizardOrgGroups: Bool = false
	@State private var isSavingAddWizard: Bool = false
	@State private var isSavingEditWizard: Bool = false
	@State private var addSelectedOrgGroupName: String = ""
	@State private var editSelectedOrgGroupName: String = ""
	@State private var prominentTintPosition: Double
	@State private var useActiveEnvironmentBrandingTint: Bool
	@State private var activeEnvironmentDetails: ActiveEnvironmentDetails? = nil
	@State private var isLoadingActiveEnvironmentDetails: Bool = false
	@State private var activeEnvironmentDetailsError: String? = nil
	@State private var isCheckingDatabase: Bool = false
	@State private var sparkleAutoCheckEnabled: Bool
	@State private var sparkleCheckIntervalHours: Int
	@State private var sparkleAutoDownloadEnabled: Bool
	@State private var actionsButtonMeasuredMaxWidth: CGFloat = 0
	@State private var actionsButtonMeasuredMaxHeight: CGFloat = 0
	private let basePanelMinHeight: CGFloat = 680
	private let bottomBarHeight: CGFloat = 88
	private let environmentWizardMinWidth: CGFloat = 620
	private let environmentWizardMinHeight: CGFloat = 560
	private let actionsButtonFallbackMinWidth: CGFloat = 100
	private let actionsButtonFallbackMinHeight: CGFloat = 32
	private let environmentStackTopAlignmentOffset: CGFloat = -30
	private let environmentSectionBottomPadding: CGFloat = 0
	private let singlePageTopPadding: CGFloat = 0

	private let oauthRegions: [String] = [
		"https://apac.uemauth.workspaceone.com",
		"https://uat.uemauth.workspaceone.com",
		"https://na.uemauth.workspaceone.com",
		"https://emea.uemauth.workspaceone.com",
	]

	private var actionsButtonMinWidth: CGFloat {
		max(actionsButtonFallbackMinWidth, actionsButtonMeasuredMaxWidth)
	}

	private var actionsButtonMinHeight: CGFloat {
		max(actionsButtonFallbackMinHeight, actionsButtonMeasuredMaxHeight)
	}

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
		_databaseAppsEndpointOverride = State(initialValue: "")
		_databaseRecipesEndpointOverride = State(initialValue: "")
		_databaseVersionEndpointOverride = State(initialValue: "")
		_prominentTintPosition = State(
			initialValue: JuiceStyleConfig.spectrumPosition(
				forHex: loadedState.prominentButtonTintHex
			)
		)
		_useActiveEnvironmentBrandingTint = State(
			initialValue: loadedState.useActiveEnvironmentBrandingTint
		)
		_sparkleAutoCheckEnabled = State(initialValue: loadedState.sparkleAutoCheckEnabled)
		_sparkleCheckIntervalHours = State(initialValue: loadedState.sparkleCheckIntervalHours)
		_sparkleAutoDownloadEnabled = State(initialValue: loadedState.sparkleAutoDownloadEnabled)
	}

	var body: some View {
		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - bottomBarHeight)
			let panelMinHeight = min(basePanelMinHeight, availableHeight)
			let panelMinWidth: CGFloat = 400
			ZStack(alignment: .bottomTrailing) {
				VStack(alignment: .leading) {
					HStack(alignment: .top) {
						mainContentPanel(
							panelMinHeight: panelMinHeight,
							panelMinWidth: panelMinWidth
						)
					}
					.frame(maxWidth: .infinity, alignment: .topLeading)
					.padding(.horizontal, 20)
					.padding(.vertical, 0)
					Spacer(minLength: 20)
				}
				EmptyView()
			}
		}
			.frame(
				maxWidth: .infinity,
				maxHeight: .infinity,
				alignment: .topLeading
			)
			.sheet(isPresented: $showResetConfirmation) {
				JuiceConfirmationSheet(
					title: "Reset App Configuration?",
					message: "This clears saved settings and secrets. This can’t be undone.",
					confirmTitle: "Reset",
					cancelTitle: "Cancel",
					isDestructive: true,
					onConfirm: {
						showResetConfirmation = false
						resetAppConfiguration()
					},
					onCancel: {
						showResetConfirmation = false
					}
				)
			}
			.sheet(isPresented: $showRemoveEnvironmentConfirmation) {
				JuiceConfirmationSheet(
					title: "Remove Environment?",
					message: "This will delete the selected environment configuration.",
					confirmTitle: "Remove",
					cancelTitle: "Cancel",
					isDestructive: true,
					onConfirm: {
						showRemoveEnvironmentConfirmation = false
						removeEnvironment()
					},
					onCancel: {
						showRemoveEnvironmentConfirmation = false
					}
				)
			}
			.sheet(isPresented: $showAddEnvironmentWizard) {
				EnvironmentWizard(
					mode: .add,
				step: $wizardStep,
				draft: $newEnvironmentDraft,
				errorMessage: $wizardErrorMessage,
				orgGroups: $addWizardOrgGroups,
				isLoadingOrgGroups: $isLoadingAddWizardOrgGroups,
				isSaving: $isSavingAddWizard,
				selectedOrgGroupName: $addSelectedOrgGroupName,
				oauthRegions: oauthRegions,
				onSelectOrgGroup: selectAddWizardOrgGroup,
				onCancel: cancelAddEnvironmentWizard,
				onBack: wizardStepBack,
					onNext: wizardStepForward,
					onSave: commitNewEnvironment
				)
			.frame(
				minWidth: environmentWizardMinWidth,
				minHeight: environmentWizardMinHeight
			)
		}
		.sheet(isPresented: $showEditEnvironmentSheet) {
			EnvironmentWizard(
				mode: .edit,
				step: $editWizardStep,
				draft: $editEnvironmentDraft,
				errorMessage: $editWizardErrorMessage,
				orgGroups: $editWizardOrgGroups,
				isLoadingOrgGroups: $isLoadingEditWizardOrgGroups,
				isSaving: $isSavingEditWizard,
				selectedOrgGroupName: $editSelectedOrgGroupName,
				oauthRegions: oauthRegions,
				onSelectOrgGroup: selectEditWizardOrgGroup,
				onCancel: cancelEditEnvironmentSheet,
				onBack: editWizardStepBack,
				onNext: editWizardStepForward,
				onSave: commitEditedEnvironment
			)
			.frame(
				minWidth: environmentWizardMinWidth,
				minHeight: environmentWizardMinHeight
			)
		}
			.sheet(isPresented: $showAdvancedConfigurationSheet) {
				AdvancedConfigurationSheet(
				databaseAppsEndpointOverride: $databaseAppsEndpointOverride,
				databaseRecipesEndpointOverride:
					$databaseRecipesEndpointOverride,
				databaseVersionEndpointOverride:
					$databaseVersionEndpointOverride,
					prominentTintPosition: $prominentTintPosition,
					useActiveEnvironmentBrandingTint:
						$useActiveEnvironmentBrandingTint,
					sparkleAutoCheckEnabled: $sparkleAutoCheckEnabled,
					sparkleCheckIntervalHours: $sparkleCheckIntervalHours,
					sparkleAutoDownloadEnabled: $sparkleAutoDownloadEnabled,
					currentDatabaseAppsEndpoint: settingsState
						.databaseAppsEndpoint,
					currentDatabaseRecipesEndpoint: settingsState
					.databaseRecipesEndpoint,
				currentDatabaseVersionEndpoint: settingsState
					.databaseVersionEndpoint,
				onProminentTintChanged: { position in
					applyProminentTint(position: position, persist: false)
				},
				onProminentTintCommit: { position in
					applyProminentTint(position: position, persist: true)
				},
					onUseActiveBrandingTintChanged: { useBrandingTint in
						applyUseActiveEnvironmentBrandingTint(
							useBrandingTint,
							persist: true
						)
					},
					onSparkleAutoCheckChanged: { enabled in
						settingsState.sparkleAutoCheckEnabled = enabled
						applySparklePreferences(persist: false)
					},
					onSparkleCheckIntervalChanged: { interval in
						let normalized = AppUpdaterService.normalizedIntervalHours(interval)
						sparkleCheckIntervalHours = normalized
						settingsState.sparkleCheckIntervalHours = normalized
						applySparklePreferences(persist: false)
					},
					onSparkleAutoDownloadChanged: { enabled in
						settingsState.sparkleAutoDownloadEnabled = enabled
						applySparklePreferences(persist: false)
					},
					onResetProminentTint: {
						let defaultPosition = JuiceStyleConfig.spectrumPosition(
							forHex: JuiceStyleConfig.defaultTintHex
					)
					prominentTintPosition = defaultPosition
					applyProminentTint(
						position: defaultPosition,
						persist: true
					)
				},
				onCancel: {
					showAdvancedConfigurationSheet = false
				},
				onSave: {
					applyAdvancedDatabaseSettings()
					showAdvancedConfigurationSheet = false
				},
				onReset: {
					showAdvancedConfigurationSheet = false
					showResetConfirmation = true
				}
				)
				.frame(minWidth: 520, minHeight: 360)
			}
			.sheet(isPresented: $showValidationFailureDialog) {
				ValidationFailureDialog(
					title: "Validation Failed",
					message: validationFailureDialogMessage,
					onOK: {
						showValidationFailureDialog = false
					}
				)
			}
			.task {
				await loadSettingsFromDisk()
			await importLegacySettingsIfNeeded()
			await refreshActiveEnvironmentDetails()
		}
		.onChange(of: activeEnvironmentIndex) { _, _ in
			Task { await refreshActiveEnvironmentDetails() }
		}
		.onChange(
			of: storedEnvironments.map(\.orgGroupId).joined(separator: "|")
		) { _, _ in
			Task { await refreshActiveEnvironmentDetails() }
		}
		.onChange(
			of: storedEnvironments.map(\.orgGroupUuid).joined(separator: "|")
		) { _, _ in
			Task { await refreshActiveEnvironmentDetails() }
		}
	}
	// --- HERE IS THE PAGE SETUP --- //
	@ViewBuilder
	private func mainContentPanel(
		panelMinHeight: CGFloat,
		panelMinWidth: CGFloat
		) -> some View {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .center, spacing: 12) {
					SectionHeader("Settings")
					Spacer()
					themePicker
						.toggleStyle(.switch)
						.font(.system(size: 13, weight: .semibold))
						.fixedSize()
						.juiceHelp(HelpText.Settings.darkMode)
				}

				singlePageContent
					.padding(.top, singlePageTopPadding)
			}
		.padding(16)
		.frame(
			minWidth: panelMinWidth,
			minHeight: panelMinHeight,
			maxHeight: .infinity,
			alignment: .topLeading
		)
		.frame(maxWidth: .infinity, alignment: .topLeading)
		.layoutPriority(1)
		.background(colorScheme == .dark ? Color.black.opacity(0.48) : Color.white)
		.background {
			let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
			if #available(macOS 26.0, iOS 16.0, *) {
				GlassEffectContainer {
					shape
						.fill(Color.clear)
						.glassEffect(.regular, in: shape)
				}
			} else {
				shape.fill(
					Color(nsColor: .windowBackgroundColor).opacity(
						colorScheme == .dark ? 0.92 : 0.94
					)
				)
			}
		}
		.overlay {
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.strokeBorder(Color.white.opacity(0.15))
		}
		.overlay(alignment: .top) {
			if let infoBarState {
				SettingsInfoBar(state: infoBarState)
					.frame(maxWidth: 460)
					.padding(.top, 14)
					.padding(.horizontal, 16)
					.allowsHitTesting(false)
					.zIndex(20)
					.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(
			.spring(response: 0.36, dampingFraction: 0.9),
			value: infoBarState?.id
		)
		.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
	}

	// --- HERE IS THE PAGE LAYOUT --- //
	private var singlePageContent: some View {

		VStack(alignment: .leading, spacing: 10) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Environments")
					.font(.title2.weight(.semibold))
			}.padding(.bottom, -20)
			HStack {
				Spacer()
				EnvironmentListDisplay(
					environments: storedEnvironments,
					activeEnvironmentUuid: settingsState.activeEnvironmentUuid
						?? storedEnvironments[safe: activeEnvironmentIndex]?
						.orgGroupUuid,
					onSetActiveEnvironment: { environment in
						setActiveEnvironment(matching: environment)
					},
					onEditEnvironment: { environment in
						editEnvironment(matching: environment)
					},
					onDeleteEnvironment: { environment in
						deleteEnvironment(matching: environment)
					},
					onAddEnvironment: {
						beginAddEnvironmentWizard()
					}
				).frame(width: 250)
				Spacer()
			}
			HStack(spacing: 10) {
				//Active Environment
				VStack(alignment: .leading, spacing: 8) {

					Text("Active Environment")
						.font(.system(size: 16, weight: .semibold))

					SettingsGlassPanel {
						if let environment = activeEnvironment {
							if isLoadingActiveEnvironmentDetails {
								VStack(spacing: 8) {
									Spacer()
									ProgressView()
										.controlSize(.small)
									Text("Loading active environment details…")
										.font(.caption)
										.foregroundStyle(.secondary)
									Spacer()
								}
								.frame(maxWidth: .infinity, minHeight: 100)
							} else {
								VStack(alignment: .leading, spacing: 4) {
									Text(
										normalizedSettingValue(
											environment.friendlyName
										)
									)
									.font(
										.system(size: 12, weight: .bold)
									)
									.lineLimit(1)

									Rectangle()
										.frame(height: 2)
										.clipped()
										.foregroundStyle(
											Color(hex: JuiceStyleConfig.defaultTintHex)
										)
										.padding(.trailing, 25)
										.padding(.vertical, 2)

									HStack(alignment: .top) {
										VStack {
											activeEnvironmentMetadataRow(
												icon: "list.bullet.rectangle",
												label: "Org Group Name",
												value: normalizedSettingValue(
													environment.orgGroupName
												)
											)
											activeEnvironmentMetadataRow(
												icon: "building.2",
												label: "Child Org Groups",
												value: formattedCount(
													activeEnvironmentDetails?
														.childOrganizationGroupCount
												)
											)
										}
										.frame(minWidth: 140)
										VStack {
											activeEnvironmentMetadataRow(
												icon:
													"desktopcomputer.and.macbook",
												label: "macOS Devices",
												value: formattedCount(
													activeEnvironmentDetails?
														.parentDeviceCount
												)
											)

											activeEnvironmentMetadataRow(
												icon: "shippingbox",
												label: "macOS Apps",
												value: formattedCount(
													activeEnvironmentDetails?
														.appCount
												)
											)
										}
										.frame(minWidth: 140)
									}
									Spacer()
								}
							}
						} else {
							HStack {
								Text("No active environment selected.")
									.font(.system(size: 12, weight: .regular))
									.foregroundStyle(.secondary)
								Spacer(minLength: 0)
							}
							.padding(.horizontal, 10)
							.padding(.vertical, 8)
						}
					}.frame(minWidth: 320, maxWidth: .infinity)
				}
				.frame(maxWidth: .infinity)
				
					//Actions
						VStack(alignment: .leading, spacing: 8) {
							Text("Actions")
								.font(.system(size: 16, weight: .semibold))
							settingsActionsContainer()
							.frame(maxWidth: .infinity)
						}
					.frame(maxWidth: .infinity)
			}.frame(maxWidth: .infinity)
		}
		//.border(.red, width: 2)
		.padding(.top, -20)
		.panelContentScrollChrome()
	}

	@ViewBuilder
	private func settingsActionsContainer() -> some View {
		#if os(macOS)
			if #available(macOS 26.0, *) {
				SettingsGlassPanel {
					settingsActionsButtonsContent()
				}
			} else {
				settingsActionsButtonsContent()
					.padding(10)
					.background(
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
					)
					.overlay(
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.strokeBorder(Color.primary.opacity(0.12))
					)
			}
		#else
			SettingsGlassPanel {
				settingsActionsButtonsContent()
			}
		#endif
	}

	@ViewBuilder
	private func settingsActionsButtonsContent() -> some View {
		ScrollView(.horizontal, showsIndicators: false) {
			LazyHStack(alignment: .top, spacing: 8) {
				VStack(alignment: .center, spacing: 8) {
					Button("Check Config") { runValidation() }
						.settingsActionsButtonStyle(prominent: false)
						.reportActionsButtonSize()
						.frame(
							width: actionsButtonMinWidth,
							height: actionsButtonMinHeight
						)
						.juiceHelp(HelpText.Settings.validateConfig)
					Button("Update DB") { updateDatabase() }
						.settingsActionsButtonStyle(prominent: true)
						.reportActionsButtonSize()
						.frame(
							width: actionsButtonMinWidth,
							height: actionsButtonMinHeight
						)
						.juiceHelp(HelpText.Settings.updateDatabase)
//					Button("Check DB") { checkForNewDatabase() }
//						.settingsActionsButtonStyle(prominent: false)
//						.reportActionsButtonSize()
//						.frame(
//							width: actionsButtonMinWidth,
//							height: actionsButtonMinHeight
//						)
//						.disabled(isCheckingDatabase)
//						.juiceHelp(HelpText.Settings.updateDatabase)
				}

				VStack(alignment: .center, spacing: 8) {
					Button("Show Logs") { showLogsWindow() }
						.settingsActionsButtonStyle(prominent: false)
						.reportActionsButtonSize()
						.frame(
							width: actionsButtonMinWidth,
							height: actionsButtonMinHeight
						)
						.juiceHelp(HelpText.Settings.showLogs)
					Button("Advanced") {
						showAdvancedConfigurationSheet = true
					}
					.settingsActionsButtonStyle(prominent: true)
					.reportActionsButtonSize()
					.frame(
						width: actionsButtonMinWidth,
						height: actionsButtonMinHeight
					)
					.juiceHelp(HelpText.Settings.openAdvanced)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.onPreferenceChange(ActionsButtonSizePreferenceKey.self) { sizes in
			let measuredWidth = sizes.map(\.width).max() ?? 0
			let measuredHeight = sizes.map(\.height).max() ?? 0
			actionsButtonMeasuredMaxWidth = measuredWidth
			actionsButtonMeasuredMaxHeight = measuredHeight
		}
	}

	private var canRemoveEnvironment: Bool {
		draftEnvironments.count > 1
	}

	private var activeEnvironment: UemEnvironment? {
		storedEnvironments[safe: activeEnvironmentIndex]
	}

	private var isConfigured: Bool {
		draftEnvironments.contains {
			!$0.uemUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		}
	}

	private var themePicker: some View {
		HStack(spacing: 12) {
			Text("Appearance")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(.secondary)
			
			LiquidGlassSegmentedPicker(
				items: [
					.init(title: "System", icon: "gearshape", tag: "system"),
					.init(title: "Light", icon: "sun.max", tag: "light"),
					.init(title: "Dark", icon: "moon", tag: "dark"),
				],
				selection: $debugThemeOverrideRaw
			)
		}
	}

	private var isEditingSelectedEnvironment: Bool {
		editingEnvironmentIndex == selectedEnvironmentIndex
	}

	private var isActiveSelectedEnvironment: Bool {
		activeEnvironmentIndex == selectedEnvironmentIndex
	}

	private func normalizedSettingValue(_ value: String) -> String {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "Not set" : trimmed
	}

	private func formattedCount(_ value: Int?) -> String {
		guard let value else { return "Not available" }
		return String(value)
	}

	private func refreshActiveEnvironmentDetails() async {
		guard let environment = activeEnvironment else {
			await MainActor.run {
				activeEnvironmentDetails = nil
				isLoadingActiveEnvironmentDetails = false
				activeEnvironmentDetailsError = nil
				persistWidgetCountSnapshot(deviceCount: nil, appCount: nil)
			}
			return
		}

		let orgGroupId = environment.orgGroupId.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let requestedOrgGroupUuid = environment.orgGroupUuid.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		if orgGroupId.isEmpty {
			await MainActor.run {
				activeEnvironmentDetails = nil
				isLoadingActiveEnvironmentDetails = false
				activeEnvironmentDetailsError =
					"Active environment is missing Org Group ID."
				persistWidgetCountSnapshot(deviceCount: nil, appCount: nil)
			}
			return
		}

		await MainActor.run {
			isLoadingActiveEnvironmentDetails = true
			activeEnvironmentDetailsError = nil
		}

		async let detailsTask = UEMService.instance.getActiveEnvironmentDetails(
			environment: environment
		)
		async let appListTask = UEMService.instance.getAllApps(
			includeVersionChecks: false
		)
		let details = await detailsTask
		let apps = await appListTask
		let appCount = apps.compactMap { $0 }.count

		await MainActor.run {
			let currentOrgGroupUuid =
				activeEnvironment?.orgGroupUuid
				.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			let currentOrgGroupId =
				activeEnvironment?.orgGroupId
				.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			let requestedMatchesCurrent =
				(!requestedOrgGroupUuid.isEmpty
					&& requestedOrgGroupUuid == currentOrgGroupUuid)
				|| (requestedOrgGroupUuid.isEmpty
					&& currentOrgGroupId == orgGroupId)
			guard requestedMatchesCurrent else {
				return
			}

			if var details {
				details.appCount = appCount
				activeEnvironmentDetails = details
			} else {
				activeEnvironmentDetails = ActiveEnvironmentDetails(
					parentDeviceCount: nil,
					parentAdminCount: nil,
					childOrganizationGroupCount: 0,
					appCount: appCount,
					parentGroupName: nil,
					parentGroupId: nil,
					parentGroupUuid: nil
				)
			}
			activeEnvironmentDetailsError =
				details == nil
				? "Unable to load active environment details."
				: nil
			isLoadingActiveEnvironmentDetails = false
			persistWidgetCountSnapshot(
				deviceCount: activeEnvironmentDetails?.parentDeviceCount,
				appCount: appCount
			)
		}
	}

	@ViewBuilder
	private func activeEnvironmentMetadataRow(
		icon: String,
		label: String,
		value: String,
		monospaced: Bool = false
	) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 7) {
			Image(systemName: icon)
				.font(.system(size: 11, weight: .medium))
				.foregroundStyle(
					Color(hex: JuiceStyleConfig.defaultTintHex)
				)
				.frame(width: 14, alignment: .center)

			VStack(alignment: .leading, spacing: 0) {
				Text(label)
					.font(.system(size: 10, weight: .semibold))
					.foregroundStyle(.primary)
				Text(value)
					.font(
						.system(
							size: 11,
							weight: .regular,
							design: monospaced ? .monospaced : .default
						)
					)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
					.textSelection(.enabled)
					.juiceFullValueHelp(fullValue: value)
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			Spacer(minLength: 0)
		}
		.padding(.vertical, 1)
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

	private func environmentIndex(matching environment: UemEnvironment) -> Int?
	{
		let targetUuid = environment.orgGroupUuid.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		if !targetUuid.isEmpty,
			let index = draftEnvironments.firstIndex(where: {
				$0.orgGroupUuid.trimmingCharacters(in: .whitespacesAndNewlines)
					== targetUuid
			})
		{
			return index
		}

		let targetUrl = environment.uemUrl.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let targetName = environment.friendlyName.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let targetGroupId = environment.orgGroupId.trimmingCharacters(
			in: .whitespacesAndNewlines
		)

		return draftEnvironments.firstIndex(where: {
			$0.uemUrl.trimmingCharacters(in: .whitespacesAndNewlines)
				== targetUrl
				&& $0.friendlyName.trimmingCharacters(
					in: .whitespacesAndNewlines
				) == targetName
				&& $0.orgGroupId.trimmingCharacters(
					in: .whitespacesAndNewlines
				) == targetGroupId
		})
	}

	private func setActiveEnvironment(matching environment: UemEnvironment) {
		guard let index = environmentIndex(matching: environment) else {
			return
		}
		selectedEnvironmentIndex = index
		setActiveEnvironment(at: index)
	}

	private func editEnvironment(matching environment: UemEnvironment) {
		guard let index = environmentIndex(matching: environment) else {
			return
		}
		selectedEnvironmentIndex = index
		beginEnvironmentEditing()
	}

	private func deleteEnvironment(matching environment: UemEnvironment) {
		guard let index = environmentIndex(matching: environment) else {
			return
		}
		selectedEnvironmentIndex = index
		showRemoveEnvironmentConfirmation = true
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

				SettingsGroup(title: "Validation") {
					Button("Run Validation") { runValidation() }
				}
			}
			.padding(.bottom, 8)
		}
		.padding(.top, -20)
		.panelContentScrollChrome()
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
							Button("Check Database") { checkForNewDatabase() }
								.disabled(isCheckingDatabase)
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
							"Database Apps Endpoint",
							text: $databaseAppsEndpointOverride,
							prompt: Text(
								settingsState.databaseAppsEndpoint
									?? SettingsStore.defaultAppsEndpoint
							)
						)
						.textFieldStyle(.roundedBorder)
						TextField(
							"Database Recipes Endpoint",
							text: $databaseRecipesEndpointOverride,
							prompt: Text(
								settingsState.databaseRecipesEndpoint
									?? SettingsStore.defaultRecipesEndpoint
							)
						)
						.textFieldStyle(.roundedBorder)
						TextField(
							"Database Version Endpoint",
							text: $databaseVersionEndpointOverride,
							prompt: Text(
								settingsState.databaseVersionEndpoint
									?? SettingsStore.defaultVersionEndpoint
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
							.juiceHelp(HelpText.Settings.resetConfiguration)
						}
					}
				}
			}
			.padding(.bottom, 8)
		}
		.padding(.top, -20)
		.panelContentScrollChrome()
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
		.padding(.top, -20)
		.panelContentScrollChrome()
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
		guard storedEnvironments.indices.contains(selectedEnvironmentIndex)
		else { return }
		editingEnvironmentIndex = selectedEnvironmentIndex
		editingEnvironmentTargetIndex = selectedEnvironmentIndex
		editEnvironmentDraft = storedEnvironments[selectedEnvironmentIndex]
		appLog(
			.debug,
			"SettingsView.EditWizard",
			"Opening edit sheet. index=\(selectedEnvironmentIndex), friendlyName=\(editEnvironmentDraft.friendlyName), uemUrl=\(editEnvironmentDraft.uemUrl), orgGroupName=\(editEnvironmentDraft.orgGroupName), orgGroupId=\(editEnvironmentDraft.orgGroupId), orgGroupUuid=\(editEnvironmentDraft.orgGroupUuid)"
		)
		editWizardStep = .configureEnvironment
		editWizardErrorMessage = nil
		editWizardOrgGroups = []
		editSelectedOrgGroupName = ""
		isLoadingEditWizardOrgGroups = false
		isSavingEditWizard = false
		showEditEnvironmentSheet = true
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
		let savedEnvironment = storedEnvironments[selectedEnvironmentIndex]
		editingEnvironmentIndex = nil
		persistSettings(activeIndex: activeEnvironmentIndex)
		Task {
			await UEMService.instance.refreshOrgGroupLogo(
				environment: savedEnvironment
			)
		}
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
		wizardStep = .configureEnvironment
		newEnvironmentDraft = UemEnvironment()
		wizardErrorMessage = nil
		addWizardOrgGroups = []
		addSelectedOrgGroupName = ""
		isLoadingAddWizardOrgGroups = false
		isSavingAddWizard = false
		showAddEnvironmentWizard = true
	}

	private func cancelAddEnvironmentWizard() {
		showAddEnvironmentWizard = false
		wizardErrorMessage = nil
		isLoadingAddWizardOrgGroups = false
		isSavingAddWizard = false
	}

	private func wizardStepBack() {
		wizardErrorMessage = nil
		switch wizardStep {
		case .configureEnvironment:
			break
		case .selectOrganizationGroup:
			wizardStep = .configureEnvironment
		}
	}

	private func wizardStepForward() {
		wizardErrorMessage = nil
		guard case .configureEnvironment = wizardStep else { return }
		if let validationError = EnvironmentWizardCoordinator.configureStepValidationError(
			for: newEnvironmentDraft
		) {
			wizardErrorMessage = validationError
			return
		}

		wizardStep = .selectOrganizationGroup
		addWizardOrgGroups = []
		addSelectedOrgGroupName = ""
		isLoadingAddWizardOrgGroups = true
		Task {
			let groups = await EnvironmentWizardCoordinator.fetchOrgGroups(
				for: newEnvironmentDraft
			)
			await MainActor.run {
				isLoadingAddWizardOrgGroups = false
				guard !groups.isEmpty else {
					wizardErrorMessage =
						"No Org Groups found. Verify credentials and tenant URL."
					return
				}
				addWizardOrgGroups = groups
				let preferredName =
					newEnvironmentDraft.orgGroupName.trimmingCharacters(
						in: .whitespacesAndNewlines
					)
				let selectedName =
					groups.first(where: { $0.name == preferredName })?.name
					?? groups.first?.name ?? ""
				selectAddWizardOrgGroup(selectedName)
			}
		}
	}

	private func cancelEditEnvironmentSheet() {
		appLog(.debug, "SettingsView.EditWizard", "Closing edit sheet.")
		showEditEnvironmentSheet = false
		editWizardErrorMessage = nil
		isLoadingEditWizardOrgGroups = false
		isSavingEditWizard = false
		editingEnvironmentTargetIndex = nil
		editingEnvironmentIndex = nil
	}

	private func editWizardStepBack() {
		editWizardErrorMessage = nil
		switch editWizardStep {
		case .configureEnvironment:
			break
		case .selectOrganizationGroup:
			appLog(
				.debug,
				"SettingsView.EditWizard",
				"Back tapped. Returning to Configure step."
			)
			editWizardStep = .configureEnvironment
		}
	}

	private func editWizardStepForward() {
		editWizardErrorMessage = nil
		guard case .configureEnvironment = editWizardStep else { return }
		appLog(
			.debug,
			"SettingsView.EditWizard",
			"Next tapped on Configure step. friendlyName=\(editEnvironmentDraft.friendlyName), uemUrl=\(editEnvironmentDraft.uemUrl), authType=\(editEnvironmentDraft.authenticationType.rawValue), clientIdLength=\(editEnvironmentDraft.clientId.count), clientSecretLength=\(editEnvironmentDraft.clientSecret.count), basicUsernameLength=\(editEnvironmentDraft.basicUsername.count), basicPasswordLength=\(editEnvironmentDraft.basicPassword.count), apiKeyLength=\(editEnvironmentDraft.apiKey.count), oauthRegion=\(editEnvironmentDraft.oauthRegion)"
		)
		if let validationError = EnvironmentWizardCoordinator.configureStepValidationError(
			for: editEnvironmentDraft
		) {
			appLog(
				.warning,
				"SettingsView.EditWizard",
				"Configure validation failed: \(validationError)"
			)
			editWizardErrorMessage = validationError
			return
		}

		editWizardStep = .selectOrganizationGroup
		editWizardOrgGroups = []
		editSelectedOrgGroupName = ""
		isLoadingEditWizardOrgGroups = true
		appLog(
			.debug,
			"SettingsView.EditWizard",
			"Fetching Org Groups for URL: \(editEnvironmentDraft.uemUrl)"
		)
		Task {
			let groups = await EnvironmentWizardCoordinator.fetchOrgGroups(
				for: editEnvironmentDraft
			)
			await MainActor.run {
				isLoadingEditWizardOrgGroups = false
				guard !groups.isEmpty else {
					appLog(
						.warning,
						"SettingsView.EditWizard",
						"Org Groups fetch returned 0 groups."
					)
					editWizardErrorMessage =
						"No Org Groups found. Verify credentials and tenant URL."
					return
				}
				appLog(
					.info,
					"SettingsView.EditWizard",
					"Org Groups fetch succeeded. Count: \(groups.count)"
				)
				let summary = groups.prefix(5).map {
					"\($0.name ?? "<nil-name>") [raw:\($0.groupId ?? "<nil-id>"), resolved:\($0.resolvedGroupId ?? "<nil-id>")]"
				}.joined(separator: ", ")
				appLog(
					.debug,
					"SettingsView.EditWizard",
					"First fetched groups: \(summary)"
				)
				editWizardOrgGroups = groups
				let preferredName =
					editEnvironmentDraft.orgGroupName.trimmingCharacters(
						in: .whitespacesAndNewlines
					)
				let selectedName =
					groups.first(where: { $0.name == preferredName })?.name
					?? groups.first?.name ?? ""
				appLog(
					.debug,
					"SettingsView.EditWizard",
					"Auto-selected org group name: \(selectedName)"
				)
				selectEditWizardOrgGroup(selectedName)
			}
		}
	}

	private func commitEditedEnvironment() {
		editWizardErrorMessage = nil
		appLog(
			.info,
			"SettingsView.EditWizard",
			"Save tapped. step=\(editWizardStep.title), targetIndex=\(editingEnvironmentTargetIndex.map(String.init) ?? "nil"), selectedOrgGroupName=\(editSelectedOrgGroupName), fetchedGroupCount=\(editWizardOrgGroups.count)"
		)
		guard let targetIndex = editingEnvironmentTargetIndex,
			storedEnvironments.indices.contains(targetIndex),
			draftEnvironments.indices.contains(targetIndex)
		else {
			appLog(
				.error,
				"SettingsView.EditWizard",
				"Target index is invalid."
			)
			cancelEditEnvironmentSheet()
			showInfoBar(
				.error(
					title: "Edit Failed",
					message: "Selected environment could not be found."
				)
			)
			return
		}

		guard case .selectOrganizationGroup = editWizardStep else {
			appLog(
				.warning,
				"SettingsView.EditWizard",
				"Save blocked: not on Select Org Group step."
			)
			editWizardErrorMessage =
				"Select an Org Group before saving."
			return
		}
		guard
			let selectedGroup = resolveSelectedOrgGroupForSave(
				selectedName: editSelectedOrgGroupName,
				groups: editWizardOrgGroups
			)
		else {
			appLog(
				.warning,
				"SettingsView.EditWizard",
				"Save blocked: selected org group not found. selectedName=\(editSelectedOrgGroupName), availableGroups=\(editWizardOrgGroups.count)"
			)
			editWizardErrorMessage =
				"Selected Org Group is invalid. Reload and try again."
			return
		}
		appLog(
			.debug,
			"SettingsView.EditWizard",
			"Selected group resolved. name=\(selectedGroup.name ?? "nil"), id=\(selectedGroup.groupId ?? "nil")"
		)
		isSavingEditWizard = true

		Task {
			guard
				let finalized = await finalizeOrgGroupIdentifiers(
					environment: editEnvironmentDraft,
					selectedGroup: selectedGroup,
					setError: { message in
						appLog(
							.warning,
							"SettingsView.EditWizard",
							"Identifier finalization failed: \(message)"
						)
						editWizardErrorMessage = message
					}
				)
			else {
				await MainActor.run {
					isSavingEditWizard = false
				}
				return
			}
			appLog(
				.info,
				"SettingsView.EditWizard",
				"Identifier finalization succeeded. orgGroupId=\(finalized.orgGroupId), orgGroupUuid=\(finalized.orgGroupUuid)"
			)

			let brandingResult = await EnvironmentWizardCoordinator
				.validateBrandingAndRefreshLogo(
					for: finalized,
					logCategory: "SettingsView.EditWizard"
				)
			guard case .success = brandingResult else {
				let message: String
				switch brandingResult {
				case .failure(let error):
					message = error.userMessage
				case .success:
					message = "Branding validation failed."
				}
				await MainActor.run {
					isSavingEditWizard = false
					editWizardErrorMessage = message
				}
				return
			}

			await MainActor.run {
				appLog(
					.info,
					"SettingsView.EditWizard",
					"Persisting edited environment at index \(targetIndex)."
				)
				storedEnvironments[targetIndex] = finalized
				draftEnvironments[targetIndex] = finalized
				selectedEnvironmentIndex = targetIndex
				persistSettings(activeIndex: activeEnvironmentIndex)
				showEditEnvironmentSheet = false
				isSavingEditWizard = false
				editingEnvironmentTargetIndex = nil
				editingEnvironmentIndex = nil
				showInfoBar(
					.success(
						title: "Environment Updated",
						message: "Environment configuration saved."
					)
				)
				appLog(
					.info,
					"SettingsView.EditWizard",
					"Save completed successfully."
				)
			}
		}
	}

	private func commitNewEnvironment() {
		wizardErrorMessage = nil
		guard case .selectOrganizationGroup = wizardStep else {
			wizardErrorMessage = "Select an Org Group before saving."
			return
		}
		guard
			let selectedGroup = resolveSelectedOrgGroupForSave(
				selectedName: addSelectedOrgGroupName,
				groups: addWizardOrgGroups
			)
		else {
			wizardErrorMessage =
				"Selected Org Group is invalid. Reload and try again."
			return
		}
		isSavingAddWizard = true

		Task {
			guard
				let finalized = await finalizeOrgGroupIdentifiers(
					environment: newEnvironmentDraft,
					selectedGroup: selectedGroup,
					setError: { message in
						wizardErrorMessage = message
					}
				)
			else {
				await MainActor.run {
					isSavingAddWizard = false
				}
				return
			}

			let brandingResult = await EnvironmentWizardCoordinator
				.validateBrandingAndRefreshLogo(
					for: finalized,
					logCategory: "SettingsView.AddWizard"
				)
			guard case .success = brandingResult else {
				let message: String
				switch brandingResult {
				case .failure(let error):
					message = error.userMessage
				case .success:
					message = "Branding validation failed."
				}
				await MainActor.run {
					isSavingAddWizard = false
					wizardErrorMessage = message
				}
				return
			}

			await MainActor.run {
				storedEnvironments.append(finalized)
				draftEnvironments.append(finalized)
				selectedEnvironmentIndex = draftEnvironments.count - 1
				persistSettings(activeIndex: activeEnvironmentIndex)
				showAddEnvironmentWizard = false
				isSavingAddWizard = false
				showInfoBar(
					.success(
						title: "Environment Added",
						message: "New environment saved."
					)
				)
			}
		}
	}

	private func selectAddWizardOrgGroup(_ name: String) {
		addSelectedOrgGroupName = name
		guard
			let selected = addWizardOrgGroups.first(where: { $0.name == name }),
			let groupName = selected.name,
			let groupId = selected.resolvedGroupId,
			!groupId.isEmpty
		else { return }
		newEnvironmentDraft.orgGroupName = groupName
		newEnvironmentDraft.orgGroupId = groupId
		newEnvironmentDraft.orgGroupUuid = ""
	}

	private func selectEditWizardOrgGroup(_ name: String) {
		editSelectedOrgGroupName = name
		guard
			let selected = editWizardOrgGroups.first(where: { $0.name == name }
			),
			let groupName = selected.name,
			let groupId = selected.resolvedGroupId,
			!groupId.isEmpty
		else { return }
		editEnvironmentDraft.orgGroupName = groupName
		editEnvironmentDraft.orgGroupId = groupId
		editEnvironmentDraft.orgGroupUuid = ""
	}

	private func resolveSelectedOrgGroupForSave(
		selectedName: String,
		groups: [OrganizationGroup]
	) -> OrganizationGroup? {
		EnvironmentWizardCoordinator.resolveSelectedOrgGroupForSave(
			selectedName: selectedName,
			groups: groups
		)
	}

	private func finalizeOrgGroupIdentifiers(
		environment: UemEnvironment,
		selectedGroup: OrganizationGroup,
		setError: @escaping @MainActor (String) -> Void
	) async -> UemEnvironment? {
		let result = await EnvironmentWizardCoordinator.finalizeOrgGroupIdentifiers(
			environment: environment,
			selectedGroup: selectedGroup,
			logCategory: "SettingsView.Wizard"
		)
		switch result {
		case .success(let finalized):
			return finalized
		case .failure(let error):
			await MainActor.run {
				setError(error.userMessage)
			}
			return nil
		}
	}

	private func configureStepValidationError(for environment: UemEnvironment)
		-> String?
	{
		EnvironmentWizardCoordinator.configureStepValidationError(
			for: environment
		)
	}

	private func finalizedEnvironmentValidationError(
		for environment: UemEnvironment
	) -> String? {
		EnvironmentWizardCoordinator.finalizedEnvironmentValidationError(
			for: environment
		)
	}

	private func removeEnvironment() {
		guard canRemoveEnvironment else { return }
		guard draftEnvironments.indices.contains(selectedEnvironmentIndex),
			storedEnvironments.indices.contains(selectedEnvironmentIndex)
		else { return }

		let removedIndex = selectedEnvironmentIndex
		storedEnvironments.remove(at: removedIndex)
		draftEnvironments.remove(at: removedIndex)

		if activeEnvironmentIndex == removedIndex {
			activeEnvironmentIndex = max(0, removedIndex - 1)
		} else if activeEnvironmentIndex > removedIndex {
			activeEnvironmentIndex -= 1
		}

		if selectedEnvironmentIndex >= draftEnvironments.count {
			selectedEnvironmentIndex = max(0, draftEnvironments.count - 1)
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
			if let groupId = group.resolvedGroupId, !groupId.isEmpty {
				env.orgGroupId = groupId
			}
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
		Task {
			let home = FileManager.default.homeDirectoryForCurrentUser.path
			let munkiToolsPath = "/usr/local/munki"
			let munkiPreferencesPath = "\(home)/Library/Preferences/com.googlecode.munki.munkiimport"
			let prefsPlistPath = "\(munkiPreferencesPath).plist"
			let munkiimportPath = "\(munkiToolsPath)/munkiimport"

			let defaultCatalogRead = readDefaultsValue(
				atPath: munkiPreferencesPath,
				key: "default_catalog"
			)
			let pkgInfoExtensionRead = readDefaultsValue(
				atPath: munkiPreferencesPath,
				key: "pkginfo_extension"
			)
			let repoURLRead = readDefaultsValue(
				atPath: munkiPreferencesPath,
				key: "repo_url"
			)

			let defaultCatalogValue = defaultCatalogRead.value ?? ""
			let pkgInfoExtensionValue = pkgInfoExtensionRead.value ?? ""
			let repoURLValue = repoURLRead.value ?? ""

			let defaultCatalogOK = defaultCatalogValue == "device_catalog"
			let pkgInfoExtensionOK = pkgInfoExtensionValue == ".plist"
			let repoURLOK = repoURLValue.hasSuffix("cache")
			let munkiToolsInstalledOK = FileManager.default.fileExists(
				atPath: munkiimportPath
			)
			let munkiPreferencesFoundOK = FileManager.default.fileExists(
				atPath: prefsPlistPath
			)

			let checks: [(name: String, passed: Bool, detail: String)] = [
				(
					"default_catalog",
					defaultCatalogOK,
					defaultCatalogRead.value.map { "got '\($0)'" }
						?? defaultCatalogRead.error ?? "not found"
				),
				(
					"pkginfo_extension",
					pkgInfoExtensionOK,
					pkgInfoExtensionRead.value.map { "got '\($0)'" }
						?? pkgInfoExtensionRead.error ?? "not found"
				),
				(
					"repo_url",
					repoURLOK,
					repoURLRead.value.map { "got '\($0)'" }
						?? repoURLRead.error ?? "not found"
				),
				(
					"munkiimport",
					munkiToolsInstalledOK,
					munkiimportPath
				),
				(
					"munki preferences plist",
					munkiPreferencesFoundOK,
					prefsPlistPath
				),
			]

			let failures = checks
				.filter { !$0.passed }
				.map { "\($0.name): \($0.detail)" }

				await MainActor.run {
					if failures.isEmpty {
						showInfoBar(
							.success(
								title: "Validation OK",
								message:
									"Juice configuration and additional tools checks passed"
							)
						)
					} else {
						validationFailureDialogMessage = failures.joined(
							separator: "\n"
						)
						showValidationFailureDialog = true
					}
				}
			}
		}

	private func readDefaultsValue(atPath path: String, key: String) -> (
		value: String?, error: String?
	) {
		let process = Process()
		let outputPipe = Pipe()
		let errorPipe = Pipe()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
		process.arguments = ["read", path, key]
		process.standardOutput = outputPipe
		process.standardError = errorPipe

		do {
			try process.run()
			process.waitUntilExit()
			let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
			let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
			let output = String(data: outputData, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines)
			let error = String(data: errorData, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines)
			guard process.terminationStatus == 0 else {
				return (nil, error?.isEmpty == false ? error : "read failed")
			}
			guard let output, !output.isEmpty else {
				return (nil, "empty value")
			}
			return (output, nil)
		} catch {
			return (nil, error.localizedDescription)
		}
	}

	private func updateDatabase() {
		guard
			let appsEndpoint = effectiveDatabaseAppsEndpoint,
			let appsURL = URL(string: appsEndpoint),
			let recipesEndpoint = effectiveDatabaseRecipesEndpoint,
			let recipesURL = URL(string: recipesEndpoint)
		else {
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
				let cache = LocalCatalogCache()
				let remoteVersion = try? await fetchRemoteDatabaseVersion()
				try await cache.refreshFromEndpoints(
					appsURL: appsURL,
					recipesURL: recipesURL,
					remoteVersion: remoteVersion,
					forceRefresh: true
				)
				await catalog.loadLocalCatalog()
				let appsVersion =
					await cache.loadCachedOrBundledVersion(for: "apps.json")
					?? "unknown"
				let recipesVersion =
					await cache.loadCachedOrBundledVersion(for: "recipes.json")
					?? "unknown"
				let versionSuffix =
					remoteVersion.map { ", remote version \($0)" } ?? ""
				showInfoBar(
					.success(
						title: "Database Updated",
						message:
							"Catalog refreshed from direct endpoints (apps.json: \(appsVersion), recipes.json: \(recipesVersion)\(versionSuffix))."
					)
				)
			} catch {
				let message = describeDatabaseUpdateError(error)
				showInfoBar(
					.error(
						title: "Update Failed",
						message: message
					)
				)
			}
		}
	}

	private func showLogsWindow() {
		#if os(macOS)
			AppLogsWindowController.shared.show()
			showInfoBar(
				.success(
					title: "Logs Window",
					message: "Opened Juice Logs window."
				)
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

	private var effectiveDatabaseAppsEndpoint: String? {
		let trimmed = databaseAppsEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		return trimmed.isEmpty
			? settingsState.databaseAppsEndpoint ?? SettingsStore.defaultAppsEndpoint
			: trimmed
	}

	private var effectiveDatabaseRecipesEndpoint: String? {
		let trimmed = databaseRecipesEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		return trimmed.isEmpty
			? settingsState.databaseRecipesEndpoint
				?? SettingsStore.defaultRecipesEndpoint
			: trimmed
	}

	private var effectiveDatabaseVersionEndpoint: String? {
		let trimmed = databaseVersionEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		return trimmed.isEmpty
			? settingsState.databaseVersionEndpoint
				?? SettingsStore.defaultVersionEndpoint
			: trimmed
	}

	private func applyAdvancedDatabaseSettings() {
		var updated = settingsState
		let apps = databaseAppsEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let recipes = databaseRecipesEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let version = databaseVersionEndpointOverride.trimmingCharacters(
			in: .whitespacesAndNewlines
		)

		if !apps.isEmpty { updated.databaseAppsEndpoint = apps }
		if !recipes.isEmpty { updated.databaseRecipesEndpoint = recipes }
		if !version.isEmpty { updated.databaseVersionEndpoint = version }
		updated.sparkleAutoCheckEnabled = sparkleAutoCheckEnabled
		updated.sparkleCheckIntervalHours = AppUpdaterService.normalizedIntervalHours(
			sparkleCheckIntervalHours
		)
		updated.sparkleAutoDownloadEnabled = sparkleAutoDownloadEnabled

		settingsState = updated
		persistSettings(activeIndex: activeEnvironmentIndex)
		showInfoBar(
			.success(
				title: "Advanced Settings Saved",
				message: "Database endpoints updated."
			)
		)
	}

	private func checkForNewDatabase() {
		guard !isCheckingDatabase else { return }
		let endpoint = effectiveDatabaseVersionEndpoint?.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let endpointLabel: String
		if let endpoint, !endpoint.isEmpty {
			endpointLabel = endpoint
		} else {
			endpointLabel = "not configured"
		}
		isCheckingDatabase = true
		showInfoBar(
			.info(
				title: "Checking Database",
				message: "Checking database version endpoint: \(endpointLabel)",
				showsActivity: true,
				autoDismiss: false
			)
		)
		Task {
			defer { isCheckingDatabase = false }
			do {
				let remoteVersion = try await fetchRemoteDatabaseVersion()
				let cache = LocalCatalogCache()
				let localAppsVersion =
					await cache.loadCachedOrBundledVersion(for: "apps.json")
				let localRecipesVersion =
					await cache.loadCachedOrBundledVersion(for: "recipes.json")
				guard let localAppsVersion else {
					showInfoBar(
						.warning(
							title: "Database Version Unknown",
							message:
								"Local apps.json version is missing. Run Update Database."
						)
					)
					return
				}
				let outcome = compareDatabaseVersions(
					remote: remoteVersion,
					local: localAppsVersion
				)
				switch outcome {
				case .orderedDescending:
					showInfoBar(
						.info(
							title: "Database Update Available",
							message:
								"Remote version \(remoteVersion) is newer than local \(localAppsVersion)."
						)
					)
				case .orderedSame:
					var message = "Database is current at version \(localAppsVersion)."
					if let localRecipesVersion,
						localRecipesVersion != localAppsVersion
					{
						message +=
							" Warning: recipes.json version is \(localRecipesVersion)."
					}
					showInfoBar(.success(title: "Database Current", message: message))
				case .orderedAscending:
					showInfoBar(
						.warning(
							title: "Local Database Newer",
							message:
								"Local version \(localAppsVersion) is newer than remote \(remoteVersion)."
						)
					)
				}
			} catch {
				showInfoBar(
					.error(
						title: "Database Check Failed",
						message: error.localizedDescription
					)
				)
			}
		}
	}

	private func fetchRemoteDatabaseVersion() async throws -> String {
		guard
			let endpoint = effectiveDatabaseVersionEndpoint,
			let url = URL(string: endpoint)
		else {
			throw NSError(
				domain: "SettingsView",
				code: 1,
				userInfo: [
					NSLocalizedDescriptionKey:
						"Database version endpoint is not configured."
				]
			)
		}

		let (data, response) = try await URLSession.shared.data(from: url)
		guard let http = response as? HTTPURLResponse,
			(200...299).contains(http.statusCode)
		else {
			throw NSError(
				domain: "SettingsView",
				code: 2,
				userInfo: [
					NSLocalizedDescriptionKey:
						"Database version endpoint failed: \(endpoint)"
				]
			)
		}

		if let text = String(data: data, encoding: .utf8)?
			.trimmingCharacters(in: .whitespacesAndNewlines),
			!text.isEmpty
		{
			if isValidDatabaseVersion(text) {
				return text
			}
			if let json = try? JSONSerialization.jsonObject(with: data)
				as? [String: Any]
			{
				let candidates = ["version", "dbVersion"]
				for key in candidates {
					guard let rawValue = json[key] else { continue }
					if let value = normalizeDatabaseVersionValue(rawValue),
						isValidDatabaseVersion(value)
					{
						return value
					}
				}
			}
		}

		throw NSError(
			domain: "SettingsView",
			code: 3,
			userInfo: [
				NSLocalizedDescriptionKey:
					"Version response is invalid. Expected YYYYMMDD or JSON {\"version\":\"YYYYMMDD\"} / {\"version\":YYYYMMDD}."
			]
		)
	}

	private func isValidDatabaseVersion(_ value: String) -> Bool {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.count == 8, trimmed.allSatisfy(\.isNumber) else {
			return false
		}
		let formatter = DateFormatter()
		formatter.calendar = Calendar(identifier: .gregorian)
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		formatter.dateFormat = "yyyyMMdd"
		guard let parsed = formatter.date(from: trimmed) else {
			return false
		}
		return formatter.string(from: parsed) == trimmed
	}

	private func normalizeDatabaseVersionValue(_ rawValue: Any) -> String? {
		if let value = rawValue as? String {
			return value.trimmingCharacters(in: .whitespacesAndNewlines)
		}
		if let value = rawValue as? NSNumber {
			return value.stringValue
		}
		return nil
	}

	private func compareDatabaseVersions(
		remote: String,
		local: String
	) -> ComparisonResult {
		let remoteValue = Int(remote) ?? 0
		let localValue = Int(local) ?? 0
		if remoteValue > localValue { return .orderedDescending }
		if remoteValue < localValue { return .orderedAscending }
		return .orderedSame
	}

	private func describeDatabaseUpdateError(_ error: Error) -> String {
		if let catalogError = error as? CatalogError {
			return catalogError.localizedDescription
		}
		return error.localizedDescription
	}

	private func applyProminentTint(position: Double, persist: Bool) {
		let clamped = min(max(position, 0), 1)
		let color = JuiceStyleConfig.spectrumColor(at: clamped)
		let hex =
			JuiceStyleConfig.hexString(from: color)
			?? JuiceStyleConfig.defaultTintHex
		settingsState.prominentButtonTintHex = hex
		applyEffectiveProminentTint()
		if persist {
			persistSettings(activeIndex: activeEnvironmentIndex)
		}
	}

	private func applyUseActiveEnvironmentBrandingTint(
		_ enabled: Bool,
		persist: Bool
	) {
		useActiveEnvironmentBrandingTint = enabled
		settingsState.useActiveEnvironmentBrandingTint = enabled
		applyEffectiveProminentTint()
		if persist {
			persistSettings(activeIndex: activeEnvironmentIndex)
		}
	}

	private func applySparklePreferences(persist: Bool) {
		appUpdater.applyPreferences(
			autoCheckEnabled: sparkleAutoCheckEnabled,
			checkIntervalHours: sparkleCheckIntervalHours,
			autoDownloadEnabled: sparkleAutoDownloadEnabled
		)
		if persist {
			persistSettings(activeIndex: activeEnvironmentIndex)
		}
	}

	private func applyEffectiveProminentTint() {
		if useActiveEnvironmentBrandingTint,
			let brandingHex = resolveActiveEnvironmentBrandingHighlightHex()
		{
			styleConfig.applyProminentTint(hex: brandingHex)
			return
		}
		styleConfig.applyProminentTint(
			hex: settingsState.prominentButtonTintHex
		)
	}

	private func resolveActiveEnvironmentBrandingHighlightHex() -> String? {
		guard let environment = activeEnvironmentForTintResolution() else {
			return nil
		}
		let orgGroupUuid = environment.orgGroupUuid.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		guard !orgGroupUuid.isEmpty else { return nil }
		guard
			let branding = loadCachedBrandingConfigForTint(
				orgGroupUUID: orgGroupUuid
			),
			!isDefaultBrandingConfig(branding)
		else {
			return nil
		}
		return JuiceStyleConfig.sanitizedHex(
			branding.brandingColor?.highlightColor
		)
	}

	private func activeEnvironmentForTintResolution() -> UemEnvironment? {
		if let activeUuid = settingsState.activeEnvironmentUuid?
			.trimmingCharacters(in: .whitespacesAndNewlines),
			!activeUuid.isEmpty,
			let match = storedEnvironments.first(where: {
				$0.orgGroupUuid.trimmingCharacters(
					in: .whitespacesAndNewlines
				) == activeUuid
			})
		{
			return match
		}
		return storedEnvironments[safe: activeEnvironmentIndex]
	}

	private func loadCachedBrandingConfigForTint(orgGroupUUID: String)
		-> BrandingConfig?
	{
		let key = orgGroupUUID.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return nil }
		do {
			let appData = FileManager.default.urls(
				for: .applicationSupportDirectory,
				in: .userDomainMask
			)[0]
			let path =
				appData
				.appendingPathComponent("Fetch")
				.appendingPathComponent("BrandingConfigs")
				.appendingPathComponent("\(key).json")
			guard FileManager.default.fileExists(atPath: path.path) else {
				return nil
			}
			let data = try Data(contentsOf: path)
			return try JSONDecoder().decode(BrandingConfig.self, from: data)
		} catch {
			return nil
		}
	}

	private func normalizedString(_ value: String?) -> String {
		value?
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased() ?? ""
	}

	private func normalizedHex(_ value: String?) -> String {
		value?
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.uppercased() ?? ""
	}

	private func isDefaultBrandingConfig(_ config: BrandingConfig?) -> Bool {
		guard let config else { return false }
		guard let colors = config.brandingColor else { return false }
		return normalizedString(config.themeCssUrl) == ""
			&& normalizedString(config.customCss) == ""
			&& normalizedString(config.primaryLogoUrl)
				== "https://www.omnissa.com/products/workspace-one-unified-endpoint-management"
			&& normalizedString(config.logoUrl) == ""
			&& normalizedHex(colors.headerColor) == "#002538"
			&& normalizedHex(colors.headerFontColor) == "#FFFFFF"
			&& normalizedHex(colors.navigationColor) == "#FFFFFF"
			&& normalizedHex(colors.navigationFontColor) == "#3C4653"
			&& normalizedHex(colors.highlightColor) == "#007CBB"
			&& normalizedHex(colors.highlightFontColor) == "#FFFFFF"
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
		databaseAppsEndpointOverride = ""
		databaseRecipesEndpointOverride = ""
		databaseVersionEndpointOverride = ""
		useActiveEnvironmentBrandingTint = false
		settingsState.useActiveEnvironmentBrandingTint = false
		prominentTintPosition = JuiceStyleConfig.spectrumPosition(
			forHex: JuiceStyleConfig.defaultTintHex
		)
		settingsState.prominentButtonTintHex = JuiceStyleConfig.defaultTintHex
		sparkleAutoCheckEnabled = true
		sparkleCheckIntervalHours = 24
		sparkleAutoDownloadEnabled = false
		settingsState.sparkleAutoCheckEnabled = true
		settingsState.sparkleCheckIntervalHours = 24
		settingsState.sparkleAutoDownloadEnabled = false
		applySparklePreferences(persist: false)
		applyEffectiveProminentTint()
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
			eulaAccepted: settingsState.eulaAccepted,
			databaseAppsEndpoint: settingsState.databaseAppsEndpoint,
			databaseRecipesEndpoint: settingsState.databaseRecipesEndpoint,
			databaseServerUrl: settingsState.databaseServerUrl,
			databaseVersionEndpoint: settingsState.databaseVersionEndpoint,
			databaseDownloadEndpoint: settingsState.databaseDownloadEndpoint,
			storagePath: settingsState.storagePath,
			prominentButtonTintHex: settingsState.prominentButtonTintHex,
				useActiveEnvironmentBrandingTint:
					settingsState.useActiveEnvironmentBrandingTint,
				activeEnvironmentDeviceCount: settingsState.activeEnvironmentDeviceCount,
				activeEnvironmentAppCount: settingsState.activeEnvironmentAppCount,
				availableUpdatesCount: settingsState.availableUpdatesCount,
				sparkleAutoCheckEnabled: settingsState.sparkleAutoCheckEnabled,
				sparkleCheckIntervalHours: settingsState.sparkleCheckIntervalHours,
				sparkleAutoDownloadEnabled: settingsState.sparkleAutoDownloadEnabled
			)
			settingsState = updated
			do {
				try settingsStore.save(updated)
				applySparklePreferences(persist: false)
				Task {
				await Runtime.Config.updateEnvironments(
					storedEnvironments,
					activeUuid: activeUuid
				)
				await MainActor.run {
					applyEffectiveProminentTint()
				}
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

	private func persistWidgetCountSnapshot(deviceCount: Int?, appCount: Int?) {
		var updated = settingsState
		updated.activeEnvironmentDeviceCount = deviceCount
		updated.activeEnvironmentAppCount = appCount
		settingsState = updated
		try? settingsStore.save(updated)
	}

	private func showInfoBar(_ state: SettingsInfoBarState) {
		let level: AppLogLevel
		switch state.severity {
		case .info:
			level = .info
		case .success:
			level = .info
		case .warning:
			level = .warning
		case .error:
			level = .error
		}
		appLog(level, "SettingsView", "\(state.title): \(state.message)")
		infoBarState = state
		guard state.autoDismiss else { return }
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
			sparkleAutoCheckEnabled = loaded.sparkleAutoCheckEnabled
			sparkleCheckIntervalHours = loaded.sparkleCheckIntervalHours
			sparkleAutoDownloadEnabled = loaded.sparkleAutoDownloadEnabled
			useActiveEnvironmentBrandingTint =
				loaded.useActiveEnvironmentBrandingTint
			prominentTintPosition = JuiceStyleConfig.spectrumPosition(
				forHex: loaded.prominentButtonTintHex
			)
			storedEnvironments = seededEnvs
			draftEnvironments = seededEnvs
			activeEnvironmentIndex = SettingsView.activeIndex(
				for: loaded.activeEnvironmentUuid
					?? model.settings.activeEnvironmentUuid,
				in: seededEnvs
			)
			selectedEnvironmentIndex = activeEnvironmentIndex
			applyEffectiveProminentTint()
		}
		appUpdater.applyPreferences(
			autoCheckEnabled: loaded.sparkleAutoCheckEnabled,
			checkIntervalHours: loaded.sparkleCheckIntervalHours,
			autoDownloadEnabled: loaded.sparkleAutoDownloadEnabled
		)
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
			sparkleAutoCheckEnabled = imported.sparkleAutoCheckEnabled
			sparkleCheckIntervalHours = imported.sparkleCheckIntervalHours
			sparkleAutoDownloadEnabled = imported.sparkleAutoDownloadEnabled
			useActiveEnvironmentBrandingTint =
				imported.useActiveEnvironmentBrandingTint
			prominentTintPosition = JuiceStyleConfig.spectrumPosition(
				forHex: imported.prominentButtonTintHex
			)
			storedEnvironments = seededEnvs
			draftEnvironments = seededEnvs
			activeEnvironmentIndex = SettingsView.activeIndex(
				for: imported.activeEnvironmentUuid
					?? model.settings.activeEnvironmentUuid,
				in: seededEnvs
			)
			selectedEnvironmentIndex = activeEnvironmentIndex
			applyEffectiveProminentTint()
		}
		appUpdater.applyPreferences(
			autoCheckEnabled: imported.sparkleAutoCheckEnabled,
			checkIntervalHours: imported.sparkleCheckIntervalHours,
			autoDownloadEnabled: imported.sparkleAutoDownloadEnabled
		)
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
		sparkleAutoCheckEnabled = imported.sparkleAutoCheckEnabled
		sparkleCheckIntervalHours = imported.sparkleCheckIntervalHours
		sparkleAutoDownloadEnabled = imported.sparkleAutoDownloadEnabled
		useActiveEnvironmentBrandingTint =
			imported.useActiveEnvironmentBrandingTint
		prominentTintPosition = JuiceStyleConfig.spectrumPosition(
			forHex: imported.prominentButtonTintHex
		)
		storedEnvironments = seededEnvs
		draftEnvironments = seededEnvs
		activeEnvironmentIndex = SettingsView.activeIndex(
			for: imported.activeEnvironmentUuid
				?? model.settings.activeEnvironmentUuid,
			in: seededEnvs
		)
		selectedEnvironmentIndex = activeEnvironmentIndex
		applyEffectiveProminentTint()
		appUpdater.applyPreferences(
			autoCheckEnabled: imported.sparkleAutoCheckEnabled,
			checkIntervalHours: imported.sparkleCheckIntervalHours,
			autoDownloadEnabled: imported.sparkleAutoDownloadEnabled
		)
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
	let showsActivity: Bool
	let autoDismiss: Bool

	init(
		title: String,
		message: String,
		severity: SettingsInfoBarSeverity,
		showsActivity: Bool = false,
		autoDismiss: Bool = true
	) {
		self.title = title
		self.message = message
		self.severity = severity
		self.showsActivity = showsActivity
		self.autoDismiss = autoDismiss
	}

	static func info(
		title: String,
		message: String,
		showsActivity: Bool = false,
		autoDismiss: Bool = true
	) -> SettingsInfoBarState {
		SettingsInfoBarState(
			title: title,
			message: message,
			severity: .info,
			showsActivity: showsActivity,
			autoDismiss: autoDismiss
		)
	}

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
	case info
	case success
	case warning
	case error

	var tint: Color {
		switch self {
		case .info: return Color.blue
		case .success: return Color.green
		case .warning: return Color.orange
		case .error: return Color.red
		}
	}

	var background: Color {
		switch self {
		case .info: return Color.blue.opacity(0.12)
		case .success: return Color.green.opacity(0.12)
		case .warning: return Color.orange.opacity(0.12)
		case .error: return Color.red.opacity(0.12)
		}
	}
}

private struct SettingsInfoBar: View {
	let state: SettingsInfoBarState

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
		HStack(alignment: .top, spacing: 12) {
			if state.showsActivity {
				ProgressView()
					.controlSize(.small)
					.tint(state.severity.tint)
					.padding(.top, 2)
			} else {
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(state.severity.tint)
					.font(.system(size: 14, weight: .semibold))
			}
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
		.background {
			if #available(macOS 26.0, iOS 26.0, *) {
				ZStack {
					shape.fill(state.severity.background)
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
				}
			} else {
				shape
					.fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
					.overlay(shape.fill(state.severity.background.opacity(0.40)))
			}
		}
		.overlay(shape.strokeBorder(state.severity.tint.opacity(0.35)))
	}
}

extension Array {
	fileprivate subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
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
						.fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
				}
			}
			.overlay(shape.strokeBorder(.white.opacity(0.12)))
	}
}

private struct ValidationFailureDialog: View {
	let title: String
	let message: String
	let onOK: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text(title)
				.font(.title3.weight(.semibold))

			Text(message)
				.font(.system(size: 13, weight: .medium))
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
				.textSelection(.enabled)

			Divider()

			HStack {
				Spacer()
				Button("OK") { onOK() }
					.juiceGradientGlassProminentButtonStyle(controlSize: .large)
			}
		}
		.padding(20)
		.frame(minWidth: 540, minHeight: 220, alignment: .topLeading)
	}
}

private struct AdvancedConfigurationSheet: View {
	@Binding var databaseAppsEndpointOverride: String
	@Binding var databaseRecipesEndpointOverride: String
	@Binding var databaseVersionEndpointOverride: String
	@Binding var prominentTintPosition: Double
	@Binding var useActiveEnvironmentBrandingTint: Bool
	@Binding var sparkleAutoCheckEnabled: Bool
	@Binding var sparkleCheckIntervalHours: Int
	@Binding var sparkleAutoDownloadEnabled: Bool
	let currentDatabaseAppsEndpoint: String?
	let currentDatabaseRecipesEndpoint: String?
	let currentDatabaseVersionEndpoint: String?
	let onProminentTintChanged: (Double) -> Void
	let onProminentTintCommit: (Double) -> Void
	let onUseActiveBrandingTintChanged: (Bool) -> Void
	let onSparkleAutoCheckChanged: (Bool) -> Void
	let onSparkleCheckIntervalChanged: (Int) -> Void
	let onSparkleAutoDownloadChanged: (Bool) -> Void
	let onResetProminentTint: () -> Void
	let onCancel: () -> Void
	let onSave: () -> Void
	let onReset: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			VStack(alignment: .leading, spacing: 2) {
				Text("Advanced Configuration")
					.font(.title3.weight(.semibold))
				Text("Configure database endpoint overrides.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			SettingsGlassPanel {
				VStack(alignment: .leading, spacing: 10) {
					Text("Database Settings")
						.font(.system(size: 14, weight: .semibold))
						.padding(.bottom, 1)

					Text("Database Apps Endpoint")
						.font(.caption.weight(.semibold))
					TextField(
						"Database Apps Endpoint",
						text: $databaseAppsEndpointOverride,
						prompt: Text(
							currentDatabaseAppsEndpoint
								?? SettingsStore.defaultAppsEndpoint
						)
					)
					.textFieldStyle(.roundedBorder)

					Text("Database Recipes Endpoint")
						.font(.caption.weight(.semibold))
					TextField(
						"Database Recipes Endpoint",
						text: $databaseRecipesEndpointOverride,
						prompt: Text(
							currentDatabaseRecipesEndpoint
								?? SettingsStore.defaultRecipesEndpoint
						)
					)
					.textFieldStyle(.roundedBorder)

					Text("Database Version Endpoint")
						.font(.caption.weight(.semibold))
					TextField(
						"Database Version Endpoint",
						text: $databaseVersionEndpointOverride,
						prompt: Text(
							currentDatabaseVersionEndpoint
								?? SettingsStore.defaultVersionEndpoint
						)
					)
					.textFieldStyle(.roundedBorder)

					Divider()
						.padding(.vertical, 4)

					Text("Appearance")
						.font(.system(size: 14, weight: .semibold))
						.padding(.bottom, 1)

					Toggle(
						"Use active environment branding highlight color",
						isOn: $useActiveEnvironmentBrandingTint
					)
					.toggleStyle(.switch)
					.onChange(of: useActiveEnvironmentBrandingTint) {
						_,
						newValue in
						onUseActiveBrandingTintChanged(newValue)
					}

					HStack(alignment: .center, spacing: 12) {
						Text("Prominent Button Color")
							.font(.caption.weight(.semibold))
						JuiceSpectrumPicker(
							position: $prominentTintPosition,
							onChanged: onProminentTintChanged,
							onCommit: onProminentTintCommit
						)
						.frame(width: 220, height: 28)
						Button("Preview") {}
							.juiceGradientGlassProminentButtonStyle(
								controlSize: .large
							)
						Button("Reset to Default") {
							onResetProminentTint()
						}
						.explicitClearGlassButtonStyle(controlSize: .large)
						Spacer(minLength: 0)
					}

					Divider()
						.padding(.vertical, 4)

					Text("App Updates")
						.font(.system(size: 14, weight: .semibold))
						.padding(.bottom, 1)

					Toggle(
						"Automatically check for updates",
						isOn: $sparkleAutoCheckEnabled
					)
					.toggleStyle(.switch)
					.onChange(of: sparkleAutoCheckEnabled) { _, newValue in
						onSparkleAutoCheckChanged(newValue)
					}

					Picker(
						"Update Check Interval",
						selection: $sparkleCheckIntervalHours
					) {
						Text("Daily").tag(24)
						Text("Weekly").tag(168)
					}
					.pickerStyle(.segmented)
					.onChange(of: sparkleCheckIntervalHours) { _, newValue in
						onSparkleCheckIntervalChanged(newValue)
					}

					Toggle(
						"Automatically download updates when available",
						isOn: $sparkleAutoDownloadEnabled
					)
					.toggleStyle(.switch)
					.onChange(of: sparkleAutoDownloadEnabled) { _, newValue in
						onSparkleAutoDownloadChanged(newValue)
					}
				}
			}

			Spacer(minLength: 0)

			Divider()

			HStack(spacing: 10) {
				Button("Cancel") { onCancel() }
					.nativeActionButtonStyle(.secondary, controlSize: .large)
				Spacer()
				Button("Reset App Configuration") { onReset() }
					.nativeActionButtonStyle(.secondary, controlSize: .large)
					.juiceHelp(HelpText.Settings.resetConfiguration)
				Button("Save") { onSave() }
					.juiceGradientGlassProminentButtonStyle(controlSize: .large)
			}
		}
		.padding(13)
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .topLeading
		)
	}
}

private struct JuiceSpectrumPicker: View {
	@Binding var position: Double
	let onChanged: (Double) -> Void
	let onCommit: (Double) -> Void

	var body: some View {
		GeometryReader { proxy in
			let width = max(proxy.size.width, 1)
			let clamped = min(max(position, 0), 1)
			let thumbX = clamped * width

			ZStack(alignment: .leading) {
				Capsule(style: .continuous)
					.fill(LinearGradient.juice)
					.overlay {
						Capsule(style: .continuous)
							.strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
					}

				Circle()
					.fill(.white)
					.overlay {
						Circle().strokeBorder(
							.black.opacity(0.25),
							lineWidth: 0.8
						)
					}
					.frame(width: 20, height: 20)
					.shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
					.position(x: thumbX, y: proxy.size.height / 2)
			}
			.contentShape(Rectangle())
			.gesture(
				DragGesture(minimumDistance: 0)
					.onChanged { value in
						let next = min(max(value.location.x / width, 0), 1)
						position = next
						onChanged(next)
					}
					.onEnded { value in
						let next = min(max(value.location.x / width, 0), 1)
						position = next
						onCommit(next)
					}
			)
		}
		.frame(minHeight: 24)
		.accessibilityLabel("Prominent Button Color Spectrum")
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

private struct ActionsButtonSizePreferenceKey: PreferenceKey {
	static let defaultValue: [CGSize] = []

	static func reduce(value: inout [CGSize], nextValue: () -> [CGSize]) {
		value.append(contentsOf: nextValue())
	}
}

private extension View {
	@ViewBuilder
	func settingsActionsButtonStyle(prominent: Bool) -> some View {
		#if os(macOS)
			if #available(macOS 26.0, *) {
				if prominent {
					self.juiceGradientGlassProminentButtonStyle(controlSize: .large)
				} else {
					self.explicitRegularGlassButtonStyle(controlSize: .large)
				}
			} else {
				if prominent {
					self
						.buttonStyle(.borderedProminent)
						.controlSize(.large)
						.buttonBorderShape(.automatic)
						.tint(JuiceStyleConfig.defaultAccentColor)
				} else {
					self
						.buttonStyle(.bordered)
						.controlSize(.large)
						.buttonBorderShape(.automatic)
				}
			}
		#else
			if prominent {
				self.juiceGradientGlassProminentButtonStyle(controlSize: .large)
			} else {
				self.explicitRegularGlassButtonStyle(controlSize: .large)
			}
		#endif
	}

	func reportActionsButtonSize() -> some View {
		background(
			GeometryReader { proxy in
				Color.clear.preference(
					key: ActionsButtonSizePreferenceKey.self,
					value: [proxy.size]
				)
			}
		)
	}
}

#Preview {
	SettingsView(model: .sample)
		.frame(width: 700, height: 600)
		.background(JuiceGradient())
}
