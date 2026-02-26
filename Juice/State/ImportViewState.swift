import SwiftUI

@MainActor
final class ImportViewState: ObservableObject {
    @Published var hasInitialized = false
    @Published var rightTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
    @Published var downloadQueueTab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
    @Published var queueItems: [ImportedApplication] = []
    @Published var resultsItems: [ImportedApplication] = []
    @Published var queueNotice: QueuePanelContent<AnyView, AnyView>.Notice?
    @Published var importApps: [ImportedApplication] = []
    @Published var selectedApp: ImportedApplication?
    @Published var selectedAppIds: Set<UUID> = []
    @Published var isScanning = false
    @Published var selectedFolderURL: URL?
    @Published var suppressQueueAutoShow = false
    @Published var showingDetails = false
    @Published var confirmationVisible = false
    @Published var confirmationMode: ConfirmationActionMode = .upload
    @Published var expandActionsTrigger: Int = 0
}
