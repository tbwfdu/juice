import Foundation
import SwiftUI

@MainActor
final class IOSCatalogStore: ObservableObject {
    @Published private(set) var apps: [IOSCaskApp] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published var query: String = ""

    // Placeholder "installed" versions used for update checks on iOS preview/scaffold.
    // This intentionally avoids upload/download/import workflows.
    private let installedVersionsByToken: [String: String] = [
        "slack": "4.35.0",
        "zoom": "5.16.0",
        "notion": "3.8.0",
        "firefox": "120.0",
        "google-chrome": "124.0.0"
    ]

    func loadIfNeeded() async {
        guard apps.isEmpty, !isLoading else { return }
        await loadCatalog()
    }

    func loadCatalog() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let url = Bundle.main.url(forResource: "cask_apps", withExtension: "json") else {
                throw NSError(domain: "IOSCatalogStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Missing cask_apps.json in app bundle"]) 
            }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([IOSCaskApp].self, from: data)
            self.apps = decoded
            self.loadError = nil
        } catch {
            self.apps = []
            self.loadError = error.localizedDescription
        }
    }

    var filteredApps: [IOSCaskApp] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }

        return apps.filter { app in
            app.token.localizedCaseInsensitiveContains(term)
                || app.displayName.localizedCaseInsensitiveContains(term)
                || (app.desc?.localizedCaseInsensitiveContains(term) ?? false)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        .prefix(100)
        .map { $0 }
    }

    var availableUpdates: [IOSAvailableUpdate] {
        installedVersionsByToken.compactMap { token, installed in
            guard let app = apps.first(where: { $0.token == token }) else { return nil }
            let latest = normalized(app.version)
            let current = normalized(installed)
            guard !latest.isEmpty, !current.isEmpty else { return nil }
            guard latest != current else { return nil }
            return IOSAvailableUpdate(app: app, installedVersion: installed)
        }
        .sorted { $0.app.displayName.localizedCaseInsensitiveCompare($1.app.displayName) == .orderedAscending }
    }

    private func normalized(_ version: String?) -> String {
        (version ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ",")
            .first
            .map(String.init) ?? ""
    }
}
