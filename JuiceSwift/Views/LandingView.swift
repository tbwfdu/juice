import SwiftUI

// Landing page / dashboard summary.
// Shows high-level catalog counts and branding.
struct LandingView: View {
    let model: PageViewData
    @EnvironmentObject private var catalog: LocalCatalog

    @State private var alertVisible: Bool = false

    private func showAlert() {
        alertVisible = true
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
				// Brand header block.
                header
					.padding(.top, -150)
//                ScrollView {
				// Quick stats strip.
                    HStack(spacing: 24) {
                        StatCard(title: "Apps", value: "\(catalog.caskApps.count)")
                        StatCard(title: "Recipes", value: "\(catalog.recipes.count)")
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                //}
                #if DEBUG
                if let loadError = catalog.loadError {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Catalog load error: \(loadError)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                #endif
            }
        }
        .contentMargins(0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                Text("Juice")
                    .font(
						.system(size: 96, weight: .bold)
                    )
					.tracking(-4.5)
                    .foregroundStyle(.primary)
                Image("JuiceLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120).padding(.bottom, 10)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 6)
                .padding(.bottom, 5)
            }
            Text("macOS Application Discovery and Upload Tool for Workspace ONE UEM")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .tracking(-0.5)
        }
        .padding(.top, 40)
        .padding(.bottom, 3)
        .frame(maxWidth: 450)
        .frame(height: 240, alignment: .top)
    }
}





#Preview {
    LandingView(model: .sample)
        .environmentObject(LocalCatalog())
        .frame(width: 900, height: 600)
}
