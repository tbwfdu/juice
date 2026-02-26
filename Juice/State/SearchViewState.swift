import SwiftUI

@MainActor
final class SearchViewState: ObservableObject {
    @Published var hasInitialized = false
    @Published var searchText = ""
    @Published var rightTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
    @Published var isSearchResultVisible = false
    @Published var showSuggestions = false
    @Published var filteredResults: [CaskApplication] = []
    @Published var selectedResult: CaskApplication?
    @Published var isFetchingFileSize = false
    @Published var selectedFileSizeText: String?
    @Published var selectedFileSizeUnavailable = false
    @Published var highlightedSuggestionIndex: Int?
    @Published var suggestionRowFrames: [Int: CGRect] = [:]
    @Published var queueItems: [CaskApplication] = []
    @Published var resultsItems: [CaskApplication] = []
    @Published var queueNotice: QueuePanelContent<AnyView, AnyView>.Notice?
    @Published var confirmationVisible = false
    @Published var confirmationMode: ConfirmationActionMode = .upload
    @Published var downloadQueueTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
}
