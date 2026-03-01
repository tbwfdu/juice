//
//  AuthService.swift
//  Juice
//
//  Created by Pete Lindley on 27/1/2026.
//

import Foundation
import os

actor AuthService {

	// Expose a Singleton-like instance here
	static let instance = AuthService()

	private init() {
	}
	
	let logPrefix = "AuthService"
	var accessToken: String? = nil
	var tokenEndpoint: String = "/connect/token"

	@discardableResult
	func authenticate() async -> Bool {
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard let headers = await authorizationHeaders(for: activeEnvironment) else {
			return false
		}
		return headers["Authorization"]?.isEmpty == false
	}

	func getAccessToken(for environment: UemEnvironment) async -> String? {
		guard environment.authenticationType == .oauthClientCredentials else {
			return nil
		}
		appLog(.debug, LogCategory.auth, "Requesting Access Token for environment", event: "auth.request_for_environment")
		guard let baseURL = URL(string: environment.oauthRegion) else {
			appLog(.error, LogCategory.auth, "Invalid OAuth region URL", event: "auth.invalid_region_url")
			return nil
		}
		guard let tokenURL = URL(string: self.tokenEndpoint, relativeTo: baseURL) else {
			appLog(.error, LogCategory.auth, "Invalid OAuth token URL", event: "auth.invalid_token_url")
			return nil
		}

		var request = URLRequest(url: tokenURL)
		request.httpMethod = "POST"
		request.setValue(
			"application/x-www-form-urlencoded",
			forHTTPHeaderField: "Content-Type"
		)

		let body = [
			"grant_type=client_credentials",
			"client_id=\(environment.clientId)",
			"client_secret=\(environment.clientSecret)",
		].joined(separator: "&")
		request.httpBody = body.data(using: .utf8)

		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			let json =
				try JSONSerialization.jsonObject(with: data, options: [])
				as? [String: Any]
			if let token = json?["access_token"] as? String, !token.isEmpty {
				accessToken = token
				return token
			}
		} catch {
			appLog(.error, LogCategory.auth, "Environment authentication failed", event: "auth.failure", metadata: ["reason": error.localizedDescription])
		}

		return nil
	}

	func authorizationHeaders(for environment: UemEnvironment) async -> [String: String]? {
		switch environment.authenticationType {
		case .oauthClientCredentials:
			guard
				let token = await getAccessToken(for: environment),
				!token.isEmpty
			else {
				return nil
			}
			return ["Authorization": "Bearer \(token)"]

		case .basicAuthApiKey:
			let username = environment.basicUsername.trimmingCharacters(
				in: .whitespacesAndNewlines
			)
			let password = environment.basicPassword.trimmingCharacters(
				in: .whitespacesAndNewlines
			)
			let apiKey = environment.apiKey.trimmingCharacters(
				in: .whitespacesAndNewlines
			)
			guard !username.isEmpty, !password.isEmpty, !apiKey.isEmpty else {
				return nil
			}
			let credentials = "\(username):\(password)"
			guard let credentialsData = credentials.data(using: .utf8) else {
				return nil
			}
			let encodedCredentials = credentialsData.base64EncodedString()
			accessToken = nil
			return [
				"Authorization": "Basic \(encodedCredentials)",
				"aw-tenant-code": apiKey
			]
		}
	}
	
	
	
	func getOrgGroupDetails() async -> [String: Any]? {
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard let baseURL = URL(string: activeEnvironment.uemUrl) else { return nil }
		guard let url = URL(string: "/API/system/groups/\(activeEnvironment.orgGroupId)", relativeTo: baseURL) else {
			return nil
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		guard let headers = await authorizationHeaders(for: activeEnvironment) else {
			return nil
		}
		for (header, value) in headers {
			request.setValue(value, forHTTPHeaderField: header)
		}
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
			return json
		} catch {
			appLog(.error, LogCategory.auth, "Get org group details failed", event: "auth.org_group_details_failed", metadata: ["reason": error.localizedDescription])
			return nil
		}
	}

	func canAuthenticate() -> Bool {
		guard let token = accessToken else { return false }
		return !token.isEmpty
	}

	private func parseToken() -> [String: Any]? {
		guard let token = accessToken, !token.isEmpty else { return nil }
		guard let payload = decodeJwtPayload(token) else { return nil }
		return payload
	}

	private func isTokenValid() -> Bool {
		guard let token = accessToken, !token.isEmpty else { return false }
		guard let payload = decodeJwtPayload(token) else { return false }
		guard let exp = payload["exp"] as? TimeInterval else { return false }
		let expiry = Date(timeIntervalSince1970: exp)
		return expiry > Date()
	}

	private func decodeJwtPayload(_ token: String) -> [String: Any]? {
		let parts = token.split(separator: ".")
		guard parts.count >= 2 else { return nil }
		let payloadPart = String(parts[1])
		guard let payloadData = base64UrlDecode(payloadPart) else { return nil }
		return (try? JSONSerialization.jsonObject(with: payloadData, options: [])) as? [String: Any]
	}

	private func base64UrlDecode(_ value: String) -> Data? {
		var base64 = value
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")
		let padding = 4 - (base64.count % 4)
		if padding < 4 {
			base64.append(String(repeating: "=", count: padding))
		}
		return Data(base64Encoded: base64)
	}
	
	
	
	
	
	
	
	
	

	//Not used but good to refer back to:

	// Mutable state
	private var settings: [String: Any] = [:]

	// Writes are automatically thread-safe in an actor
	func update(key: String, value: Any) {
		settings[key] = value
	}

	// Reads must be awaited when called from outside the actor
	func get(key: String) -> Any? {
		return settings[key]
	}

}
