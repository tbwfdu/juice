//
//  IconByFiletype.swift
//  Juice
//
//  Created by Pete Lindley on 29/1/2026.
//
import SwiftUI

struct IconByFiletype: View {
	let applicationFileName: String

	var body: some View {
		let ext = URL(fileURLWithPath: applicationFileName).pathExtension.lowercased()

		Group {
			if ext == "zip" {
				Image(systemName: "zipper.page")
					.symbolRenderingMode(.hierarchical)
					.symbolVariant(.none)
					.fontWeight(.regular)
					.font(.system(size: 28, weight: .regular))
					.frame(width: 40, height: 40)
					.foregroundStyle(.gray)
			} else if ext == "dmg" {
				Image(systemName: "shippingbox.fill")
					.symbolRenderingMode(.hierarchical)
					.symbolVariant(.none)
					.fontWeight(.regular)
					.font(.system(size: 28, weight: .regular))
					.frame(width: 40, height: 40)
					.foregroundStyle(.gray)
			} else if ext == "pkg" {
				Image(systemName: "apple.terminal.on.rectangle.fill")
					.symbolRenderingMode(.hierarchical)
					.symbolVariant(.none)
					.fontWeight(.regular)
					.font(.system(size: 28, weight: .regular))
					.frame(width: 40, height: 40)
					.foregroundStyle(.gray)
			} else {
				Image(systemName: "questionmark.app.dashed")
					.symbolRenderingMode(.hierarchical)
					.symbolVariant(.none)
					.fontWeight(.regular)
					.font(.system(size: 28, weight: .regular))
					.frame(width: 40, height: 40)
					.foregroundStyle(.gray)
			}
		}
	}
}

#Preview {
	VStack(spacing: 16) {
		IconByFiletype(applicationFileName: "/tmp/archive.zip")
		IconByFiletype(applicationFileName: "/tmp/installer.dmg")
		IconByFiletype(applicationFileName: "/tmp/setup.pkg")
		IconByFiletype(applicationFileName: "/tmp/unknown.filetype")
	}
	.padding()
}
