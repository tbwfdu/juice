import SwiftUI

enum IOSTabSelection: Hashable {
    case landing
    case search
    case updates
}

struct IOSLandingView: View {
    @EnvironmentObject private var store: IOSCatalogStore
    @Environment(\.colorScheme) private var colorScheme
    let onShowSearch: () -> Void
    let onShowUpdates: () -> Void

    private var glassState: GlassStateContext {
        GlassStateContext(colorScheme: colorScheme, isFocused: true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroSection
                statsSection
                quickActionsSection
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Juice")
        .task {
            await store.loadIfNeeded()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Juice")
                .font(.system(size: 54, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient.juice)
            Text("Application discovery for Workspace ONE")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
            Text("Search apps and review available updates. Download, upload, and import are intentionally disabled on iOS.")
                .font(.subheadline)
                .foregroundStyle(GlassThemeTokens.textSecondary(for: glassState))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .iosV2GlassPanel(context: glassState, cornerRadius: 20)
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Catalog Apps",
                value: "\(store.apps.count)",
                symbol: "square.stack.3d.up.fill"
            )
            statCard(
                title: "Available Updates",
                value: "\(store.availableUpdates.count)",
                symbol: "arrow.triangle.2.circlepath.circle.fill"
            )
        }
    }

    private func statCard(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LinearGradient.juice)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(GlassThemeTokens.textSecondary(for: glassState))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .iosV2GlassRow(context: glassState, cornerRadius: 14)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))

            Button {
                onShowSearch()
            } label: {
                actionRow(
                    icon: "magnifyingglass",
                    title: "Search Applications",
                    subtitle: "Look up catalog apps by name, token, or description"
                )
            }
            .buttonStyle(.plain)

            Button {
                onShowUpdates()
            } label: {
                actionRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "View Available Updates",
                    subtitle: "See tracked apps with newer versions in the catalog"
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .iosV2GlassPanel(context: glassState, cornerRadius: 16)
    }

    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LinearGradient.juice)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GlassThemeTokens.textPrimary(for: glassState))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(GlassThemeTokens.textSecondary(for: glassState))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GlassThemeTokens.textSecondary(for: glassState))
        }
        .padding(12)
        .iosV2GlassRow(context: glassState, cornerRadius: 12)
    }
}
