import Foundation

enum EnvironmentWizardCoordinator {
	enum WizardError: Error {
		case message(String)

		var userMessage: String {
			switch self {
			case .message(let value):
				return value
			}
		}
	}

	static func configureStepValidationError(for environment: UemEnvironment)
		-> String?
	{
		var missing: [String?] = [
			environment.friendlyName.trimmingCharacters(
				in: .whitespacesAndNewlines
			).isEmpty ? "Friendly Name" : nil,
			environment.uemUrl.trimmingCharacters(in: .whitespacesAndNewlines)
				.isEmpty ? "Workspace ONE API Server URL" : nil,
		]

		switch environment.authenticationType {
		case .oauthClientCredentials:
			missing.append(
				environment.clientId.trimmingCharacters(
					in: .whitespacesAndNewlines
				).isEmpty ? "Client ID" : nil
			)
			missing.append(
				environment.clientSecret.trimmingCharacters(
					in: .whitespacesAndNewlines
				).isEmpty ? "Client Secret" : nil
			)
			missing.append(
				environment.oauthRegion.trimmingCharacters(
					in: .whitespacesAndNewlines
				).isEmpty ? "OAuth Region" : nil
			)
		case .basicAuthApiKey:
			missing.append(
				environment.basicUsername.trimmingCharacters(
					in: .whitespacesAndNewlines
				).isEmpty ? "Username" : nil
			)
			missing.append(
				environment.basicPassword.trimmingCharacters(
					in: .whitespacesAndNewlines
				).isEmpty ? "Password" : nil
			)
			missing.append(
				environment.apiKey.trimmingCharacters(
					in: .whitespacesAndNewlines
				).isEmpty ? "API Key" : nil
			)
		}

		let compactMissing = missing.compactMap { $0 }
		if !compactMissing.isEmpty {
			return "Missing: \(compactMissing.joined(separator: ", "))."
		}

		let trimmedURL = environment.uemUrl.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		guard
			let url = URL(string: trimmedURL),
			let scheme = url.scheme?.lowercased(),
			scheme == "https" || scheme == "http",
			url.host != nil
		else {
			return "Workspace ONE API Server URL is invalid."
		}
		return nil
	}

	static func finalizedEnvironmentValidationError(for environment: UemEnvironment)
		-> String?
	{
		if let stepError = configureStepValidationError(for: environment) {
			return stepError
		}
		let missing = [
			environment.orgGroupName.trimmingCharacters(
				in: .whitespacesAndNewlines
			).isEmpty ? "Organization Group" : nil,
			environment.orgGroupId.trimmingCharacters(
				in: .whitespacesAndNewlines
			).isEmpty ? "Organization Group ID" : nil,
		].compactMap { $0 }
		if !missing.isEmpty {
			return "Missing: \(missing.joined(separator: ", "))."
		}
		return nil
	}

	static func fetchOrgGroups(for environment: UemEnvironment) async
		-> [OrganizationGroup]
	{
		await UEMService.instance.getAllOrgGroups(environment: environment) ?? []
	}

	static func resolveSelectedOrgGroupForSave(
		selectedName: String,
		groups: [OrganizationGroup]
	) -> OrganizationGroup? {
		let trimmedName = selectedName.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		guard !trimmedName.isEmpty else { return nil }
		return groups.first {
			$0.name?.trimmingCharacters(in: .whitespacesAndNewlines)
				== trimmedName
		}
	}

	static func finalizeOrgGroupIdentifiers(
		environment: UemEnvironment,
		selectedGroup: OrganizationGroup,
		logCategory: String = "EnvironmentWizard"
	) async -> Result<UemEnvironment, WizardError> {
		guard
			let selectedName = selectedGroup.name?.trimmingCharacters(
				in: .whitespacesAndNewlines
			),
			!selectedName.isEmpty
		else {
			return .failure(.message("Selected Organization Group name is missing."))
		}

		guard
			let selectedId = selectedGroup.resolvedGroupId?.trimmingCharacters(
				in: .whitespacesAndNewlines
			),
			!selectedId.isEmpty
		else {
			return .failure(
				.message(
					"Selected Organization Group does not have a valid Group ID."
				)
			)
		}

		var finalized = environment
		finalized.orgGroupName = selectedName
		finalized.orgGroupId = selectedId
		finalized.orgGroupUuid = ""

		if let validationError = finalizedEnvironmentValidationError(
			for: finalized
		) {
			return .failure(.message(validationError))
		}

		guard
			let uuid = await UEMService.instance.getOrgGroupUuid(
				environment: finalized,
				id: selectedId
			),
			!uuid.isEmpty
		else {
			appLog(
				.error,
				logCategory,
				"Org Group UUID lookup failed for orgGroupId=\(selectedId)"
			)
			return .failure(
				.message(
					"Could not verify Org Group UUID. Check the selected Organization Group."
				)
			)
		}

		finalized.orgGroupUuid = uuid
		return .success(finalized)
	}

	static func validateBrandingAndRefreshLogo(
		for environment: UemEnvironment,
		logCategory: String = "EnvironmentWizard"
	) async -> Result<UemEnvironment, WizardError> {
		guard
			let branding = await UEMService.instance.getOrgGroupBrandingConfig(
				environment: environment,
				preferCached: false
			)
		else {
			appLog(.error, logCategory, "Branding validation failed.")
			return .failure(
				.message(
					"Branding validation failed. Could not fetch Organization Group branding."
				)
			)
		}

		if let logoUrl = branding.logoUrl?.trimmingCharacters(
			in: .whitespacesAndNewlines
		), !logoUrl.isEmpty {
			await UEMService.instance.downloadOrgGroupLogo(
				environment: environment,
				brandingConfig: branding
			)
		} else {
			await UEMService.instance.refreshOrgGroupLogo(
				environment: environment
			)
		}

		return .success(environment)
	}
}
