import Foundation

enum AppLogRedactor {
	static func sanitize(_ value: String) -> String {
		var sanitized = value
		sanitized = redactAuthorizationHeaders(in: sanitized)
		sanitized = redactBearerTokens(in: sanitized)
		sanitized = redactTenantCode(in: sanitized)
		sanitized = redactClientSecret(in: sanitized)
		sanitized = redactApiKeys(in: sanitized)
		sanitized = redactAccessTokenJSON(in: sanitized)
		return sanitized
	}

	private static func redactAuthorizationHeaders(in value: String) -> String {
		let pattern = #"(?i)(Authorization[:=]\s*(?:Bearer|Basic)\s+)[A-Za-z0-9\-._~+/=]+"#
		return replacing(pattern: pattern, in: value, with: "$1[REDACTED]")
	}

	private static func redactBearerTokens(in value: String) -> String {
		let pattern = #"(?i)(Bearer\s+)[A-Za-z0-9\-._~+/=]+"#
		return replacing(pattern: pattern, in: value, with: "$1[REDACTED]")
	}

	private static func redactClientSecret(in value: String) -> String {
		let pattern = #"(?i)(client_secret[=:]\s*)[^&\s",}]+"#
		return replacing(pattern: pattern, in: value, with: "$1[REDACTED]")
	}

	private static func redactTenantCode(in value: String) -> String {
		let pattern = #"(?i)(\"?aw-tenant-code\"?\s*[:=]\s*\"?)[^\"&\s,}]+"#
		return replacing(pattern: pattern, in: value, with: "$1[REDACTED]")
	}

	private static func redactApiKeys(in value: String) -> String {
		let pattern = #"(?i)(\"?api[_-]?key\"?\s*[:=]\s*\"?)[^\"&\s,}]+"#
		return replacing(pattern: pattern, in: value, with: "$1[REDACTED]")
	}

	private static func redactAccessTokenJSON(in value: String) -> String {
		let pattern = #"(?i)("access_token"\s*:\s*")[^"]+(")"#
		return replacing(pattern: pattern, in: value, with: "$1[REDACTED]$2")
	}

	private static func replacing(pattern: String, in value: String, with template: String) -> String {
		guard let regex = try? NSRegularExpression(pattern: pattern) else {
			return value
		}
		let range = NSRange(value.startIndex..<value.endIndex, in: value)
		return regex.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: template)
	}
}
