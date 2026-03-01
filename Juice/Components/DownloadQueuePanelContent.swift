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

	private var queueSectionLabel: String {
		if model.stage == .uploading { return "Uploading" }
		return "Downloading"
	}

	var body: some View {
		let hasQueueItems = !model.queueItems.isEmpty
		let hasEditableItems = !model.editableDownloads.isEmpty
		let hasResults = !model.results.isEmpty
		
		let showQueueAction = !(model.stage == .downloading
			|| model.stage == .editing
			|| model.stage == .uploading)
		let queueActionTitle = showQueueAction
			? (model.isRunning ? "Cancel All" : "Clear")
			: ""
		let showCancelButton = (hasQueueItems || hasEditableItems)
			&& (model.stage == .downloading
				|| model.stage == .editing
				|| model.stage == .uploading)
		let showContinueButton = hasEditableItems && (model.stage == .editing || model.stage == .downloading)
		
		let bottomActionsView: AnyView? = (showCancelButton || showContinueButton)
			? AnyView(
				HStack {
					Spacer()
					if showCancelButton {
						Button("Cancel") {
							showCancelConfirmation = true
						}
						.nativeActionButtonStyle(.secondary, controlSize: .large)
						.buttonBorderShape(.capsule)
						.juiceHelp(HelpText.DownloadQueue.cancelMetadataEdits)
					}
					if showContinueButton {
						Button("Continue") {
							model.startUploadAfterEdits()
						}
						.juiceGradientGlassProminentButtonStyle(controlSize: .large)
						.buttonBorderShape(.capsule)
						.juiceHelp(HelpText.DownloadQueue.continueAfterEdits)
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
			queueIsEmpty: !hasQueueItems && !hasEditableItems,
			resultsIsEmpty: !hasResults,
			queueActionTitle: queueActionTitle,
			resultsActionTitle: "Clear",
			onQueueAction: {
				if hasEditableItems && !hasQueueItems {
					model.startUploadAfterEdits()
				} else if model.isRunning {
					model.cancel()
				} else {
					model.clearQueue()
				}
			},
			onResultsAction: {
				withAnimation(.easeInOut(duration: 0.25)) {
					model.clearResults()
				}
			},
			isPinned: $inspector.isPinned,
			bottomActions: bottomActionsView
		) {
			AnyView(
				VStack(alignment: .leading, spacing: 16) {
					DownloadQueueStatusHeader(
						statusText: model.statusText,
						stageProgressText: model.stageProgressText
					)
					
					if hasQueueItems {
						VStack(alignment: .leading, spacing: 8) {
							if hasEditableItems || model.stage == .uploading {
								Text(queueSectionLabel)
									.font(.system(size: 11, weight: .bold))
									.foregroundStyle(.secondary)
									.padding(.leading, 4)
							}
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
					
					if hasEditableItems {
						VStack(alignment: .leading, spacing: 8) {
							if hasQueueItems {
								Divider()
									.padding(.vertical, 4)
								Text("Ready to Review")
									.font(.system(size: 11, weight: .bold))
									.foregroundStyle(.secondary)
									.padding(.leading, 4)
							}
							
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
						}
					}
				}
			)
		} resultsContent: {
			AnyView(
				VStack(spacing: 8) {
					ForEach(model.results) { result in
						DownloadResultRow(result: result)
							.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
				.padding(.horizontal, 10)
			)
		}
		.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
		.frame(maxWidth: .infinity, alignment: .trailing)
		.onAppearUnlessPreview {
			model.startIfNeeded()
			if model.stage == .completed || model.stage == .cancelled {
				tab = .results
			}
		}
		.onChange(of: model.stage) { _, newStage in
			if newStage == .editing {
				tab = .queue
			} else if newStage == .completed {
				DispatchQueue.main.async {
					tab = .results
				}
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
					},
					onSelectRecipe: { recipeId in
						// Just resolve the recipe without updating the parent view's state for the open sheet.
						// The sheet handles its own activeRecipe state.
						return model.recipesById[recipeId]
					}
				)
			}
		.sheet(isPresented: $showCancelConfirmation) {
			JuiceConfirmationSheet(
				title: "Cancel all in-progress work?",
				message: "This will stop any downloads or uploads and clear the queues.",
				confirmTitle: "Cancel All",
				cancelTitle: "Keep Going",
				isDestructive: true,
				onConfirm: {
					showCancelConfirmation = false
					model.cancelAndClearQueues()
				},
				onCancel: {
					showCancelConfirmation = false
				}
			)
		}
	}
}
