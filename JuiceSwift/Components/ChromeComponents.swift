//
//  GradientHeaderBar.swift
//  JuiceSwift
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
		VStack(alignment: .leading) {
			backgroundView
            Text(title)
				.font(.system(size: 40, weight: .bold, design: .default))
				.foregroundStyle(.primary)
				.padding(.leading, 150)
				//.padding(5)
				.tracking(-2)
				//.frame(height: .infinity, alignment: .trailing)
        }
        //.frame(maxWidth: .infinity)
		.frame(
			minHeight: 40,
			maxHeight: 40,
			//alignment: .init(horizontal: .leading, vertical: .top)
		)
		//.padding(.bottom, 20)
		
//        .overlay(
//            Rectangle()
//                .fill(Color.black.opacity(0.12))
//                .frame(height: 1),
//            alignment: .bottom
//        )
		//.ignoresSafeArea(edges: .all)
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
			VStack(alignment: .leading, spacing: 6) {
				ForEach(NavigationItem.mainCases) { item in
					navItemButton(item)
				}
			}

			Spacer(minLength: 0)

			navItemButton(.settings)
		}
		.padding(16)
		.frame(minWidth: 220, idealWidth: 280, maxWidth: 350)
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
		let rowShape = RoundedRectangle(cornerRadius: 10, style: .continuous)
		#if os(macOS)
		let selectedForeground = Color(nsColor: .alternateSelectedControlTextColor)
		let selectedBackground = Color(nsColor: .controlAccentColor)
		let hoveredBackground = Color(nsColor: .controlColor).opacity(0.22)
		#else
		let selectedForeground = GlassThemeTokens.textPrimary(for: glassState)
		let selectedBackground = GlassThemeTokens.selectedChipFill(for: glassState)
		let hoveredBackground = GlassThemeTokens.overlayColor(for: glassState, role: .hover)
		#endif
		let hoverForeground = GlassThemeTokens.textPrimary(for: glassState).opacity(0.78)
		let iconForeground: Color = isSelected ? selectedForeground : (hoveredItem == item ? hoverForeground : .primary)
		let textForeground: Color = isSelected ? selectedForeground : (hoveredItem == item ? hoverForeground : .primary)
		Button {
			selection = item
		} label: {
			HStack(spacing: 10) {
				Image(systemName: item.systemImage)
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(iconForeground)
				Text(item.title)
					.font(.system(size: 14, weight: .regular))
					.foregroundStyle(textForeground)
				Spacer(minLength: 0)
			}
			.padding(.vertical, 10)
			.padding(.horizontal, 10)
			.background(
					rowShape
						.fill(
							isSelected
								? selectedBackground
								: (hoveredItem == item
									? hoveredBackground
									: .clear)
						)
				)
		}
		.buttonStyle(.plain)
		.onHover { hovering in
			hoveredItem = hovering ? item : (hoveredItem == item ? nil : hoveredItem)
		}
    }
}

#Preview {
    NavigationMenu(selection: .constant(.landing))
        .frame(width: 280)
}
//
//  SectionHeader.swift
//  JuiceSwift
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
