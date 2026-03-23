import SwiftUI
import Runtime

private let onboardingSheetMinWidth: CGFloat = 620
private let onboardingSheetMinHeight: CGFloat = 560

struct OnboardingFlowView: View {
	enum Stage {
		case eula
		case environment
	}

	let onCompleted: () -> Void
	let onDeclined: () -> Void

	@State private var stage: Stage = .eula
	@State private var acceptedEula = false
	@State private var settingsStore = SettingsStore()
	@State private var draftEnvironment = UemEnvironment()
	@State private var wizardStep: AddEnvironmentStep = .configureEnvironment
	@State private var wizardErrorMessage: String? = nil
	@State private var wizardOrgGroups: [OrganizationGroup] = []
	@State private var selectedOrgGroupName: String = ""
	@State private var isLoadingOrgGroups = false
	@State private var isSaving = false

	private let oauthRegions: [String] = [
		"https://apac.uemauth.workspaceone.com",
		"https://uat.uemauth.workspaceone.com",
		"https://na.uemauth.workspaceone.com",
		"https://emea.uemauth.workspaceone.com",
	]

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text("Juice Setup")
				.font(.system(size: 28, weight: .bold))

			if stage == .eula {
				Text("Review and accept the EULA to continue.")
					.font(.system(size: 14, weight: .regular))
					.foregroundStyle(.secondary)
					.padding(.top, -12)
			}

			stageBody
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.padding(22)
		.frame(minWidth: onboardingSheetMinWidth, minHeight: onboardingSheetMinHeight, alignment: .topLeading)
		.onAppear {
			appLog(.info, "Onboarding", "onboarding.started")
		}
	}

	@ViewBuilder
	private var stageBody: some View {
		switch stage {
		case .eula:
			eulaStage
		case .environment:
			EnvironmentWizard(
				mode: .add,
				step: $wizardStep,
				draft: $draftEnvironment,
				errorMessage: $wizardErrorMessage,
				orgGroups: $wizardOrgGroups,
				isLoadingOrgGroups: $isLoadingOrgGroups,
				isSaving: $isSaving,
				selectedOrgGroupName: $selectedOrgGroupName,
				horizontalPadding: 0,
				oauthRegions: oauthRegions,
				onSelectOrgGroup: selectWizardOrgGroup,
				onCancel: declineAndQuit,
				onBack: wizardStepBack,
				onNext: wizardStepForward,
				onSave: commitOnboardingEnvironment
			)
			.padding(.top, -12)
		}
	}

	private var eulaStage: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("License Agreement")
				.font(.system(size: 18, weight: .semibold))
			ScrollView {
				Text(EulaText.fullText)
					.font(.system(size: 12, weight: .regular))
					.frame(maxWidth: .infinity, alignment: .leading)
					.textSelection(.enabled)
			}
			.frame(maxHeight: .infinity)
			.padding(10)
			.background(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.fill(.ultraThinMaterial)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.stroke(Color.white.opacity(0.12), lineWidth: 1)
			)

			Toggle("I have read and accept the EULA", isOn: $acceptedEula)
				.toggleStyle(.checkbox)

			HStack(spacing: 10) {
				Button("Decline") {
					declineAndQuit()
				}
				.nativeActionButtonStyle(.secondary, controlSize: .large)
				Spacer()
				Button("Continue") {
					appLog(.info, "Onboarding", "onboarding.eula.accepted")
					stage = .environment
				}
				.juiceGradientGlassProminentButtonStyle(controlSize: .large)
				.disabled(!acceptedEula)
			}
		}
	}

	private func declineAndQuit() {
		appLog(.warning, "Onboarding", "onboarding.eula.declined")
		onDeclined()
	}

	private func wizardStepBack() {
		wizardErrorMessage = nil
		if wizardStep == .selectOrganizationGroup {
			wizardStep = .configureEnvironment
		}
	}

	private func wizardStepForward() {
		wizardErrorMessage = nil
		if let validationError = EnvironmentWizardCoordinator
			.configureStepValidationError(for: draftEnvironment)
		{
			wizardErrorMessage = validationError
			return
		}
		wizardStep = .selectOrganizationGroup
		wizardOrgGroups = []
		selectedOrgGroupName = ""
		isLoadingOrgGroups = true
		Task {
			let groups = await EnvironmentWizardCoordinator.fetchOrgGroups(
				for: draftEnvironment
			)
			await MainActor.run {
				isLoadingOrgGroups = false
				guard !groups.isEmpty else {
					wizardErrorMessage =
						"No Organization Groups found. Verify credentials and tenant URL."
					return
				}
				wizardOrgGroups = groups
				let selectedName = groups.first?.name ?? ""
				selectWizardOrgGroup(selectedName)
			}
		}
	}

	private func selectWizardOrgGroup(_ name: String) {
		selectedOrgGroupName = name
		guard
			let selected = wizardOrgGroups.first(where: { $0.name == name }),
			let groupName = selected.name,
			let groupId = selected.resolvedGroupId,
			!groupId.isEmpty
		else { return }
		draftEnvironment.orgGroupName = groupName
		draftEnvironment.orgGroupId = groupId
		draftEnvironment.orgGroupUuid = ""
	}

	private func commitOnboardingEnvironment() {
		wizardErrorMessage = nil
		guard case .selectOrganizationGroup = wizardStep else {
			wizardErrorMessage = "Select an Organization Group before saving."
			return
		}
		guard
			let selectedGroup = EnvironmentWizardCoordinator
				.resolveSelectedOrgGroupForSave(
					selectedName: selectedOrgGroupName,
					groups: wizardOrgGroups
				)
		else {
			wizardErrorMessage =
				"Selected Organization Group is invalid. Reload and try again."
			return
		}

		isSaving = true
		Task {
			let finalizedResult = await EnvironmentWizardCoordinator
				.finalizeOrgGroupIdentifiers(
					environment: draftEnvironment,
					selectedGroup: selectedGroup,
					logCategory: "Onboarding"
				)
			guard case .success(let finalized) = finalizedResult else {
				let message: String
				switch finalizedResult {
				case .failure(let error):
					message = error.userMessage
				case .success:
					message = "Unable to validate Organization Group."
				}
				await MainActor.run {
					wizardErrorMessage = message
					isSaving = false
					appLog(.error, "Onboarding", "onboarding.failed: \(message)")
				}
				return
			}

			let brandingResult = await EnvironmentWizardCoordinator
				.validateBrandingAndRefreshLogo(
					for: finalized,
					logCategory: "Onboarding"
				)
			guard case .success(let readyEnvironment) = brandingResult else {
				let message: String
				switch brandingResult {
				case .failure(let error):
					message = error.userMessage
				case .success:
					message = "Unable to validate branding."
				}
				await MainActor.run {
					wizardErrorMessage = message
					isSaving = false
					appLog(.error, "Onboarding", "onboarding.failed: \(message)")
				}
				return
			}

			await MainActor.run {
				var state = settingsStore.load()
				state.eulaAccepted = true
				if state.uemEnvironments.isEmpty {
					state.uemEnvironments = [readyEnvironment]
				} else {
					state.uemEnvironments.append(readyEnvironment)
				}
				state.activeEnvironmentUuid = readyEnvironment.orgGroupUuid
				do {
					try settingsStore.save(state)
					appLog(.info, "Onboarding", "onboarding.environment.saved")
					Task {
						await Runtime.Config.applySettings(state)
						await MainActor.run {
							isSaving = false
							onCompleted()
						}
					}
				} catch {
					wizardErrorMessage = error.localizedDescription
					isSaving = false
					appLog(
						.error,
						"Onboarding",
						"onboarding.failed: \(error.localizedDescription)"
					)
				}
			}
		}
	}
}

#Preview("Onboarding (Minimum Window)") {
	OnboardingFlowView(
		onCompleted: {},
		onDeclined: {}
	)
	.frame(
		width: onboardingSheetMinWidth,
		height: onboardingSheetMinHeight
	)
}
