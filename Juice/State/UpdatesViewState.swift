import SwiftUI

@MainActor
final class UpdatesViewState: ObservableObject {
    @Published var hasInitialized = false
    @Published var rightTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
    @Published var queueItems: [CaskApplication] = []
    @Published var queuedSourceAppsByKey: [String: UemApplication] = [:]
    @Published var resultsItems: [CaskApplication] = []
    @Published var uemApps: [UemApplication] = []
    @Published var isQueryingUem = false
    @Published var showAllUemApps = false
    @Published var selectedApp: UemApplication?
    @Published var selectedAppKeys: Set<String> = []
    @Published var queueNotice: QueuePanelContent<AnyView, AnyView>.Notice?
    @Published var confirmationVisible = false
    @Published var confirmationMode: ConfirmationActionMode = .upload
    @Published var downloadQueueTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
    @Published var expandActionsTrigger: Int = 0
    @Published var isClearActionExpanded = false
}
