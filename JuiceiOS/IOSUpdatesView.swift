import SwiftUI

struct IOSUpdatesView: View {
    @EnvironmentObject private var store: IOSCatalogStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let glassState = GlassStateContext(colorScheme: colorScheme, isFocused: true)
        ZStack {
            if store.isLoading {
                ProgressView("Loading updates…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.loadError {
                ContentUnavailableView("Updates unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if store.availableUpdates.isEmpty {
                ContentUnavailableView("No available updates", systemImage: "checkmark.circle", description: Text("No newer catalog versions were found for tracked apps."))
            } else {
                List(store.availableUpdates) { update in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(update.app.displayName)
                            .font(.headline)
                            .foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
                        Text(update.app.token)
                            .font(.caption)
                            .foregroundStyle(GlassThemeTokens.textSecondary(for: glassState))
                        HStack(spacing: 8) {
                            Text("Installed: \(update.installedVersion)")
                                .font(.subheadline)
                                .foregroundStyle(GlassThemeTokens.textSecondary(for: glassState))
                            Text("→")
                                .foregroundStyle(.tertiary)
                            Text("Available: \(latestVersion(update.app))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
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
            }
        }
        .navigationTitle("Updates")
        .padding(.horizontal, 10)
        .iosV2GlassPanel(context: glassState, cornerRadius: 16)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task {
            await store.loadIfNeeded()
        }
    }

    private func latestVersion(_ app: IOSCaskApp) -> String {
        (app.version ?? "")
            .split(separator: ",")
            .first
            .map(String.init) ?? "Unknown"
    }
}
