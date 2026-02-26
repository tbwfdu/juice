//
//  Helpers.swift
//  Juice
//
//  Created by Pete Lindley on 27/1/2026.
//
import SwiftUI
import os

let logger = Logger(
	subsystem: Bundle.main.bundleIdentifier ?? "Juice",
	category: "Helpers"
)

func printAsJSON<T: Encodable>(_ value: T) {
	let encoder = JSONEncoder()
	encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
	if let data = try? encoder.encode(value),
	   let json = String(data: data, encoding: .utf8) {
		appLog(.debug, LogCategory.helpers, "JSON dump generated", event: "helpers.json_dump", metadata: ["payload": json])
	} else {
		appLog(.warning, LogCategory.helpers, "Failed to encode value as JSON", event: "helpers.json_dump_failed")
	}
}

func printStruct(_ value: Any) {
	let mirror = Mirror(reflecting: value)
	for child in mirror.children {
		if let label = child.label {
			appLog(
				.debug,
				LogCategory.helpers,
				"Struct field: \(label)",
				event: "helpers.struct_dump",
				metadata: ["value": String(describing: child.value)]
			)
		}
	}
}
