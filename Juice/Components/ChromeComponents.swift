//
//  GradientHeaderBar.swift
//  Juice
//
//  Created by Pete Lindley on 25/1/2026.
//
import SwiftUI

// Consolidated top-level app chrome primitives.
// Used by: ContentView and primary page views.


struct GradientHeaderBar: View {
	enum BackgroundStyle {
		case gradient
		case clear
	}

    var title: String = "Juice"
	var backgroundStyle: BackgroundStyle = .gradient

	var body: some View {
		ZStack {
			backgroundView
			if title == "Juice" {
				HStack(spacing: -2) {
					ForEach(Array(title), id: \.self) { character in
						Text(String(character))
					}
				}
				.font(.system(size: 40, weight: .bold, design: .default))
				.fixedSize(horizontal: true, vertical: false)
				.foregroundStyle(.primary)
			} else {
				Text(title)
					.font(.system(size: 40, weight: .bold, design: .default))
					.foregroundStyle(.primary)
					.tracking(-2)
			}
        }
		.padding(.top, 10)
		.frame(maxWidth: .infinity, alignment: .center)
		.frame(
			minHeight: 40,
			maxHeight: 40,
		)
    }

	@ViewBuilder
	private var backgroundView: some View {
		switch backgroundStyle {
		case .gradient:
			LinearGradient.juice
		case .clear:
			Color.clear
		}
	}
}

#Preview("GradientHeaderBar - Gradient") {
    GradientHeaderBar(title: "Juice", backgroundStyle: .gradient)
}

#Preview("GradientHeaderBar - Clear") {
    GradientHeaderBar(title: "Juice", backgroundStyle: .clear)
}

struct NavigationMenu: View {
    @Binding var selection: NavigationItem?
	let onCollapse: (() -> Void)?
	let panelWidth: CGFloat?
    @State private var hoveredItem: NavigationItem?
	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var focusObserver = WindowFocusObserver()

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
	}

	    var body: some View {
		let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		return VStack(spacing: 0) {
			VStack(alignment: .leading, spacing: 3) {
				ForEach(NavigationItem.mainCases) { item in
					navItemButton(item)
				}
			}

			Spacer(minLength: 0)

			navItemButton(.settings)
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 16)
		.padding(.top, 24)
		.frame(width: panelWidth, alignment: .leading)
		.frame(
			minWidth: panelWidth == nil ? 220 : nil,
			idealWidth: panelWidth == nil ? 280 : nil,
			maxWidth: panelWidth == nil ? 350 : nil
		)
		.frame(maxHeight: .infinity, alignment: .top)
		.background {
			Color.clear
				.glassCompatSurface(
					in: shape,
					style: .regular,
					context: glassState,
					fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
					fillOpacity: 0.40,
					surfaceOpacity: 0.90
				)
			}
			.clipShape(shape)
			.glassCompatBorder(in: shape, context: glassState, role: .standard)
				.overlay(alignment: .topTrailing) {
					if let onCollapse {
						let collapseIcon = resolvedSymbolName(
							preferred: "chevron.left.2",
							fallback: "sidebar.left"
						)
						Button(action: onCollapse) {
							Image(systemName: collapseIcon)
								.font(.system(size: 14, weight: .regular))
								.frame(width: 28, height: 22)
								.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
					.juiceHelp(HelpText.Actions.collapse)
					.padding(.top, 8)
					.padding(.trailing, 8)
				}
			}
			.overlay(
				ZStack {
					RadialGradient(
						colors: [GlassThemeTokens.textPrimary(for: glassState).opacity(0.35), .clear],
						center: .topLeading,
						startRadius: 0,
						endRadius: 10
					)
					RadialGradient(
						colors: [GlassThemeTokens.textPrimary(for: glassState).opacity(0.26), .clear],
						center: .bottomTrailing,
						startRadius: 0,
						endRadius: 10
					)
				}
				.clipShape(shape)
				.blendMode(.screen)
				.allowsHitTesting(false)
			)
			.glassCompatShadow(context: glassState, elevation: .panel)
			.background(WindowFocusReader { focusObserver.attach($0) })
		}

	@ViewBuilder
	private func navItemButton(_ item: NavigationItem) -> some View {
		let isSelected = selection == item
		let rowShape = RoundedRectangle(cornerRadius: 7, style: .continuous)
		let useGradientSelection = isSelected
		#if os(macOS)
		let selectedForeground = Color(nsColor: .alternateSelectedControlTextColor)
		let selectedGlassTint = colorScheme == .light
			? Color(nsColor: .controlBackgroundColor).opacity(0.78)
			: Color(nsColor: .windowBackgroundColor).opacity(0.82)
		#else
		let selectedForeground = GlassThemeTokens.textPrimary(for: glassState)
		let selectedBackground = GlassThemeTokens.selectedChipFill(for: glassState)
		#endif
		let hoveredBackground = GlassThemeTokens.navHoverRowFill(for: glassState)
		let hoverForeground = GlassThemeTokens.textPrimary(for: glassState).opacity(0.78)
		let iconForeground: Color = isSelected ? selectedForeground : (hoveredItem == item ? hoverForeground : .primary)
		let textForeground: Color = isSelected ? selectedForeground : (hoveredItem == item ? hoverForeground : .primary)
		Button {
			selection = item
		} label: {
			HStack(spacing: 7) {
				Image(systemName: item.systemImage)
					.font(.system(size: 13, weight: .regular))
					.foregroundStyle(useGradientSelection ? AnyShapeStyle(RadialGradient.navSelection) : AnyShapeStyle(iconForeground))
				Text(item.title)
					.font(.system(size: 12, weight: .regular))
					.foregroundStyle(useGradientSelection ? AnyShapeStyle(RadialGradient.navSelection) : AnyShapeStyle(textForeground))
				Spacer(minLength: 0)
			}
			.padding(.vertical, 7)
			.padding(.horizontal, 6)
			.background(
				ZStack {
					#if os(macOS)
					if isSelected {
						rowShape.fill(.thinMaterial)
						rowShape.fill(selectedGlassTint)
					} else if hoveredItem == item {
						rowShape.fill(hoveredBackground)
					}
					#else
					rowShape
						.fill(
							isSelected
								? selectedBackground
								: (hoveredItem == item
									? hoveredBackground
									: .clear)
						)
					#endif
				}
				)
		}
		.buttonStyle(.plain)
		.onHover { hovering in
			hoveredItem = hovering ? item : (hoveredItem == item ? nil : hoveredItem)
		}
    }
}

#Preview {
	NavigationMenu(selection: .constant(.landing), onCollapse: nil, panelWidth: nil)
        .frame(width: 280)
}
//
//  SectionHeader.swift
//  Juice
//
//  Created by Pete Lindley on 25/1/2026.
//

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                //.font(.system(size: 24, weight: .semibold))
				.font(.largeTitle.weight(.semibold))
            if let subtitle {
                Text(subtitle)
					.font(.body)
					.foregroundStyle(.primary)
            }
        }
    }
}
