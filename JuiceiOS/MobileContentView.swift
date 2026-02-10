import SwiftUI

struct MobileContentView: View {
    @StateObject private var store = IOSCatalogStore()
    @State private var selection: IOSTabSelection = .landing

    var body: some View {
        ZStack {
            IOSV2GlassStyle.windowGradient
                .ignoresSafeArea()

            TabView(selection: $selection) {
                NavigationStack {
                    IOSLandingView(
                        onShowSearch: { selection = .search },
                        onShowUpdates: { selection = .updates }
                    )
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(IOSTabSelection.landing)

                NavigationStack {
                    IOSSearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(IOSTabSelection.search)

                NavigationStack {
                    IOSUpdatesView()
                }
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(IOSTabSelection.updates)
            }
            .background(.clear)
        }
        .environmentObject(store)
    }
}

#Preview {
    MobileContentView()
}
