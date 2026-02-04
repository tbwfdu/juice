import SwiftUI
#if os(macOS)
import AppKit
#endif

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
	let model: PageViewData
    @EnvironmentObject private var catalog: LocalCatalog
	@EnvironmentObject private var inspector: InspectorCoordinator
    @State private var searchText = ""
    @State private var rightTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
    @State private var isSearchResultVisible: Bool = false
    @State private var showSuggestions = false
    @FocusState private var isSearchFocused: Bool
    @State private var filteredResults: [CaskApplication] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedResult: CaskApplication?
	@State private var highlightedSuggestionIndex: Int? = nil
	@State private var suggestionRowFrames: [Int: CGRect] = [:]
	@State private var keyMonitor: Any?
    @State private var queueItems: [CaskApplication] = []
    @State private var resultsItems: [CaskApplication] = []
    @State private var queueNotice: QueuePanelContent<AnyView, AnyView>.Notice?
    @State private var confirmationVisible = false
    @State private var confirmationMode: ConfirmationActionMode = .upload
	@StateObject private var focusObserver = WindowFocusObserver()
	private let basePanelMinHeight: CGFloat = 680
	private let bottomBarHeight: CGFloat = 88
	private let panelGlassOpacity: CGFloat = 1.0
	@State private var panelMinHeightCache: CGFloat = 0

	private var glassBaseOpacity: CGFloat {
		focusObserver.isFocused ? 0.6 : 0.3
	}

	var body: some View {
		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - bottomBarHeight)
			let panelMinHeight = min(basePanelMinHeight, availableHeight)
//			let panelMinWidth = 630
			let panelMinWidth = 400
			ZStack(alignment: .bottomTrailing) {
				VStack(alignment: .leading) {
					HStack(alignment: .top) {
						leftPanel(
							panelMinHeight: panelMinHeight,
							panelMinWidth: CGFloat(panelMinWidth)
						)
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
					Spacer(minLength:20)
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
		.onChange(of: inspector.isPresented) { _, isPresented in
			if isPresented {
				inspector.show(queuePanelView(panelMinHeight: panelMinHeightCache))
			}
		}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.ifAvailableMacOS14ContentMarginsElsePadding()
		.onAppear {
			queueItems = model.queueItems
			resultsItems = model.searchResults
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
	private func leftPanel(panelMinHeight: CGFloat, panelMinWidth: CGFloat) -> some View {
		ZStack(alignment: .topLeading) {
			VStack(alignment: .leading, spacing: 16) {
				SectionHeader("Search", subtitle: "Use the search box below to find applications you wish to download or upload automatically to Workspace ONE.")
				HStack(spacing: 8) {
					AutoSuggestBox(
						text: $searchText,
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
								highlightedSuggestionIndex = 0
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
							highlightedSuggestionIndex = highlightedSuggestionIndex ?? 0
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
					.onAppear {
						updateSuggestions()
						showSuggestions = isSearchFocused && !searchText.isEmpty && !filteredResults.isEmpty
						if showSuggestions, !filteredResults.isEmpty {
							highlightedSuggestionIndex = 0
						}
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
							actionTitle: "Add"
						) {
							addSelectedToQueue()
						}
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
		.overlayPreferenceValue(AutoSuggestAnchorKey.self) { anchor in
			GeometryReader { proxy in
				if showSuggestions, isSearchFocused, !filteredResults.isEmpty, let anchor {
					let rect = proxy[anchor]
					let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
					let rowHeight: CGFloat = 52
					ScrollViewReader { scrollProxy in
						ScrollView(.vertical, showsIndicators: filteredResults.count > 1) {
							VStack(alignment: .leading, spacing: 0) {
								ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, app in
									Button {
										handleSuggestionSelection(app)
									} label: {
										suggestionRow(for: app)
											.contentShape(Rectangle())
											.background(
												RoundedRectangle(cornerRadius: 8, style: .continuous)
													.fill(Color.white.opacity(index == highlightedSuggestionIndex ? 0.22 : 0))
													.overlay(
														RoundedRectangle(cornerRadius: 8, style: .continuous)
															.stroke(Color.white.opacity(index == highlightedSuggestionIndex ? 0.38 : 0), lineWidth: 1)
													)
													.shadow(color: Color.white.opacity(index == highlightedSuggestionIndex ? 0.12 : 0), radius: 1, x: 0, y: 0.5)
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
						.coordinateSpace(name: "suggestionsScroll")
						.onPreferenceChange(SuggestionRowFrameKey.self) { frames in
							suggestionRowFrames = frames
						}
						.onChange(of: highlightedSuggestionIndex) { _, newValue in
							guard let newValue,
								  let frame = suggestionRowFrames[newValue] else { return }
							let visibleHeight = min(CGFloat(filteredResults.count) * rowHeight, 300)
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
					.frame(height: min(CGFloat(filteredResults.count) * rowHeight, 300))
					.background {
						if #available(macOS 26.0, iOS 26.0, *) {
							GlassEffectContainer {
								shape
									.fill(Color.clear)
									.glassEffect(.regular, in: shape)
							}
						} else {
							shape.fill(.ultraThinMaterial)
						}
					}
					.clipShape(shape)
					.overlay(shape.strokeBorder(.white.opacity(0.16)))
					.shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 6)
					.frame(width: rect.width, alignment: .leading)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
					.offset(x: rect.minX, y: rect.maxY + 6)
					.zIndex(100)
				}
			}
		}
		.contentShape(Rectangle())
		.onTapGesture {
			isSearchFocused = false
			showSuggestions = false
		}
	}

	@ViewBuilder
	private func queuePanelView(panelMinHeight: CGFloat) -> some View {
		InspectorQueuePanelView(
			tab: $rightTab,
			notice: $queueNotice,
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
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(app.desc ?? "")
                    .font(.caption)
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

    private func addSelectedToQueue() {
        guard let selected = selectedResult else { return }
        let token = selected.fullToken.isEmpty ? selected.token : selected.fullToken
        if queueItems.contains(where: { $0.id == token }) {
            showQueueNotice("Already in queue", isDuplicate: true)
            resetSearchUI()
            return
        }
        let wasEmpty = queueItems.isEmpty
        queueItems.append(selected)
		inspector.notifyQueueAdded()
        showQueueNotice("Added to queue", isDuplicate: false)
		if wasEmpty {
			inspector.show(queuePanelView(panelMinHeight: panelMinHeightCache))
		}
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
        queueNotice = .init(message: message, isDuplicate: isDuplicate)
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
						highlightedSuggestionIndex = min(highlightedSuggestionIndex ?? 0, results.count - 1)
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
	
    SearchView(model: .sample)
        .environmentObject(LocalCatalog())
		.environmentObject(InspectorCoordinator())
		.frame(width: 700, height: 400)
		.background(){
			JuiceGradient()
				.frame(maxWidth: .infinity)
				.frame(height: 500)
				.mask(
					LinearGradient(
						stops: [
							.init(color: Color.white, location: 0.0),
							.init(color: Color.white, location: 0.55),
							.init(color: Color.white.opacity(0.7), location: 0.7),
							.init(color: Color.white.opacity(0.3), location: 0.82),
							.init(color: Color.white.opacity(0.0), location: 1.0)
						],
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.ignoresSafeArea(edges: .top)
		}
}
