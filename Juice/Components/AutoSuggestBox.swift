//
//  AutoSuggestBox.swift
//  Juice
//
//  Created by Pete Lindley on 25/1/2026.
//


import SwiftUI

struct AutoSuggestBox<T: Identifiable, ItemView: View>: View {
	@Binding var text: String
	var suggestions: [T]
	var onSuggestionClick: (T) -> Void
	var onCommit: () -> Void
	var isFocused: FocusState<Bool>.Binding
	@State private var isEditing = false
	@State private var isHovered = false
	
	@ViewBuilder var itemViewBuilder: (T) -> ItemView
	
	var body: some View {
		VStack(spacing: 0) {
			let isActive = isEditing && isFocused.wrappedValue
			let shape = RoundedRectangle(cornerRadius: isActive ? 20 : 14, style: .continuous)
			let inputVerticalPadding: CGFloat = 5
			let containerVerticalPadding: CGFloat = 8
			// Input Field
			HStack {
				Image(systemName: "magnifyingglass")
					.foregroundStyle(.secondary)
					.font(.system(size: 14, weight: .semibold))
					.scaleEffect(isActive ? 1.15 : 1.0)
					.animation(.easeInOut(duration: 0.2), value: isActive)
				TextField(
					"eg. 'Omnissa Horizon Client'",
					text: $text,
					onEditingChanged: { editing in
						isEditing = editing
					},
					onCommit: {
						onCommit()
					}
				)
					.font(.system(size: 14, weight: .regular))
					.textFieldStyle(.plain)
					.padding(.vertical, inputVerticalPadding)
					.padding(.horizontal, 12)
					.frame(height: 22, alignment: .center)
					.frame(maxWidth: .infinity, alignment: .leading)
					.focused(isFocused)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, 12)
			.padding(.vertical, containerVerticalPadding)
			.background {
				if #available(macOS 26.0, iOS 26.0, *) {
					shape
						.fill(Color.clear)
						.glassEffect(.regular, in: shape)
				} else {
					shape.fill(.ultraThinMaterial)
				}
			}
			.overlay {
				shape.strokeBorder(Color.white.opacity(isActive ? 0.18 : (isHovered ? 0.2 : 0.08)))
			}
			.overlay {
				if isHovered && !isActive {
					shape
						.fill(Color.white.opacity(0.04))
				}
			}
			.shadow(
				color: Color.black.opacity(isActive ? 0.08 : 0.0),
				radius: isActive ? 5 : 0,
				x: 0,
				y: isActive ? 3 : 0
			)
			.opacity(isActive ? 1 : 0.6)
			.scaleEffect(isHovered && !isActive ? 1.01 : 1)
			.animation(.easeInOut(duration: 0.2), value: isActive)
			.contentShape(shape)
			.onTapGesture {
				isFocused.wrappedValue = true
			}
			.onHover { hovering in
				isHovered = hovering
			}
			.animation(.easeInOut(duration: 0.15), value: isHovered)
			.onChange(of: isFocused.wrappedValue) { _, focused in
				if !focused {
					isEditing = false
				}
			}
			.anchorPreference(key: AutoSuggestAnchorKey.self, value: .bounds) { $0 }
		}
	}
}
