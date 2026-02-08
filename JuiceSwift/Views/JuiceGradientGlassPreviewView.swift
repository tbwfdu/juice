import SwiftUI

// Visual test harness for gradient/glass styling combinations.
// This view is preview-only and does not participate in normal navigation.
struct JuiceGradientGlassPreviewView: View {
    @State private var searchText: String = "Jamf Connect"
    @State private var selectedScope: Scope = .all
    @State private var includeBetaApps: Bool = true
    @State private var freshness: Double = 0.65

    var body: some View {
        ZStack {
			// Simulated desktop + window background treatment.
            JuiceGradientMaskedBackground()

            VStack(spacing: 20) {
				// Sample controls to inspect contrast and legibility.
                controlsCard
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                glassButton("Install", systemImage: "arrow.down.circle.fill")
                glassButton("Details", systemImage: "info.circle")
                glassClearButton("Skip")
            }

            HStack(spacing: 12) {
                TextField("Search catalog", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Picker("Scope", selection: $selectedScope) {
                    ForEach(Scope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            Toggle("Include beta apps", isOn: $includeBetaApps)

            VStack(alignment: .leading, spacing: 6) {
                Text("Freshness")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Slider(value: $freshness)
            }
        }
        .padding(18)
        .frame(maxWidth: 900)
        .frame(minHeight: 600)
        .background(cardBackground)
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if #available(macOS 26.0, iOS 26.0, *) {
            GlassEffectContainer {
                shape
                    .fill(Color.clear)
                    .glassEffect(.regular, in: shape)
            }
            .overlay {
                shape.strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func glassButton(_ title: String, systemImage: String) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            Button {
                // Preview-only action
            } label: {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.glass(.regular))
            .controlSize(.large)
        } else {
            Button {
                // Preview-only action
            } label: {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private func glassClearButton(_ title: String) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            Button(title) {
                // Preview-only action
            }
            .buttonStyle(.glass(.clear))
            .controlSize(.large)
        } else {
            Button(title) {
                // Preview-only action
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

private struct JuiceGradientMaskedBackground: View {
    var body: some View {
        JuiceGlassWordBackground(style: .v2, showsDesktopWallpaper: true)
    }
}

private enum Scope: String, CaseIterable, Identifiable {
    case all = "All"
    case recipes = "Recipes"
    case casks = "Casks"

    var id: String { rawValue }
}

#Preview("JUICE Glass Background - Light") {
    JuiceGradientGlassPreviewView()
        .preferredColorScheme(.light)
        .frame(width: 1000, height: 650)
}

#Preview("JUICE Glass Background - Dark") {
    JuiceGradientGlassPreviewView()
        .preferredColorScheme(.dark)
        .frame(width: 1000, height: 650)
}
