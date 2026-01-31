//
//  CaskApplication+Display.swift
//  Juice
//
//  Created by Pete Lindley on 29/1/2026.
//

import Foundation

extension CaskApplication {
	var displayName: String {
		name.first ?? token
	}

	var hasRecipe: Bool {
		matchingRecipeId != nil
	}

	var iconSource: String {
		url
	}

	var fileType: String {
		let lower = url.lowercased()
		if lower.contains(".pkg") { return "pkg" }
		if lower.contains(".dmg") { return "dmg" }
		if lower.contains(".zip") { return "zip" }
		return URL(fileURLWithPath: url).pathExtension
	}
}
