//
//  AuthService.swift
//  JuiceSwift
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
	let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "JuiceSwift", category: "Auth")
	var accessToken: String? = nil
	var tokenEndpoint: String = "/connect/token"

	@discardableResult
	func authenticate() async -> Bool {

		logger.debug("[\(self.logPrefix)] Requesting Access Token")
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard let baseURL = URL(string: activeEnvironment.oauthRegion) else {
			logger.error("[\(self.logPrefix)] Invalid OAuth region URL")
			return false
		}
		guard let tokenURL = URL(string: self.tokenEndpoint, relativeTo: baseURL) else {
			logger.error("[\(self.logPrefix)] Invalid OAuth token URL")
			return false
		}

		var request = URLRequest(url: tokenURL)
		request.httpMethod = "POST"
		request.setValue(
			"application/x-www-form-urlencoded",
			forHTTPHeaderField: "Content-Type"
		)

		let body = [
			"grant_type=client_credentials",
			"client_id=\(activeEnvironment.clientId)",
			"client_secret=\(activeEnvironment.clientSecret)",
		].joined(separator: "&")
		request.httpBody = body.data(using: .utf8)

		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			let json =
				try JSONSerialization.jsonObject(with: data, options: [])
				as? [String: Any]
			if let token = json?["access_token"] as? String {
				accessToken = token
				logger.debug("[\(self.logPrefix)] Access Token Obtained")
				return true
			}
		} catch {
			logger.error(
				"[\(self.logPrefix)] \(String(describing: error), privacy: .public)"
			)
		}

		return false
	}
	
	
	
	func getOrgGroupDetails() async -> [String: Any]? {
		_ = await authenticate()
		let activeEnvironment = await Runtime.Config.currentActiveEnvironment()
		guard let baseURL = URL(string: activeEnvironment.uemUrl) else { return nil }
		guard let url = URL(string: "/API/system/groups/\(activeEnvironment.orgGroupId)", relativeTo: baseURL) else {
			return nil
		}

		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		
		if let token = accessToken {
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}
		
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
			return json
		} catch {
			logger.error("[\(self.logPrefix)] \(String(describing: error), privacy: .public)")
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
