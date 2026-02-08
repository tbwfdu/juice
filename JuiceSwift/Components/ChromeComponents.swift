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

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(NavigationItem.mainCases) { item in
                    Button {
                        selection = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.systemImage)
								.font(.system(size: 16, weight: .regular))
                            Text(item.title)
								.font(.system(size: 14, weight: .regular))
                            Spacer(minLength: 0)
//                            if item == .updates && updatesCount > 0 {
//                                Text("\(updatesCount)")
//                                    .font(.system(size: 11, weight: .bold))
//                                    .foregroundStyle(.white)
//                                    .padding(.vertical, 2)
//                                    .padding(.horizontal, 6)
//                                    .background(
//                                        Capsule().fill(Color.red)
//                                    )
//                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .foregroundStyle(
                            selection == item
                            ? Color(nsColor: .alternateSelectedControlTextColor)
                            : Color.primary
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    selection == item
                                    ? Color(nsColor: .controlAccentColor).opacity(1)
                                    : (hoveredItem == item ? Color(nsColor: .controlColor).opacity(0.35) : Color.clear)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .onHover { hovering in
                        hoveredItem = hovering ? item : (hoveredItem == item ? nil : hoveredItem)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .tint(Color(nsColor: .controlAccentColor))

            Spacer(minLength: 0)

            List {
                Button {
                    selection = .settings
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: NavigationItem.settings.systemImage)
                            .font(.system(size: 16, weight: .regular))
                        Text(NavigationItem.settings.title)
							.font(.system(size: 14, weight: .regular))
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .foregroundStyle(
                        selection == .settings
                        ? Color(nsColor: .alternateSelectedControlTextColor)
                        : Color.primary
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                selection == .settings
                                ? Color(nsColor: .controlAccentColor).opacity(0.35)
                                : (hoveredItem == .settings ? Color(nsColor: .controlColor).opacity(0.35) : Color.clear)
                            )
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .onHover { hovering in
                    hoveredItem = hovering ? .settings : (hoveredItem == .settings ? nil : hoveredItem)
                }
            }
            .listStyle(.sidebar)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(height: 60)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 220)
		.background {
			Color.clear
		}
        .environment(\.controlActiveState, .active)
        //.background(Color(nsColor: .windowBackgroundColor))
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
