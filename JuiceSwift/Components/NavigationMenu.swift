import SwiftUI

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
                    .onHover { hovering in
                        hoveredItem = hovering ? item : (hoveredItem == item ? nil : hoveredItem)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
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
                .onHover { hovering in
                    hoveredItem = hovering ? .settings : (hoveredItem == .settings ? nil : hoveredItem)
                }
            }
            .listStyle(.sidebar)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .frame(height: 60)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 280)
		.background(.ultraThinMaterial)
        .environment(\.controlActiveState, .active)
        //.background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    NavigationMenu(selection: .constant(.landing))
        .frame(width: 280)
}
