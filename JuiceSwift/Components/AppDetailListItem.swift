//
//  AppRowView.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 25/1/2026.
//
import SwiftUI

struct AppDetailListItem: View {
	let item: CaskApplication
	let label: String

	private enum PillKey: String, CaseIterable {
		case recipe
		case token
		case filetype
	}

	// Add/remove keys here to control which pills appear.
	private let enabledPillKeys: [PillKey] = [
		.recipe,
		.token,
		.filetype
	]

	private var content: some View {
		VStack{
			HStack(alignment: .top, spacing: 12) {
				ZStack(alignment: .bottomLeading) {
					IconByFiletype(applicationFileName: item.iconSource)
				}
				VStack(alignment: .leading, spacing: 4) {
					Text(item.displayName)
						.font(.system(size: 14, weight: .semibold))
						.lineLimit(1)
					Text(item.desc ?? "")
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
				Spacer()
				VStack(alignment: .trailing, spacing: 4) {
					Text(label)
						.font(.system(size: 10, weight: .bold))
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.trailing)
					Text(item.version)
						.font(.system(size: 13, weight: .medium))
						.lineLimit(1)
						.multilineTextAlignment(.trailing)
				}
				.frame(minWidth: 110, alignment: .trailing)
			}
			if !pillDescriptors.isEmpty {
				FlowLayout(spacing: 6, rowSpacing: 6) {
					ForEach(pillDescriptors) { pill in
						Pill(pill.title, color: pill.color)
					}
				}
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		return Group {
			if #available(macOS 26.0, iOS 26.0, *) {
				GlassEffectContainer {
					content
						.glassEffect(.regular, in: shape)
				}
				.clipShape(shape)
				.shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
			} else {
				content
					.background(.ultraThinMaterial, in: shape)
					.overlay(
						shape.strokeBorder(.white.opacity(0.08))
					)
					.clipShape(shape)
					.shadow(
						color: Color.black.opacity(0.06),
						radius: 2,
						x: 0,
						y: 1
					)
			}
		}
		.contentShape(shape)
	}

	private struct PillDescriptor: Identifiable {
		let id = UUID()
		let title: String
		let color: Color
	}

	private var pillDescriptors: [PillDescriptor] {
		enabledPillKeys.compactMap { key in
			switch key {
			case .recipe:
				guard item.hasRecipe else { return nil }
				return PillDescriptor(title: "Recipe", color: .green)
			case .token:
				guard item.token.isEmpty == false else { return nil }
				return PillDescriptor(title: item.token, color: .blue)
			case .filetype:
				guard item.url.isEmpty == false else { return nil }
				let ext = URL(fileURLWithPath: item.url).pathExtension.lowercased()
				return PillDescriptor(title: ".\(ext)", color: .blue)
			}
		}
	}
}
#Preview {
	AppDetailListItem(
		item: CaskApplication(
			token: "omnissa-horizon-client",
			fullToken: "omnissa-horizon-client",
			name: ["Omnissa Horizon Client"],
			desc: "Virtual machine client for macOS",
			url: "https://download3.omnissa.com/Omnissa-Horizon-Client.pkg",
			version: "8.16.0",
			autoUpdates: true,
			matchingRecipeId:
				"com.github.dataJAR-recipes.munki.Omnissa Horizon Client"
		),
		label: "Version"
	)
	.padding(20)
	.background(Color.clear)
	.frame(width: 420)
}
