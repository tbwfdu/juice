//
//  Helpers.swift
//  JuiceSwift
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
		print(json)
	} else {
		print("Failed to encode value as JSON")
	}
}

func printStruct(_ value: Any) {
	let mirror = Mirror(reflecting: value)
	for child in mirror.children {
		if let label = child.label {
			print("\(label): \(child.value)")
		}
	}
}
