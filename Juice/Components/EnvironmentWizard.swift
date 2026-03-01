import SwiftUI

private enum EnvironmentWizardDisplayStep: String, CaseIterable, Identifiable {
	case configureEnvironment
	case selectOrganizationGroup
	case save

	var id: String { rawValue }

	var title: String {
		switch self {
		case .configureEnvironment: return "Configure Environment"
		case .selectOrganizationGroup: return "Select Org Group"
		case .save: return "Save Environment"
		}
	}
}

struct EnvironmentWizard: View {
	enum Mode {
		case add
		case edit
	}

	let mode: Mode
	@Binding var step: AddEnvironmentStep
	@Binding var draft: UemEnvironment
	@Binding var errorMessage: String?
	@Binding var orgGroups: [OrganizationGroup]
	@Binding var isLoadingOrgGroups: Bool
	@Binding var isSaving: Bool
	@Binding var selectedOrgGroupName: String
	let horizontalPadding: CGFloat
	let oauthRegions: [String]
	let onSelectOrgGroup: (String) -> Void
	let onCancel: () -> Void
	let onBack: () -> Void
	let onNext: () -> Void
	let onSave: () -> Void
	@State private var showClientSecret: Bool = false
	@State private var showBasicPassword: Bool = false

	init(
		mode: Mode,
		step: Binding<AddEnvironmentStep>,
		draft: Binding<UemEnvironment>,
		errorMessage: Binding<String?>,
		orgGroups: Binding<[OrganizationGroup]>,
		isLoadingOrgGroups: Binding<Bool>,
		isSaving: Binding<Bool>,
		selectedOrgGroupName: Binding<String>,
		horizontalPadding: CGFloat = 23,
		oauthRegions: [String],
		onSelectOrgGroup: @escaping (String) -> Void,
		onCancel: @escaping () -> Void,
		onBack: @escaping () -> Void,
		onNext: @escaping () -> Void,
		onSave: @escaping () -> Void
	) {
		self.mode = mode
		self._step = step
		self._draft = draft
		self._errorMessage = errorMessage
		self._orgGroups = orgGroups
		self._isLoadingOrgGroups = isLoadingOrgGroups
		self._isSaving = isSaving
		self._selectedOrgGroupName = selectedOrgGroupName
		self.horizontalPadding = horizontalPadding
		self.oauthRegions = oauthRegions
		self.onSelectOrgGroup = onSelectOrgGroup
		self.onCancel = onCancel
		self.onBack = onBack
		self.onNext = onNext
		self.onSave = onSave
	}

	private var titleText: String {
		switch mode {
		case .add: return "Add Environment"
		case .edit: return "Edit Environment"
		}
	}

	private var orgGroupNames: [String] {
		orgGroups.compactMap { $0.name }.filter { !$0.isEmpty }
	}

	private var selectedGroupId: String? {
		orgGroups.first(where: { $0.name == selectedOrgGroupName })?
			.resolvedGroupId
	}

	private var displaySteps: [EnvironmentWizardDisplayStep] {
		[.configureEnvironment, .selectOrganizationGroup, .save]
	}

	private var currentDisplayStep: EnvironmentWizardDisplayStep {
		if isSaving {
			return .save
		}
		switch step {
		case .configureEnvironment: return .configureEnvironment
		case .selectOrganizationGroup: return .selectOrganizationGroup
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 11) {
			VStack(alignment: .leading, spacing: 2) {
				Text(titleText)
					.font(.title3.weight(.semibold))
				Text("Configure and validate your Workspace ONE UEM environment settings")
					.font(.system(size: 11, weight: .regular))
					.foregroundStyle(.secondary)
			}

			EnvironmentWizardStepsProgress(
				steps: displaySteps,
				currentStep: currentDisplayStep
			)
			.padding(.top, 1)
			.padding(.bottom, 2)

			if let errorMessage {
				EnvironmentWizardInfoBar(message: errorMessage)
			}

			EnvironmentWizardPanel {
				switch step {
				case .configureEnvironment:
					VStack(alignment: .leading, spacing: 10) {
						Text("Workspace ONE UEM Tenant Details")
							.font(.system(size: 14, weight: .semibold))
							.padding(.bottom, 1)

						Text("Friendly Name")
							.font(.system(size: 12, weight: .semibold))
							.padding(.bottom, -4)
						TextField("eg. Production Tenant", text: $draft.friendlyName)
							.textFieldStyle(.roundedBorder)
							.padding(.top, -2)

						Text("Workspace ONE API Server URL")
							.font(.system(size: 12, weight: .semibold))
							.padding(.bottom, -4)
						TextField("eg. https://as1234.awmdm.com", text: $draft.uemUrl)
							.textFieldStyle(.roundedBorder)
							.padding(.top, -2)

						Text("Authentication Type")
							.font(.system(size: 12, weight: .semibold))
							.padding(.bottom, -4)
						LiquidGlassSegmentedPicker(
							items: [
								.init(
									title: "OAuth",
									icon: "person.badge.key",
									tag: UemAuthenticationType.oauthClientCredentials
								),
								.init(
									title: "Basic + API Key",
									icon: "key.fill",
									tag: UemAuthenticationType.basicAuthApiKey
								),
							],
							selection: $draft.authenticationType
						)
						.padding(.top, -2)

						if draft.authenticationType == .oauthClientCredentials {
							Text("Client ID")
								.font(.system(size: 12, weight: .semibold))
								.padding(.bottom, -4)
							TextField("Client ID", text: $draft.clientId)
								.textFieldStyle(.roundedBorder)
								.padding(.top, -2)

							Text("Client Secret")
								.font(.system(size: 12, weight: .semibold))
								.padding(.bottom, -4)

							if mode == .edit {
								HStack(spacing: 8) {
									Group {
										if showClientSecret {
											TextField(
												"Client Secret",
												text: $draft.clientSecret
											)
										} else {
											SecureField(
												"Client Secret",
												text: $draft.clientSecret
											)
										}
									}
									.textFieldStyle(.roundedBorder)
									Button {
										showClientSecret.toggle()
									} label: {
										Image(
											systemName: showClientSecret
												? "eye.slash" : "eye"
										)
										.font(
											.system(
												size: 12,
												weight: .semibold
											)
										)
										.foregroundStyle(.secondary)
									}
									.buttonStyle(.plain)
									.juiceHelp(
										HelpText.Settings.clientSecretToggle(
											isRevealed: showClientSecret
										)
									)
								}
								.padding(.top, -2)
							} else {
								SecureField(
									"Client Secret",
									text: $draft.clientSecret
								)
								.textFieldStyle(.roundedBorder)
								.padding(.top, -2)
							}

							Text("OAuth Region")
								.font(.system(size: 12, weight: .semibold))
								.padding(.bottom, -4)
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
							.pickerStyle(.menu)
							.labelsHidden()
							.padding(.top, -2)
						} else {
							Text("Username")
								.font(.system(size: 12, weight: .semibold))
								.padding(.bottom, -4)
							TextField("Username", text: $draft.basicUsername)
								.textFieldStyle(.roundedBorder)
								.padding(.top, -2)

							Text("Password")
								.font(.system(size: 12, weight: .semibold))
								.padding(.bottom, -4)
							if mode == .edit {
								HStack(spacing: 8) {
									Group {
										if showBasicPassword {
											TextField(
												"Password",
												text: $draft.basicPassword
											)
										} else {
											SecureField(
												"Password",
												text: $draft.basicPassword
											)
										}
									}
									.textFieldStyle(.roundedBorder)
									Button {
										showBasicPassword.toggle()
									} label: {
										Image(
											systemName: showBasicPassword
												? "eye.slash" : "eye"
										)
										.font(
											.system(
												size: 12,
												weight: .semibold
											)
										)
										.foregroundStyle(.secondary)
									}
									.buttonStyle(.plain)
								}
								.padding(.top, -2)
							} else {
								SecureField("Password", text: $draft.basicPassword)
									.textFieldStyle(.roundedBorder)
									.padding(.top, -2)
							}

							Text("API Key")
								.font(.system(size: 12, weight: .semibold))
								.padding(.bottom, -4)
							SecureField("API Key", text: $draft.apiKey)
								.textFieldStyle(.roundedBorder)
								.padding(.top, -2)
						}
					}

				case .selectOrganizationGroup:
					VStack(alignment: .leading, spacing: 10) {
						Text("Select Org Group")
							.font(.system(size: 14, weight: .semibold))
							.padding(.bottom, 1)

						if isSaving {
							VStack(spacing: 7) {
								ProgressView().controlSize(.small)
								Text("Validating configuration before saving...")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							.frame(maxWidth: .infinity, minHeight: 102)
						} else if isLoadingOrgGroups {
							VStack(spacing: 7) {
								ProgressView().controlSize(.small)
								Text("Loading Org Groups...")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							.frame(maxWidth: .infinity, minHeight: 102)
						} else {
							Text("Org Group")
								.font(.caption.weight(.semibold))
							Picker(
								"Org Group",
								selection: $selectedOrgGroupName
							) {
								ForEach(
									normalizedOptions(
										orgGroupNames,
										current: selectedOrgGroupName
									),
									id: \.self
								) { option in
									Text(option).tag(option)
								}
							}
							.pickerStyle(.menu)
							.onChange(of: selectedOrgGroupName) { _, newValue in
								onSelectOrgGroup(newValue)
							}

							if let selectedGroupId {
								HStack {
									Text("Org Group ID")
										.font(.caption.weight(.semibold))
									Spacer()
									Text(selectedGroupId).foregroundStyle(.secondary)
								}
								.padding(.top, 4)
							}
						}
					}
				}
			}

			Spacer(minLength: 0)
			Divider().padding(.top, 1)
			HStack(spacing: 10) {
				Button("Cancel") { onCancel() }
					.nativeActionButtonStyle(.secondary, controlSize: .large)
					.disabled(isLoadingOrgGroups || isSaving)
				Spacer()
				if step == .selectOrganizationGroup {
					Button("Back") { onBack() }
						.nativeActionButtonStyle(.secondary, controlSize: .large)
						.disabled(isLoadingOrgGroups || isSaving)
					Button("Save") { onSave() }
						.juiceGradientGlassProminentButtonStyle(controlSize: .large)
						.disabled(isLoadingOrgGroups || isSaving)
				} else {
					Button("Next") { onNext() }
						.juiceGradientGlassProminentButtonStyle(controlSize: .large)
						.disabled(isLoadingOrgGroups || isSaving)
				}
			}
			.padding(.top, 1)
		}
		.padding(.vertical, 23)
		.padding(.horizontal, horizontalPadding)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.onAppear { showClientSecret = false }
		.onChange(of: step) { _, _ in showClientSecret = false }
		.onDisappear { showClientSecret = false }
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

private struct EnvironmentWizardStepsProgress: View {
	@ObservedObject private var styleConfig = JuiceStyleConfig.shared
	let steps: [EnvironmentWizardDisplayStep]
	let currentStep: EnvironmentWizardDisplayStep

	private struct StepState: Identifiable {
		let id: String
		let title: String
		let iconName: String
		let isCurrent: Bool
		let isCompleted: Bool
		let isActiveOrCompleted: Bool
	}

	private var currentIndex: Int {
		steps.firstIndex(of: currentStep) ?? 0
	}

	private var stepStates: [StepState] {
		steps.enumerated().map { index, step in
			let isCurrent = index == currentIndex
			let isCompleted = index < currentIndex
			let isActiveOrCompleted = isCurrent || isCompleted
			let iconName = isCompleted ? "checkmark.circle.fill" :
				(isCurrent ? "circle.fill" : "circle")
			return StepState(
				id: step.id,
				title: step.title,
				iconName: iconName,
				isCurrent: isCurrent,
				isCompleted: isCompleted,
				isActiveOrCompleted: isActiveOrCompleted
			)
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			GeometryReader { geometry in
				let stepCount = max(stepStates.count, 1)
				let columnWidth = geometry.size.width / CGFloat(stepCount)
				let connectorWidth = max(columnWidth - 18, 0)

					ZStack(alignment: .topLeading) {
						ForEach(Array(stepStates.enumerated()), id: \.element.id) {
							index,
							state in
							if index < stepStates.count - 1 {
								let connectorColor =
									(index < currentIndex
										? styleConfig.prominentButtonTintColor : Color.secondary
									)
									.opacity(index < currentIndex ? 0.45 : 0.30)
								Rectangle()
									.fill(connectorColor)
									.frame(width: connectorWidth, height: 1)
									.position(
										x: columnWidth * CGFloat(index + 1),
										y: 8
									)
							}
						}

					HStack(spacing: 0) {
						ForEach(stepStates) { state in
							Image(systemName: state.iconName)
								.font(.system(size: 10, weight: .semibold))
								.foregroundStyle(
									state.isActiveOrCompleted
										? styleConfig.prominentButtonTintColor
										: Color.secondary
								)
								.frame(maxWidth: .infinity, alignment: .center)
						}
					}
				}
			}
			.frame(height: 16)

			HStack(spacing: 0) {
				ForEach(stepStates) { state in
					Text(state.title)
						.font(
							.system(
								size: 11,
								weight: state.isCurrent ? .semibold : .medium
							)
						)
						.lineLimit(2)
						.truncationMode(.tail)
						.multilineTextAlignment(.center)
						.foregroundStyle(
							state.isActiveOrCompleted
								? styleConfig.prominentButtonTintColor : Color.secondary
						)
						.frame(maxWidth: .infinity, alignment: .center)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

private struct EnvironmentWizardInfoBar: View {
	let message: String

	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(Color.orange)
			VStack(alignment: .leading, spacing: 2) {
				Text("Validation Error")
					.font(.system(size: 12, weight: .semibold))
				Text(message)
					.font(.system(size: 11, weight: .regular))
					.foregroundStyle(.secondary)
			}
			Spacer(minLength: 0)
		}
		.padding(10)
		.background(
			RoundedRectangle(cornerRadius: 10, style: .continuous)
				.fill(Color.orange.opacity(0.08))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 10, style: .continuous)
				.stroke(Color.orange.opacity(0.35), lineWidth: 1)
		)
	}
}

private struct EnvironmentWizardPanel<Content: View>: View {
	let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
		VStack(alignment: .leading, spacing: 0) {
			content
		}
		.frame(maxWidth: .infinity, alignment: .topLeading)
		.padding(16)
		.background(shape.fill(.ultraThinMaterial))
		.overlay(
			shape
				.stroke(Color.white.opacity(0.15), lineWidth: 1)
		)
		.frame(maxWidth: .infinity, alignment: .topLeading)
	}
}
