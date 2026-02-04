import SwiftUI

struct InspectorQueuePanelView: View {
	@EnvironmentObject private var inspector: InspectorCoordinator
	@Binding var tab: QueuePanelContent<AnyView, AnyView>.Tab
	@Binding var notice: QueuePanelContent<AnyView, AnyView>.Notice?
	@Binding var queueItems: [CaskApplication]
	@Binding var resultsItems: [CaskApplication]
	let panelMinHeight: CGFloat
	let onPrimaryAction: () -> Void
	let onSecondaryAction: () -> Void

	var body: some View {
		QueuePanelContent(
			tab: $tab,
			notice: $notice,
			queueTitle: "Queue",
			resultsTitle: "Results",
			queueCountText: "\(queueItems.count) apps added",
			resultsCountText: "\(resultsItems.count) processed",
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
			},
			isPinned: $inspector.isPinned,
			bottomActions: AnyView(
				QueueBottomActions(
					primaryTitle: "Upload to UEM",
					secondaryTitle: "Download Only",
					isEnabled: !queueItems.isEmpty,
					queueCount: queueItems.count,
					onPrimary: onPrimaryAction,
					onSecondary: onSecondaryAction
				)
			)
		) {
			AnyView(LazyVStack(spacing: 8) {
				ForEach(queueItems) { item in
					AppDetailListItem(item: item, label: "Version")
						.transition(.opacity.combined(with: .move(edge: .top)))
				}
			})
		} resultsContent: {
			AnyView(LazyVStack(spacing: 8) {
				ForEach(resultsItems) { item in
					AppDetailListItem(item: item, label: "Version")
						.transition(.opacity.combined(with: .move(edge: .top)))
				}
			})
		}
		.frame(alignment: .leading)
		.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
		.frame(width: 400, alignment: .center)
		.frame(maxWidth: .infinity, alignment: .trailing)
		.background(Color.clear)
	}
}

struct InspectorUpdatesQueuePanelView: View {
	@EnvironmentObject private var inspector: InspectorCoordinator
	@Binding var tab: QueuePanelContent<AnyView, AnyView>.Tab
	@Binding var notice: QueuePanelContent<AnyView, AnyView>.Notice?
	@Binding var queueItems: [CaskApplication]
	@Binding var resultsItems: [CaskApplication]
	@Binding var selectedAppKeys: Set<String>
	let panelMinHeight: CGFloat
	let onPrimaryAction: () -> Void
	let onSecondaryAction: () -> Void

	var body: some View {
		QueuePanelContent(
			tab: $tab,
			notice: $notice,
			queueTitle: "Updates Queue",
			resultsTitle: "Results",
			queueCountText: "\(queueItems.count) selected",
			resultsCountText: "\(resultsItems.count) processed",
			queueIsEmpty: queueItems.isEmpty,
			resultsIsEmpty: resultsItems.isEmpty,
			onQueueAction: {
				withAnimation(.easeInOut(duration: 0.2)) {
					queueItems.removeAll()
					selectedAppKeys.removeAll()
				}
			},
			onResultsAction: {
				withAnimation(.easeInOut(duration: 0.2)) {
					resultsItems.removeAll()
				}
			},
			isPinned: $inspector.isPinned,
			bottomActions: AnyView(
				QueueBottomActions(
					primaryTitle: "Upload to UEM",
					secondaryTitle: "Download Only",
					isEnabled: !queueItems.isEmpty,
					queueCount: queueItems.count,
					onPrimary: onPrimaryAction,
					onSecondary: onSecondaryAction
				)
			)
		) {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(queueItems) { item in
						AppDetailListItem(
							item: item,
							label: "New Version"
						)
						.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
			)
		} resultsContent: {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(resultsItems) { item in
						AppDetailListItem(
							item: item,
							label: "New Version"
						)
						.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
			)
		}
		.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
		.frame(width: 400, alignment: .center)
		.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

struct InspectorImportQueuePanelView: View {
	@EnvironmentObject private var inspector: InspectorCoordinator
	@Binding var tab: QueuePanelContent<AnyView, AnyView>.Tab
	@Binding var queueItems: [ImportItem]
	@Binding var resultsItems: [ImportItem]
	let panelMinHeight: CGFloat
	let onPrimaryAction: () -> Void
	let onSecondaryAction: () -> Void

	var body: some View {
		QueuePanelContent(
			tab: $tab,
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
			},
			isPinned: $inspector.isPinned,
			bottomActions: AnyView(
				QueueBottomActions(
					primaryTitle: "Upload to UEM",
					secondaryTitle: "Download Only",
					isEnabled: !queueItems.isEmpty,
					queueCount: queueItems.count,
					onPrimary: onPrimaryAction,
					onSecondary: onSecondaryAction
				)
			)
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
}
