import SwiftUI
#if os(macOS)
import AppKit
#endif
import os

struct DownloadQueuePanelContent: View {
	@ObservedObject var model: DownloadQueueViewModel
	@Binding var tab: QueuePanelContent<AnyView, AnyView>.Tab
	let panelMinHeight: CGFloat
	@EnvironmentObject private var inspector: InspectorCoordinator
	@State private var selectedEditable: EditableDownload?
	@State private var showCancelConfirmation = false

	var body: some View {
		let isEditing = model.stage == .editing
		let hasQueueItems = isEditing ? model.hasEditableDownloads : !model.queueItems.isEmpty
		let showQueueAction = !(model.stage == .downloading
			|| model.stage == .editing
			|| model.stage == .uploading)
		let queueActionTitle = showQueueAction
			? (model.isRunning ? "Cancel All" : "Clear")
			: ""
		let showCancelButton = hasQueueItems
			&& (model.stage == .downloading
				|| model.stage == .editing
				|| model.stage == .uploading)
		let showContinueButton = hasQueueItems && model.stage == .editing
		let bottomActionsView: AnyView? = (showCancelButton || showContinueButton)
			? AnyView(
					HStack {
						Spacer()
						if showCancelButton {
							Button("Cancel") {
								showCancelConfirmation = true
							}
							.nativeActionButtonStyle(.secondary, controlSize: .small)
						}
						if showContinueButton {
							Button("Continue") {
								model.startUploadAfterEdits()
							}
							.nativeActionButtonStyle(.primary, controlSize: .small)
						}
					}
			)
			: nil
		QueuePanelContent(
			tab: $tab,
			queueTitle: "Queue",
			resultsTitle: "Results",
			queueCountText: model.queueCountText,
			resultsCountText: model.resultsCountText,
			queueIsEmpty: isEditing ? !model.hasEditableDownloads : model.queueItems.isEmpty,
			resultsIsEmpty: model.results.isEmpty,
			queueActionTitle: queueActionTitle,
			resultsActionTitle: "Clear",
			onQueueAction: {
				if isEditing {
					model.startUploadAfterEdits()
				} else if model.isRunning {
					model.cancel()
				} else {
					model.clearQueue()
				}
			},
			onResultsAction: {
				model.clearResults()
			},
			isPinned: $inspector.isPinned,
			bottomActions: bottomActionsView
		) {
			AnyView(
				VStack(alignment: .leading, spacing: 12) {
					DownloadQueueStatusHeader(
						statusText: model.statusText,
						stageProgressText: model.stageProgressText,
					)
					if isEditing {
						DownloadEditReviewList(
							model: model,
							onEdit: { id in
								if let index = model.editableDownloads.firstIndex(where: { $0.id == id }) {
									if !model.editableDownloads[index].iconPaths.isEmpty {
										model.editableDownloads[index].selectedIconIndex = 0
									}
									selectedEditable = model.editableDownloads[index]
								}
							}
						)
					} else {
						LazyVStack(spacing: 8) {
							ForEach(model.queueItems) { item in
								DownloadQueueRow(
									app: item,
									uploadStatus: model.uploadStatus(for: item)
								)
								.transition(.opacity.combined(with: .move(edge: .top)))
							}
						}
					}
				}
			)
		} resultsContent: {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(model.results) { result in
						DownloadResultRow(result: result)
							.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
			)
		}
		.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
		.frame(width: 400, alignment: .center)
		.frame(maxWidth: .infinity, alignment: .trailing)
		.onAppearUnlessPreview {
			model.startIfNeeded()
		}
		.onChange(of: model.stage) { _, newStage in
			if newStage == .editing {
				tab = .queue
			}
		}
		.sheet(item: $selectedEditable) { editable in
			MetadataEditSheet(
				download: editable,
				onSave: { updated in
					model.updateEditedDownload(updated)
					selectedEditable = nil
				},
				onCancel: {
					selectedEditable = nil
				}
			)
		}
		.confirmationDialog(
			"Cancel all in-progress work?",
			isPresented: $showCancelConfirmation,
			titleVisibility: .visible
		) {
			Button("Cancel All", role: .destructive) {
				model.cancelAndClearQueues()
			}
			Button("Keep Going", role: .cancel) {}
		} message: {
			Text("This will stop any downloads or uploads and clear the queues.")
		}
	}
}
