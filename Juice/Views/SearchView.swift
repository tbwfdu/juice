import SwiftUI
import OSLog
#if os(macOS)
import AppKit
#endif

// Search page.
// Layout ownership:
// - Left panel: query field, suggestions, selected app result card.
// - Inspector panel: queue/results and app detail flyouts.

extension View {
    @ViewBuilder
    func ifAvailableMacOS14ContentMarginsElsePadding() -> some View {
        if #available(macOS 14.0, *) {
            self.contentMargins(.zero)
        } else {
            self.padding(.zero)
        }
    }
}

struct AutoSuggestAnchorKey: PreferenceKey {
	static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct SuggestionRowFrameKey: PreferenceKey {
	static let defaultValue: [Int: CGRect] = [:]
	static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
		value.merge(nextValue(), uniquingKeysWith: { $1 })
	}
}

struct SearchView: View {
	private static let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "Juice",
		category: "SearchQueue"
	)

	// MARK: - Inputs & Environment

	let model: PageViewData
	@ObservedObject var state: SearchViewState
    @EnvironmentObject private var catalog: LocalCatalog
	@EnvironmentObject private var inspector: InspectorCoordinator
	@Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSearchFocused: Bool
    @State private var searchTask: Task<Void, Never>?
	@State private var keyMonitor: Any?
	@State private var queueNoticeTask: Task<Void, Never>?
	@StateObject private var downloadQueueModel = DownloadQueueViewModel()
	@StateObject private var focusObserver = WindowFocusObserver()
	private let basePanelMinHeight: CGFloat = 680
	private let bottomBarHeight: CGFloat = 88
	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
	}
	private var panelGlassOpacity: CGFloat {
		GlassThemeTokens.panelSurfaceOpacity(for: glassState)
	}
	@State private var panelMinHeightCache: CGFloat = 0

	private var glassBaseOpacity: CGFloat {
		GlassThemeTokens.panelBaseTintOpacity(for: glassState)
	}

	private var panelBaseTintColor: Color {
		GlassThemeTokens.controlBackgroundBase(for: glassState)
	}

	private var panelBorderColor: Color {
		GlassThemeTokens.borderColor(for: glassState, role: .standard)
	}

	private var panelNeutralOverlayOpacity: CGFloat {
		GlassThemeTokens.panelNeutralOverlayOpacity(for: glassState)
	}

	private func binding<T>(
		_ keyPath: ReferenceWritableKeyPath<SearchViewState, T>
	) -> Binding<T> {
		Binding(
			get: { state[keyPath: keyPath] },
			set: { state[keyPath: keyPath] = $0 }
		)
	}

	private var searchText: String {
		get { state.searchText }
		nonmutating set { state.searchText = newValue }
	}

	private var rightTab: QueuePanelContent<AnyView, AnyView>.Tab {
		get { state.rightTab }
		nonmutating set { state.rightTab = newValue }
	}

	private var isSearchResultVisible: Bool {
		get { state.isSearchResultVisible }
		nonmutating set { state.isSearchResultVisible = newValue }
	}

	private var showSuggestions: Bool {
		get { state.showSuggestions }
		nonmutating set { state.showSuggestions = newValue }
	}

	private var filteredResults: [CaskApplication] {
		get { state.filteredResults }
		nonmutating set { state.filteredResults = newValue }
	}

	private var selectedResult: CaskApplication? {
		get { state.selectedResult }
		nonmutating set { state.selectedResult = newValue }
	}

	private var isFetchingFileSize: Bool {
		get { state.isFetchingFileSize }
		nonmutating set { state.isFetchingFileSize = newValue }
	}

	private var selectedFileSizeText: String? {
		get { state.selectedFileSizeText }
		nonmutating set { state.selectedFileSizeText = newValue }
	}

	private var selectedFileSizeUnavailable: Bool {
		get { state.selectedFileSizeUnavailable }
		nonmutating set { state.selectedFileSizeUnavailable = newValue }
	}

	private var highlightedSuggestionIndex: Int? {
		get { state.highlightedSuggestionIndex }
		nonmutating set { state.highlightedSuggestionIndex = newValue }
	}

	private var suggestionRowFrames: [Int: CGRect] {
		get { state.suggestionRowFrames }
		nonmutating set { state.suggestionRowFrames = newValue }
	}

	private var queueItems: [CaskApplication] {
		get { state.queueItems }
		nonmutating set { state.queueItems = newValue }
	}

	private var resultsItems: [CaskApplication] {
		get { state.resultsItems }
		nonmutating set { state.resultsItems = newValue }
	}

	private var queueNotice: QueuePanelContent<AnyView, AnyView>.Notice? {
		get { state.queueNotice }
		nonmutating set { state.queueNotice = newValue }
	}

	private var confirmationVisible: Bool {
		get { state.confirmationVisible }
		nonmutating set { state.confirmationVisible = newValue }
	}

	private var confirmationMode: ConfirmationActionMode {
		get { state.confirmationMode }
		nonmutating set { state.confirmationMode = newValue }
	}

	private var downloadQueueTab: QueuePanelContent<AnyView, AnyView>.Tab {
		get { state.downloadQueueTab }
		nonmutating set { state.downloadQueueTab = newValue }
	}

	// MARK: - Body

	var body: some View {
		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - bottomBarHeight)
			let panelMinHeight = min(basePanelMinHeight, availableHeight)
//			let panelMinWidth = 630
			let panelMinWidth = 400
				ZStack(alignment: .bottomTrailing) {
					VStack(alignment: .leading) {
						HStack(alignment: .top) {
							// Main searchable content region.
							mainContentPanel(
								panelMinHeight: panelMinHeight,
								panelMinWidth: CGFloat(panelMinWidth)
						)
						}
						.frame(maxWidth: .infinity, alignment: .topLeading)
						.padding(.horizontal, 20)
						.padding(.vertical, 0)
						Spacer(minLength: 20)
					}

				EmptyView()
			}
			.onAppearUnlessPreview {
				panelMinHeightCache = panelMinHeight
			}
		.onChange(of: panelMinHeight) { _, newValue in
			panelMinHeightCache = newValue
			if inspector.isPresented {
				if downloadQueueModel.shouldPresentPanel {
					inspector.show(
						downloadPanelView(panelMinHeight: newValue)
					)
				} else {
					inspector.show(queuePanelView(panelMinHeight: newValue))
				}
			}
		}
		.onChange(of: inspector.isPresented) { _, isPresented in
			if isPresented {
				if downloadQueueModel.shouldPresentPanel {
					inspector.show(
						downloadPanelView(panelMinHeight: panelMinHeightCache)
					)
				} else {
					inspector.show(
						queuePanelView(panelMinHeight: panelMinHeightCache)
					)
				}
			}
		}
		.onChange(of: downloadQueueModel.shouldPresentPanel) { _, shouldPresent in
			if inspector.isPresented {
				if shouldPresent {
					inspector.show(
						downloadPanelView(panelMinHeight: panelMinHeightCache)
					)
				} else {
					inspector.show(
						queuePanelView(panelMinHeight: panelMinHeightCache)
					)
				}
			}
		}
		.onChange(of: downloadQueueModel.stage) { _, newStage in
			if inspector.isPresented {
				if newStage == .completed || newStage == .cancelled {
					inspector.show(
						downloadPanelView(panelMinHeight: panelMinHeightCache)
					)
				}
			}
		}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.ifAvailableMacOS14ContentMarginsElsePadding()
		.onAppearUnlessPreview {
			if !state.hasInitialized {
				queueItems = model.queueItems
				resultsItems = model.searchResults
				state.hasInitialized = true
			}
		}
			.sheet(isPresented: binding(\.confirmationVisible)) {
				QueueActionSheet(
				mode: confirmationMode,
				itemCount: queueItems.count,
				onConfirm: {
					let confirmedMode = confirmationMode
					confirmationVisible = false
					startQueueProcessing(mode: confirmedMode)
				},
				onCancel: {
					confirmationVisible = false
				}
				)
			}
			.onChange(of: confirmationVisible) { _, isVisible in
				Self.logger.debug("Search confirmationVisible changed: \(isVisible, privacy: .public)")
			}
			.onDisappear {
			queueNoticeTask?.cancel()
			queueNoticeTask = nil
		}
	}

	@ViewBuilder
	private func mainContentPanel(panelMinHeight: CGFloat, panelMinWidth: CGFloat) -> some View {
		ZStack(alignment: .topLeading) {
			VStack(alignment: .leading, spacing: 16) {
				SectionHeader("Search", subtitle: "Use the search box below to find applications you wish to download or upload automatically to Workspace ONE.")
				HStack(spacing: 8) {
					AutoSuggestBox(
						text: binding(\.searchText),
						suggestions: filteredResults,
						onSuggestionClick: { app in
							handleSuggestionSelection(app)
						},
						onCommit: {
							if let index = highlightedSuggestionIndex,
							   filteredResults.indices.contains(index) {
								handleSuggestionSelection(filteredResults[index])
								return
							}
						},
						isFocused: $isSearchFocused
					) { app in
						suggestionRow(for: app)
					}
					.anchorPreference(key: AutoSuggestAnchorKey.self, value: .bounds) { anchor in
						anchor
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.onChange(of: searchText) { _, newValue in
						if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
							filteredResults = []
							showSuggestions = false
							return
						}
						updateSuggestions()
						showSuggestions = isSearchFocused && !newValue.isEmpty && !filteredResults.isEmpty
					}
						.onChange(of: filteredResults.count) { _, _ in
							showSuggestions = isSearchFocused && !searchText.isEmpty && !filteredResults.isEmpty
							if showSuggestions, !filteredResults.isEmpty {
								if let current = highlightedSuggestionIndex, current < filteredResults.count {
									// keep current highlight
								} else {
									highlightedSuggestionIndex = nil
								}
							} else {
								highlightedSuggestionIndex = nil
							}
						}
						.onChange(of: isSearchFocused) { _, focused in
							if !focused {
								showSuggestions = false
								highlightedSuggestionIndex = nil
							} else if !searchText.isEmpty && !filteredResults.isEmpty {
								showSuggestions = true
								highlightedSuggestionIndex = nil
							}
						}
					.onChange(of: showSuggestions) { _, isVisible in
						if !isVisible {
							highlightedSuggestionIndex = nil
							stopKeyMonitor()
						} else {
							startKeyMonitor()
						}
					}
						.onAppearUnlessPreview {
							updateSuggestions()
							showSuggestions = isSearchFocused && !searchText.isEmpty && !filteredResults.isEmpty
							highlightedSuggestionIndex = nil
							if showSuggestions {
								startKeyMonitor()
							}
					}
					.onChange(of: catalog.caskApps.count) { _, _ in
						updateSuggestions()
					}
					.onMoveCommand { direction in
						moveSuggestionHighlight(direction)
					}
					.onExitCommand {
						dismissSuggestions()
					}
					.onDisappear {
						stopKeyMonitor()
					}
					if !searchText.isEmpty {
						Button {
							resetSearchUI()
						} label: {
							Image(systemName: "xmark.circle.fill")
								.foregroundStyle(.secondary)
						}
						.buttonStyle(.borderless)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)

				ZStack(alignment: .top) {
						if isSearchResultVisible, let selected = selectedResult {
							SearchResultCard(
								selectedApplication: selected,
								title: selected.name.first ?? selected.token,
								subtitle: selected.desc ?? "",
								token: selected.fullToken,
								version: selected.version,
								fileType: selected.fileType,
								fileSizeText: selectedFileSizeText,
								isFileSizeLoading: isFetchingFileSize,
								isFileSizeUnavailable: selectedFileSizeUnavailable,
								actionTitle: "Add"
							) {
								addToQueue(selected)
							}
							.padding(10)
							.background {
								let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
								Color.clear
									.glassCompatSurface(
										in: shape,
										style: .regular,
										context: glassState,
										fillColor: panelBaseTintColor,
										fillOpacity: min(
											1,
											glassBaseOpacity + (panelNeutralOverlayOpacity * 0.45)
										),
										surfaceOpacity: panelGlassOpacity
									)
							}
							.overlay(
								RoundedRectangle(cornerRadius: 14, style: .continuous)
									.strokeBorder(panelBorderColor.opacity(0.9))
							)
							.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
							.frame(maxWidth: 900, alignment: .leading)
							.transition(.opacity.animation(.easeInOut(duration: 0.15)))
							.zIndex(1)
					} else {
						Color.clear
							.frame(height: 160)
							.accessibilityHidden(true)
					}
				}
				.animation(.easeInOut(duration: 0.15), value: isSearchResultVisible)
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
		.background(colorScheme == .dark ? Color.black.opacity(0.40) : Color.white)
		.background {
			let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
			if #available(macOS 26.0, iOS 16.0, *) {
				GlassEffectContainer {
					shape
						.fill(Color.clear)
						.glassEffect(.regular, in: shape)
				}
			} else {
				shape.fill(.ultraThinMaterial)
			}
		}
		.overlay {
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.strokeBorder(Color.white.opacity(0.15))
		}
		.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
		.background(WindowFocusReader { focusObserver.attach($0) })
		.zIndex(1)
		.overlay(alignment: .center) {
			if let notice = queueNotice {
				leftPanelQueueNotice(notice)
					.transition(
						.opacity.combined(with: .scale(scale: 0.96, anchor: .center))
					)
					.allowsHitTesting(false)
			}
		}
		.animation(.bouncy(duration: 0.22, extraBounce: 0.08), value: queueNotice)

		}
			.overlayPreferenceValue(AutoSuggestAnchorKey.self) { anchor in
				GeometryReader { proxy in
					if showSuggestions, isSearchFocused, !filteredResults.isEmpty, let anchor {
					let rect = proxy[anchor]
					let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
					let rowHeight: CGFloat = 56
					let verticalPadding: CGFloat = 20 // 8 top + 12 bottom from panelContentScrollChrome
					ScrollViewReader { scrollProxy in
							ScrollView(.vertical, showsIndicators: filteredResults.count > 1) {
								VStack(alignment: .leading, spacing: 0) {
										ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, app in
											let isHighlighted = index == highlightedSuggestionIndex
											let highlightTone = Color(
												hex: JuiceStyleConfig.defaultTintHex
											)
											let highlightFill = isHighlighted
												? highlightTone.opacity(
													glassState.colorScheme == .dark ? 0.24 : 0.16
												)
												: .clear
											let highlightBorder = isHighlighted
												? highlightTone.opacity(
													glassState.colorScheme == .dark ? 0.44 : 0.34
												)
												: .clear
											Button {
												handleSuggestionSelection(app)
											} label: {
												suggestionRow(for: app)
													.contentShape(Rectangle())
													.background(
														RoundedRectangle(cornerRadius: 8, style: .continuous)
															.fill(highlightFill)
															.overlay(
																RoundedRectangle(cornerRadius: 8, style: .continuous)
																	.stroke(highlightBorder, lineWidth: 1)
															)
															.padding(.horizontal, 4)
															.padding(.top, 4)
															.padding(.bottom, 1)
													)
											}
									.buttonStyle(.plain)
									.onHover { hovering in
										if hovering {
											highlightedSuggestionIndex = index
										}
									}
									.background(
										GeometryReader { rowProxy in
											Color.clear.preference(
												key: SuggestionRowFrameKey.self,
												value: [index: rowProxy.frame(in: .named("suggestionsScroll"))]
											)
										}
									)
									.id(index)
								}
								}
							}
							.panelContentScrollChrome(topInset: 8, bottomContentInset: 12)
							.coordinateSpace(name: "suggestionsScroll")
							.onPreferenceChange(SuggestionRowFrameKey.self) { frames in
							suggestionRowFrames = frames
						}
						.onChange(of: highlightedSuggestionIndex) { _, newValue in
							guard let newValue,
								  let frame = suggestionRowFrames[newValue] else { return }
							let visibleHeight = min(CGFloat(filteredResults.count) * rowHeight + verticalPadding, 300)
							if frame.minY < 0 {
								withAnimation(.easeOut(duration: 0.12)) {
									scrollProxy.scrollTo(newValue, anchor: .top)
								}
							} else if frame.maxY > visibleHeight {
								withAnimation(.easeOut(duration: 0.12)) {
									scrollProxy.scrollTo(newValue, anchor: .bottom)
								}
							}
						}
						}
							.frame(height: min(CGFloat(filteredResults.count) * rowHeight + verticalPadding, 300))
							.background {
								Color.clear
									.glassCompatSurface(
										in: shape,
										style: .clear,
										context: glassState,
										fillColor: panelBaseTintColor,
										fillOpacity: min(1, glassBaseOpacity + panelNeutralOverlayOpacity),
										surfaceOpacity: 1
									)
							}
						.clipShape(shape)
						.glassCompatBorder(in: shape, context: glassState, role: .strong)
						.glassCompatShadow(context: glassState, elevation: .panel)
						.frame(width: rect.width, alignment: .leading)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
					.offset(x: rect.minX, y: rect.maxY + 6)
					.zIndex(100)
					}
				}
				.allowsHitTesting(showSuggestions && isSearchFocused && !filteredResults.isEmpty)
			}
			.onChange(of: selectedResult?.id) { _, _ in
			guard let app = selectedResult else {
				isFetchingFileSize = false
				selectedFileSizeText = nil
				selectedFileSizeUnavailable = false
				return
			}
			loadFileSize(for: app)
		}
	}

	@ViewBuilder
	private func queuePanelView(panelMinHeight: CGFloat) -> some View {
		InspectorSearchQueuePanelView(
			tab: binding(\.rightTab),
			notice: .constant(nil),
			queueItems: binding(\.queueItems),
			resultsItems: binding(\.resultsItems),
			panelMinHeight: panelMinHeight,
			onPrimaryAction: {
				Self.logger.debug("Search queue primary action invoked")
				confirmationMode = .upload
				confirmationVisible = true
			},
			onSecondaryAction: {
				Self.logger.debug("Search queue secondary action invoked")
				confirmationMode = .download
				confirmationVisible = true
			},
			onQueueItemsRemoved: { removedItems in
				// If we want to restore them somewhere, we can.
				// For search, removing from queue just removes it.
			}
		)
	}

	@ViewBuilder
	private func downloadPanelView(panelMinHeight: CGFloat) -> some View {
		DownloadQueuePanelContent(
			model: downloadQueueModel,
			tab: binding(\.downloadQueueTab),
			panelMinHeight: panelMinHeight
		)
	}

    @ViewBuilder
    private func suggestionRow(for app: CaskApplication) -> some View {
        HStack(spacing: 12) {
            ZStack {
				IconByFiletype(applicationFileName: app.url)
					.aspectRatio(contentMode: .fit)
					.frame(width: 32, height: 32)
            }
            VStack(alignment: .leading) {
                Text(app.name.first ?? app.token)
					.font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(app.desc ?? "")
					.font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
       // .padding(.vertical, 4)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }

	private func handleSuggestionSelection(_ app: CaskApplication) {
        selectedResult = app
        isSearchResultVisible = true
        showSuggestions = false
        isSearchFocused = false
		highlightedSuggestionIndex = nil
    }

	    private func addToQueue(_ selected: CaskApplication) {
	        let token = selected.fullToken.isEmpty ? selected.token : selected.fullToken
	        if queueItems.contains(where: { $0.id == token }) {
	            showQueueNotice("Already in Queue", isDuplicate: true)
	            resetSearchUI()
	            return
	        }
					if !downloadQueueModel.results.isEmpty {
						downloadQueueModel.reset()
						downloadQueueTab = .queue
						rightTab = .queue
					}
			let wasQueueEmpty = queueItems.isEmpty
	        queueItems.append(selected)
			inspector.notifyQueueAdded(
				by: 1,
				triggerInspectorAttention: wasQueueEmpty && !inspector.isPresented
			)
	        showQueueNotice("App added to Queue", isDuplicate: false)
	        resetSearchUI()
	    }

    private func resetSearchUI() {
		searchTask?.cancel()
		searchTask = nil
        searchText = ""
        filteredResults = []
        selectedResult = nil
        isSearchResultVisible = false
        showSuggestions = false
        isSearchFocused = false
		highlightedSuggestionIndex = nil
    }

    private func showQueueNotice(_ message: String, isDuplicate: Bool) {
		let notice = QueuePanelContent<AnyView, AnyView>.Notice(
			message: message,
			isDuplicate: isDuplicate
		)
		queueNoticeTask?.cancel()
		withAnimation(.bouncy(duration: 0.2, extraBounce: 0.08)) {
			queueNotice = notice
		}
		queueNoticeTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 1_500_000_000)
			guard !Task.isCancelled else { return }
			withAnimation(.easeInOut(duration: 0.14)) {
				queueNotice = nil
			}
		}
    }

	@ViewBuilder
	private func leftPanelQueueNotice(
		_ notice: QueuePanelContent<AnyView, AnyView>.Notice
	) -> some View {
		let shape = Capsule()
		HStack(spacing: 8) {
			Image(
				systemName: notice.isDuplicate
					? "exclamationmark.triangle.fill"
					: "checkmark.circle.fill"
			)
			.foregroundStyle(notice.isDuplicate ? Color.orange : Color.green)
			.font(.system(size: 14, weight: .bold))
			Text(notice.message)
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 8)
		.background {
			Color.clear
				.glassCompatSurface(
					in: shape,
					style: .clear,
					context: glassState,
					fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
					fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: glassState),
					surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: glassState)
				)
				.glassCompatBorder(in: shape, context: glassState, role: .standard)
				.glassCompatShadow(context: glassState, elevation: .panel)
		}
	}

    private func updateSuggestions() {
        searchTask?.cancel()
        let trimmed = searchText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let currentSearchText = self.searchText
        guard !trimmed.isEmpty else {
            filteredResults = []
            selectedResult = nil
			highlightedSuggestionIndex = nil
            return
        }
        let allApps = catalog.caskApps
        searchTask = Task.detached(priority: .userInitiated) { [trimmed, allApps, currentSearchText] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            let needle = trimmed.lowercased()
            let results = allApps.filter { app in
                let nameMatch = app.name.first?.lowercased().contains(needle) ?? false
                let tokenMatch = app.token.lowercased().contains(needle)
                let fullTokenMatch = app.fullToken.lowercased().contains(needle)
                let descMatch = app.desc?.lowercased().contains(needle) ?? false
                return nameMatch || tokenMatch || fullTokenMatch || descMatch
            }
            .prefix(20)
            .map { $0 }
            await MainActor.run {
                if trimmed == currentSearchText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) {
                    filteredResults = results
                    if let selected = selectedResult {
						let selectedKey = appKey(selected)
						if !results.contains(where: { appKey($0) == selectedKey }) {
                        selectedResult = nil
                        isSearchResultVisible = false
						}
                    }
						if showSuggestions, !results.isEmpty {
							if let current = highlightedSuggestionIndex {
								highlightedSuggestionIndex = min(current, results.count - 1)
							}
						} else if results.isEmpty {
							highlightedSuggestionIndex = nil
						}
                }
            }
        }
    }

	private func moveSuggestionHighlight(_ direction: MoveCommandDirection) {
		guard showSuggestions, !filteredResults.isEmpty else { return }
		var index = highlightedSuggestionIndex ?? (direction == .down ? -1 : filteredResults.count)
		switch direction {
		case .down:
			index += 1
		case .up:
			index -= 1
		default:
			return
		}
		if index < 0 { index = filteredResults.count - 1 }
		if index >= filteredResults.count { index = 0 }
		highlightedSuggestionIndex = index
	}

	private func loadFileSize(for app: CaskApplication) {
		let urlString = app.url
		if urlString.isEmpty {
			selectedFileSizeText = nil
			selectedFileSizeUnavailable = true
			isFetchingFileSize = false
			return
		}

		selectedFileSizeText = nil
		selectedFileSizeUnavailable = false
		isFetchingFileSize = true

		Task {
			let currentId = app.id
			if let cached = await RemoteFileSizeService.cachedSizeText(for: urlString) {
				await MainActor.run {
					guard selectedResult?.id == currentId else { return }
					selectedFileSizeText = cached
					selectedFileSizeUnavailable = false
					isFetchingFileSize = false
				}
				return
			}

			let label = await RemoteFileSizeService.sizeText(for: urlString)
			await MainActor.run {
				guard selectedResult?.id == currentId else { return }
				if let label {
					selectedFileSizeText = label
					selectedFileSizeUnavailable = false
				} else {
					selectedFileSizeText = nil
					selectedFileSizeUnavailable = true
				}
				isFetchingFileSize = false
			}
		}
	}

	private func startQueueProcessing(mode: ConfirmationActionMode) {
		guard !queueItems.isEmpty else { return }
		downloadQueueModel.configure(
			queue: queueItems,
			mode: mode,
			recipes: catalog.recipes
		)
		queueItems.removeAll()
		inspector.show(
			downloadPanelView(panelMinHeight: panelMinHeightCache)
		)
		downloadQueueModel.start()
	}

	private func dismissSuggestions() {
		showSuggestions = false
		highlightedSuggestionIndex = nil
	}

	private func startKeyMonitor() {
#if os(macOS)
		guard keyMonitor == nil else { return }
		keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
			guard showSuggestions, isSearchFocused else { return event }
			switch event.keyCode {
			case 126: // up arrow
				moveSuggestionHighlight(.up)
				return nil
			case 125: // down arrow
				moveSuggestionHighlight(.down)
				return nil
			case 53: // escape
				dismissSuggestions()
				return nil
			case 36, 76: // return / keypad enter
				if let index = highlightedSuggestionIndex,
				   filteredResults.indices.contains(index) {
					handleSuggestionSelection(filteredResults[index])
					return nil
				}
				return event
			default:
				return event
			}
		}
#endif
	}

	private func stopKeyMonitor() {
#if os(macOS)
		if let monitor = keyMonitor {
			NSEvent.removeMonitor(monitor)
			keyMonitor = nil
		}
#endif
	}

	private func iconAsset(from app: CaskApplication) -> String {
		let lower = app.url.lowercased()
		if lower.contains(".pkg") { return "pkgIcon" }
		if lower.contains(".dmg") { return "dmgIcon" }
		if lower.contains(".zip") { return "zipIcon" }
		return "documentIcon"
	}

	private func appKey(_ app: CaskApplication) -> String {
		let key = app.fullToken.isEmpty ? app.token : app.fullToken
		return key.lowercased()
	}

}

#Preview {
	
    SearchView(model: .sample, state: SearchViewState())
        .environmentObject(LocalCatalog())
		.environmentObject(InspectorCoordinator())
		.frame(width: 700, height: 400)
	        .background(){
				JuiceGradient()
					.frame(maxWidth: .infinity)
					.frame(height: 500)
					.mask(
						LinearGradient(
							stops: JuiceBackgroundStyle.v1.legacyTopGradientMaskStops,
							startPoint: .top,
							endPoint: .bottom
						)
				)
				.ignoresSafeArea(edges: .top)
		}
}
