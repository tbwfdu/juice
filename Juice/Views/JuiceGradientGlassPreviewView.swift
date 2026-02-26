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
	@Namespace var controls
	@State private var isLiked: Bool = false
	
	enum Tab: Hashable { case queue, results }

	@State private var selectedTab: Tab = .queue
	
	private var controlsCard: some View {
		VStack(alignment: .leading, spacing: 16) {

			if #available(macOS 26.0, *) {
				GlassEffectContainer {
					


					LiquidGlassSegmentedPicker(
						items: [
							.init(title: "Queue", icon: "tray.full", tag: .queue),
							.init(title: "Results", icon: "checkmark.circle", tag: .results)
						],
						selection: $selectedTab
					)
				
					Picker("Scope", selection: $selectedScope) {
						Label("1", systemImage: "square.fill")
						Label("2", systemImage: "square.fill")
						Label("3", systemImage: "square.fill")
					}
					.labelsHidden()
					.background(.clear)
					.controlSize(.extraLarge)
					.glassEffect(.clear)
					.pickerStyle(.segmented)
					.frame(width: 220)

					//					HStack(spacing: 0) {
					//						Button("Edit") {}
					//							.buttonStyle(.glass(.clear))
					//							.controlSize(ControlSize.extraLarge)
					//							.glassEffectUnion(id: "tools", namespace: controls)
					//
					//						Button("Delete") {}
					//							.buttonStyle(.glass(.clear))
					//							.controlSize(ControlSize.extraLarge)
					//							.glassEffectUnion(id: "tools", namespace: controls)
					//					}
				}
				.frame(width: 300)
			} else {

			}
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
					.background(
						.ultraThinMaterial,
						in: RoundedRectangle(
							cornerRadius: 12,
							style: .continuous
						)
					)

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
	private func glassButton(_ title: String, systemImage: String) -> some View
	{
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

	fileprivate struct FloatingActionCluster: View {
		@State private var isExpanded = false
		@Namespace private var namespace

		let actions = [
			("home", Color.purple),
			("pencil", Color.blue),
			("message", Color.green),
			("envelope", Color.orange),
		]

		var body: some View {
			ZStack {
				VStack {
					Spacer()
					HStack {
						Spacer()
						cluster
							.padding()
					}
				}
			}
		}

		var cluster: some View {
			Group {
				if #available(macOS 26.0, *) {
					GlassEffectContainer(spacing: 20) {
						VStack(spacing: 12) {
							if isExpanded {
								ForEach(actions, id: \.0) { action in
									actionButton(action.0, color: action.1)
										.glassEffectID(action.0, in: namespace)
								}
							}

							Button {
								withAnimation(.bouncy(duration: 0.4)) {
									isExpanded.toggle()
								}
							} label: {
								Image(systemName: isExpanded ? "xmark" : "plus")
									.font(.title2.bold())
									.frame(width: 56, height: 56)
							}
							.buttonStyle(.glassProminent)
							.buttonBorderShape(.circle)
							.tint(.blue)
							.glassEffectID("toggle", in: namespace)
						}
					}
				} else {
					EmptyView()
				}
			}
		}

		func actionButton(_ icon: String, color: Color) -> some View {
			Group {
				if #available(macOS 26.0, *) {
					Button {
						// action
					} label: {
						Image(systemName: icon)
							.font(.title3)
							.frame(width: 48, height: 48)
					}
					.buttonStyle(.glass)
					.buttonBorderShape(.circle)
					.tint(color)
				} else {
					Button {
						// action
					} label: {
						Image(systemName: icon)
							.font(.title3)
							.frame(width: 48, height: 48)
					}
					.buttonStyle(.bordered)
					.buttonBorderShape(.circle)
					.tint(color)
				}
			}
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
	var icon: String {
		switch self {
		case .all: return "apple.logo"
		case .recipes: return "book.fill"
		case .casks: return "flask.fill"
		}
	}
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

