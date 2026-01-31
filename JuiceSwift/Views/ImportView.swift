import SwiftUI

struct ImportView: View {
    let model: PageViewData
    @State private var rightTab: QueuePanel<AnyView, AnyView>.Tab = .queue
    @State private var queueItems: [ImportItem] = []
    @State private var resultsItems: [ImportItem] = []
	private let basePanelMinHeight: CGFloat = 680
	private let bottomBarHeight: CGFloat = 88
	private let panelGlassOpacity: CGFloat = 0.95
	@StateObject private var focusObserver = WindowFocusObserver()

    var body: some View {
		let glassBaseOpacity = focusObserver.isFocused ? 0.6 : 0.3
		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - bottomBarHeight)
			let panelMinHeight = min(basePanelMinHeight, availableHeight)
			let panelMinWidth = 630
			VStack(alignment: .leading) {
				HStack(alignment: .top) {
					ZStack(alignment: .topLeading) {
						VStack(alignment: .leading, spacing: 16) {
							SectionHeader("Import Applications", subtitle: "Upload local packages and metadata for Workspace ONE.")

							ElevatedPanel(style: .glass) {
								VStack(alignment: .leading, spacing: 12) {
									JuiceTypography.sectionTitle("Drop files here")
									JuiceTypography.smallCaption("Supported: PKG, DMG, ZIP")
									HStack(spacing: 8) {
										JuiceButtons.primary("Choose Files") {}
										JuiceButtons.secondary("Clear") {}
									}
								}
							}
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

					Color.clear.frame(width: 24)

					QueuePanel(
						tab: $rightTab,
						queueTitle: "Applications Queue",
						resultsTitle: "Results",
						queueCountText: "\(queueItems.count) items",
						resultsCountText: "\(resultsItems.count) completed",
						queueIsEmpty: queueItems.isEmpty,
						resultsIsEmpty: resultsItems.isEmpty,
						onQueueAction: {
							withAnimation(.easeInOut(duration: 0.2)) {
								queueItems.removeAll()
							}
						},
						onResultsAction: {
							withAnimation(.easeInOut(duration: 0.2)) {
								resultsItems.removeAll()
							}
						}
					) {
						AnyView(
							LazyVStack(spacing: 8) {
								ForEach(queueItems) { item in
									ImportRowView(item: item)
										.transition(.opacity.combined(with: .move(edge: .top)))
								}
							}
						)
					} resultsContent: {
						AnyView(
							LazyVStack(spacing: 8) {
								ForEach(resultsItems) { item in
									ImportRowView(item: item)
										.transition(.opacity.combined(with: .move(edge: .top)))
								}
							}
						)
					}
					.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
					.frame(width: 400, alignment: .center)
					.frame(maxWidth: .infinity, alignment: .trailing)
				}
				.frame(maxWidth: .infinity, alignment: .topLeading)
				.padding(.horizontal, 40)
				.padding(.vertical, 0)

				HStack {
					Spacer()
					JuiceButtons.primary("Upload to UEM") {}
						.disabled(queueItems.isEmpty)
				}
				.padding(.horizontal, 40)
				.padding(.top, 20)
				.padding(.bottom, 24)
				.frame(alignment: .top)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.ifAvailableMacOS14ContentMarginsElsePadding()
		.onAppear {
			queueItems = model.importItems
			resultsItems = model.importResults
		}
    }
}

#Preview {
    ImportView(model: .sample)
        .frame(width: 800, height: 500)
}
