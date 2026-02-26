import Foundation

@MainActor
final class LocalCatalog: ObservableObject {
    @Published private(set) var caskApps: [CaskApplication] = []
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var isLoaded = false
    @Published private(set) var loadError: String?

    private let store: LocalCatalogCache

    init() {
        self.store = LocalCatalogCache()
        Task { @MainActor in
            await loadLocalCatalog()
        }
    }

    func loadLocalCatalog() async {
        do {
            let caskApps = try await store.loadCaskApps()
            let loadedRecipes = try await store.loadRecipes()
            self.caskApps = caskApps
            self.recipes = loadedRecipes
            self.isLoaded = true
        } catch {
            let nsError = error as NSError
            let filePath = (nsError.userInfo[NSFilePathErrorKey] as? String) ?? "n/a"
            let extra = "domain=\(nsError.domain) code=\(nsError.code) file=\(filePath)"
            let reflected = String(reflecting: error)
            self.loadError = "\(error.localizedDescription)\n\(extra)\nerror=\(reflected)"
            self.isLoaded = false
        }
    }
}
