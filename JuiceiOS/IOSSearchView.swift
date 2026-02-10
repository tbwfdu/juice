import SwiftUI

struct IOSSearchView: View {
    @EnvironmentObject private var store: IOSCatalogStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let glassState = GlassStateContext(colorScheme: colorScheme, isFocused: true)
        ZStack {
            if store.isLoading {
                ProgressView("Loading catalog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.loadError {
                ContentUnavailableView("Catalog unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                List(store.filteredApps) { app in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.displayName)
                            .font(.headline)
                            .foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
                        Text(app.token)
                            .font(.caption)
                            .foregroundStyle(GlassThemeTokens.textSecondary(for: glassState))
                        if let desc = app.desc, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(GlassThemeTokens.textSecondary(for: glassState))
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .iosV2GlassRow(context: glassState, cornerRadius: 12)
                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
                .overlay {
                    if store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView("Search apps", systemImage: "magnifyingglass", description: Text("Type an app name or token."))
                    }
                }
            }
        }
        .navigationTitle("Search")
        .padding(.horizontal, 10)
        .iosV2GlassPanel(context: glassState, cornerRadius: 16)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .searchable(text: $store.query, prompt: "Search apps")
        .task {
            await store.loadIfNeeded()
        }
    }
}
