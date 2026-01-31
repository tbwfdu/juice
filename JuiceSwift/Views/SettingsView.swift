import SwiftUI

struct SettingsView: View {
    let model: PageViewData
    @State private var activeEnvironment = 0
	private let basePanelMinHeight: CGFloat = 680
	private let bottomBarHeight: CGFloat = 88
	private let panelGlassOpacity: CGFloat = 0.95
	@StateObject private var focusObserver = WindowFocusObserver()

    var body: some View {
		let glassBaseOpacity = focusObserver.isFocused ? 0.6 : 0.3
		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - bottomBarHeight)
			let panelMinHeight = min(basePanelMinHeight, availableHeight)
			let panelMinWidth = 620
			VStack(alignment: .leading) {
				HStack(alignment: .top) {
					ZStack(alignment: .topLeading) {
						ScrollView {
							VStack(alignment: .leading, spacing: 20) {
								Text("Settings")
									.font(.system(size: 28, weight: .semibold))
								ElevatedPanel(style: .glass) {
									SectionHeader("UEM Environment", subtitle: "Workspace ONE UEM Environment Configuration Details")
									Picker("Active Environment", selection: $activeEnvironment) {
										Text("Primary").tag(0)
										Text("Secondary").tag(1)
									}
									.pickerStyle(.segmented)

									Text("Configure Environments")
										.font(.system(size: 14, weight: .semibold))
									Text("You can configure up to 2 Workspace ONE environments.")
										.font(.system(size: 12, weight: .medium))
										.foregroundStyle(.secondary)

									VStack(spacing: 12) {
										SettingsField(title: "UEM URL", value: model.settings.uemUrl)
										SettingsField(title: "Client ID", value: model.settings.clientId)
										SettingsField(title: "Org Group ID", value: model.settings.orgGroupId)
										SettingsField(title: "Org Group UUID", value: model.settings.orgGroupUuid)
									}
								}

								ElevatedPanel(style: .glass) {
									SectionHeader("Validate Config", subtitle: "Check basic configuration settings")
									JuiceButtons.primary("Run Validation") {}
								}

								ElevatedPanel(style: .glass) {
									SectionHeader("Database", subtitle: "Local cache and metadata status")
									HStack {
										Text("Database Version")
											.font(.system(size: 13, weight: .semibold))
										Spacer()
										Text(model.settings.databaseVersion)
											.font(.system(size: 12, weight: .medium))
											.foregroundStyle(.secondary)
									}
									JuiceButtons.secondary("Update Database") {}
								}

								ElevatedPanel(style: .glass) {
									SectionHeader("About", subtitle: "Juice SwiftUI preview")
									Text("App Version: \(model.settings.appVersion)")
										.font(.system(size: 12, weight: .medium))
										.foregroundStyle(.secondary)
									Text("Database Version: \(model.settings.databaseVersion)")
										.font(.system(size: 12, weight: .medium))
										.foregroundStyle(.secondary)
								}
							}
							.padding(24)
							.frame(maxWidth: 900, alignment: .leading)
						}
						.padding(16)
						.frame(
							minWidth: CGFloat(panelMinWidth),
							minHeight: panelMinHeight,
							maxHeight: .infinity,
							alignment: .topLeading
						)
					.frame(maxWidth: .infinity, alignment: .topLeading)
					.layoutPriority(1)
					.background {
						let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
						if #available(macOS 26.0, iOS 26.0, *) {
							GlassEffectContainer {
								shape
									.fill(Color.white).opacity(glassBaseOpacity)
									.glassEffect(.regular, in: shape)
							}
							.opacity(panelGlassOpacity)
						} else {
							shape.fill(.ultraThinMaterial)
								.opacity(panelGlassOpacity)
						}
					}
					.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
					.overlay {
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.strokeBorder(.white.opacity(0.12))
					}
					.shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
					.background(WindowFocusReader { focusObserver.attach($0) })
					.zIndex(1)

					}
				}
				.frame(maxWidth: .infinity, alignment: .topLeading)
				.padding(.horizontal, 40)
				.padding(.vertical, 0)
			}
		}
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ifAvailableMacOS14ContentMarginsElsePadding()
    }
}

struct SettingsField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            TextField("", text: .constant(value))
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    SettingsView(model: .sample)
        .frame(width: 1100, height: 720)
}
