import SwiftUI

struct ImportView: View {
    let model: PageViewData
	@EnvironmentObject private var inspector: InspectorCoordinator
    @State private var rightTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
    @State private var queueItems: [ImportItem] = []
    @State private var resultsItems: [ImportItem] = []
	@State private var confirmationVisible = false
	@State private var confirmationMode: ConfirmationActionMode = .upload
	private let basePanelMinHeight: CGFloat = 680
	private let bottomBarHeight: CGFloat = 88
	private let panelGlassOpacity: CGFloat = 0.95
	@StateObject private var focusObserver = WindowFocusObserver()
	@State private var panelMinHeightCache: CGFloat = 0

    var body: some View {
		let glassBaseOpacity = focusObserver.isFocused ? 0.6 : 0.3
		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - bottomBarHeight)
			let panelMinHeight = min(basePanelMinHeight, availableHeight)
			let panelMinWidth = 630
			ZStack(alignment: .bottomTrailing) {
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
					}
					.frame(maxWidth: .infinity, alignment: .topLeading)
					.padding(.horizontal, 40)
					.padding(.vertical, 0)
					.contentShape(Rectangle())
					.onTapGesture {
						if inspector.isPresented {
							inspector.hide()
						}
					}
					Spacer(minLength: 20)
				}

				EmptyView()
			}
			.onAppear {
				panelMinHeightCache = panelMinHeight
			}
			.onChange(of: panelMinHeight) { _, newValue in
				panelMinHeightCache = newValue
				if inspector.isPresented {
					inspector.show(queuePanelView(panelMinHeight: newValue))
				}
			}
			.onChange(of: queueItems.count) { oldValue, newValue in
				guard oldValue == 0, newValue > 0 else { return }
				guard !inspector.isPresented else { return }
				inspector.show(queuePanelView(panelMinHeight: panelMinHeightCache))
			}
			.onChange(of: inspector.isPresented) { _, isPresented in
				if isPresented {
					inspector.show(queuePanelView(panelMinHeight: panelMinHeightCache))
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.ifAvailableMacOS14ContentMarginsElsePadding()
		.onAppear {
			queueItems = model.importItems
			resultsItems = model.importResults
		}
		.sheet(isPresented: $confirmationVisible) {
			QueueActionSheet(
				mode: confirmationMode,
				itemCount: queueItems.count,
				onConfirm: {
					confirmationVisible = false
				},
				onCancel: {
					confirmationVisible = false
				}
			)
		}
    }

	@ViewBuilder
	private func queuePanelView(panelMinHeight: CGFloat) -> some View {
		InspectorImportQueuePanelView(
			tab: $rightTab,
			queueItems: $queueItems,
			resultsItems: $resultsItems,
			panelMinHeight: panelMinHeight,
			onPrimaryAction: {
				confirmationMode = .upload
				confirmationVisible = true
			},
			onSecondaryAction: {
				confirmationMode = .download
				confirmationVisible = true
			}
		)
	}

	
}

#Preview {
    ImportView(model: .sample)
		.environmentObject(InspectorCoordinator())
        .frame(width: 800, height: 500)
}
