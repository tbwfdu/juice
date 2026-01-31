import SwiftUI

struct ConfirmationDialog<Item: Identifiable, RowContent: View>: View {
    enum Mode {
        case upload
        case download
        case uploadOnly

        var verb: String {
            switch self {
            case .upload, .uploadOnly: return "upload"
            case .download: return "download"
            }
        }

        var destinationText: String {
            switch self {
            case .upload, .uploadOnly: return "to Workspace ONE."
            case .download: return "to your local device."
            }
        }
    }

    let mode: Mode
    let items: [Item]
    let uploadOnlyItems: [Item]
    let title: String
    let confirmTitle: String
    let cancelTitle: String
	let onConfirm: () -> Void
	let onCancel: () -> Void
	let rowContent: (Item) -> RowContent
	@StateObject private var focusObserver = WindowFocusObserver()

    init(
        mode: Mode,
        items: [Item],
        uploadOnlyItems: [Item] = [],
        title: String = "Ready to Proceed?",
        confirmTitle: String = "Confirm",
        cancelTitle: String = "Cancel",
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.mode = mode
        self.items = items
        self.uploadOnlyItems = uploadOnlyItems
        self.title = title
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.rowContent = rowContent
    }

    var body: some View {
		let glassBaseOpacity = focusObserver.isFocused ? 0.9 : 0.25
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 16) {
            smallHeader
            VStack(alignment: .leading, spacing: 8) {
                messageText
                    .font(.system(size: 14, weight: .regular))
                Text("Applications obtained using Juice are licensed to you by its owner. Juice and related services are not responsible for, nor does it grant any licenses to, third-party packages.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(activeItems) { item in
                        rowContent(item)
                    }
                }
            }
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )

            HStack {
                Spacer()
                JuiceButtons.secondary(cancelTitle, action: onCancel)
                JuiceButtons.primary(confirmTitle, action: onConfirm)
            }
        }
        .padding(20)
        .frame(minWidth: 620)
		.background {
			if #available(macOS 26.0, iOS 26.0, *) {
				ZStack {
					shape.fill(Color.white.opacity(glassBaseOpacity))
					GlassEffectContainer {
						shape
							.fill(Color.white)
							.glassEffect(.regular, in: shape)
					}
				}
			} else {
				shape.fill(.ultraThinMaterial)
			}
		}
		.background(WindowFocusReader { focusObserver.attach($0) })
		.clipShape(shape)
		.overlay(shape.strokeBorder(.white.opacity(0.12)))
		.shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 4)
    }

    private var activeItems: [Item] {
        if mode == .uploadOnly {
            return uploadOnlyItems.isEmpty ? items : uploadOnlyItems
        }
        return items
    }

    private var messageText: Text {
        let count = activeItems.count
        let noun = count == 1 ? "app" : "apps"
        return Text("You're about to \(Text(mode.verb).bold()) \(count) \(noun) \(mode.destinationText)")
    }

    private var smallHeader: some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.top, 4)
    }
}

#Preview {
    let items: [CaskApplication] = [
        CaskApplication(
            token: "safari",
            fullToken: "safari",
            name: ["Safari"],
            desc: "Apple's web browser",
            url: "https://example.com/safari.pkg",
            version: "17.2",
            matchingRecipeId: "safari"
        ),
        CaskApplication(
            token: "xcode",
            fullToken: "xcode",
            name: ["Xcode"],
            desc: "Apple's IDE for macOS",
            url: "https://example.com/xcode.dmg",
            version: "15.1"
        )
    ]

    return ConfirmationDialog(
        mode: .upload,
        items: items,
        onConfirm: {},
        onCancel: {}
    ) { item in
        AnyView(
            AppDetailListItem(item: item, label: "Version")
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
        )
    }
    .frame(width: 720, height: 520)
}
