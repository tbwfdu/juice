import SwiftUI

// Reusable segmented control with liquid-glass styling.
// Supports icon + title per segment and binds selection like a Picker.
struct LiquidGlassSegmentedPicker<Tag: Hashable>: View {
	// MARK: - Item

	struct Item: Identifiable {
		let id = UUID()
		let title: String
		let icon: String
		let tag: Tag
		let isEnabled: Bool

		init(
			title: String,
			icon: String,
			tag: Tag,
			isEnabled: Bool = true
		) {
			self.title = title
			self.icon = icon
			self.tag = tag
			self.isEnabled = isEnabled
		}
	}

	// MARK: - Inputs

	let items: [Item]
	@Binding var selection: Tag
	var horizontalPadding: CGFloat = 6
	var verticalPadding: CGFloat = 6

	// MARK: - Environment

	@Environment(\.colorScheme) private var colorScheme
	#if os(macOS)
		@Environment(\.controlActiveState) private var controlActiveState
	#endif

	// MARK: - State

	@State private var hoveredTag: Tag?
	@State private var pressedTag: Tag?
	@State private var morphIntensity: CGFloat = 0
	@State private var morphingTag: Tag?
	@State private var morphTask: Task<Void, Never>?

	private let segmentPadding = EdgeInsets(
		top: 9,
		leading: 12,
		bottom: 9,
		trailing: 12
	)
	private let segmentSpacing: CGFloat = 16
	private let segmentOuterPadding = EdgeInsets(
		top: 1,
		leading: 2,
		bottom: 1,
		trailing: 2
	)

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: isWindowActive
		)
	}

	private var isWindowActive: Bool {
		#if os(macOS)
			return controlActiveState == .active
		#else
			return true
		#endif
	}

	// MARK: - Body

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 25, style: .continuous)
		HStack(spacing: segmentSpacing) {
			ForEach(items) { item in
				segmentButton(for: item)
			}
		}
		.fixedSize(horizontal: true, vertical: false)
		.padding(.horizontal, horizontalPadding)
		.padding(.vertical, verticalPadding)
		.background { segmentedBackground(shape: shape) }
		.clipShape(shape)
		.glassCompatBorder(
			in: shape,
			context: glassState,
			role: .standard,
			lineWidth: 1
		)
		.glassCompatShadow(context: glassState, elevation: .small)
		.onChange(of: selection) { oldValue, newValue in
			triggerMorph(from: oldValue, to: newValue)
		}
		.animation(
			.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.28),
			value: selection
		)
	}

	// MARK: - Segments

	private func segmentButton(for item: Item) -> some View {
		let isSelected = selection == item.tag
		let isHovered = hoveredTag == item.tag
		let isPressed = pressedTag == item.tag
		let isMorphing = morphingTag == item.tag
		let textOpacity: CGFloat =
			item.isEnabled ? (isSelected ? 0.95 : 0.8) : 0.35
		let backgroundOpacity: CGFloat = isPressed ? 1 : (isHovered ? 0.7 : 0)
		let hoverRole: GlassOverlayRole = isPressed ? .pressed : .hover

		return Button {
			guard item.isEnabled else { return }
			selection = item.tag
		} label: {
			if isSelected {
				HStack(spacing: 6) {
					Image(systemName: item.icon)
						.font(.system(size: 13, weight: .regular))
					Text(item.title)
						.font(.system(.callout, weight: .regular))
				}
				.padding(segmentPadding)
				.contentShape(Rectangle())
			} else {
				HStack(spacing: 6) {
					Image(systemName: item.icon)
						.font(.system(size: 13, weight: .regular))
					Text(item.title)
						.font(.system(.callout, weight: .regular))
				}
				.foregroundStyle(
					GlassThemeTokens.textPrimary(for: glassState).opacity(
						textOpacity
					)
				)
				.padding(segmentPadding)
				.contentShape(Rectangle())
			}
		}
		.modifier(ProminentSegmentButtonStyle())
		.tint(isSelected ? .accentColor : .clear)
		.disabled(!item.isEnabled)
		.background {
			if !isSelected && backgroundOpacity > 0 {
				Capsule(style: .continuous)
					.fill(
						GlassThemeTokens.overlayColor(
							for: glassState,
							role: hoverRole
						)
					)
					.opacity(backgroundOpacity)
			}
		}
		.frame(minHeight: 38, alignment: .center)
		.padding(segmentOuterPadding)
		.scaleEffect(
			isSelected
				? (1 + (isMorphing ? 0.045 * morphIntensity : 0))
				: 1,
			anchor: .center
		)
		.blur(radius: isMorphing ? max(0, (1 - morphIntensity) * 0.6) : 0)
		.animation(
			.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.24),
			value: morphIntensity
		)
		.zIndex(isSelected ? 1 : 0)
		.onHover { hovering in
			hoveredTag =
				hovering
				? item.tag : (hoveredTag == item.tag ? nil : hoveredTag)
		}
		.onLongPressGesture(
			minimumDuration: 0.01,
			maximumDistance: 12,
			pressing: { pressing in
				pressedTag =
					pressing
					? item.tag : (pressedTag == item.tag ? nil : pressedTag)
			},
			perform: {}
		)
	}

	private struct ProminentSegmentButtonStyle: ViewModifier {
		func body(content: Content) -> some View {
			if #available(macOS 26.0, iOS 26.0, *) {
				content
					.buttonStyle(.glassProminent)
					.buttonBorderShape(.capsule)
					.controlSize(.small)
			} else {
				content
					.buttonStyle(.borderedProminent)
					.buttonBorderShape(.capsule)
					.controlSize(.small)
			}
		}
	}

	@ViewBuilder
	private func segmentedBackground(shape: RoundedRectangle) -> some View {
		if #available(macOS 26.0, iOS 26.0, *) {
			ZStack {
				GlassEffectContainer {
					shape
						.fill(.clear)
						.glassEffect(.clear, in: shape)
				}
				shape
					.fill(
						GlassThemeTokens.controlBackgroundBase(for: glassState)
					)
					.opacity(
						Double(
							min(
								1,
								GlassThemeTokens.panelBaseTintOpacity(
									for: glassState
								)
									+ GlassThemeTokens
									.panelNeutralOverlayOpacity(for: glassState)
							)
						)
					)
			}
			.opacity(
				Double(GlassThemeTokens.panelSurfaceOpacity(for: glassState))
			)
		} else {
			Color.clear
				.glassCompatSurface(
					in: shape,
					style: .regular,
					context: glassState,
					fillColor: GlassThemeTokens.controlBackgroundBase(
						for: glassState
					),
					fillOpacity: min(
						1,
						GlassThemeTokens.panelBaseTintOpacity(for: glassState)
							+ GlassThemeTokens.panelNeutralOverlayOpacity(
								for: glassState
							)
					),
					surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(
						for: glassState
					)
				)
		}
	}

	private func triggerMorph(from oldValue: Tag, to newValue: Tag) {
		guard oldValue != newValue else { return }
		morphTask?.cancel()
		morphTask = Task { @MainActor in
			morphingTag = newValue
			morphIntensity = 0
			withAnimation(.spring(response: 0.22, dampingFraction: 0.66)) {
				morphIntensity = 1
			}
			try? await Task.sleep(nanoseconds: 170_000_000)
			if !Task.isCancelled {
				withAnimation(
					.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.22)
				) {
					morphIntensity = 0
				}
				try? await Task.sleep(nanoseconds: 220_000_000)
				if !Task.isCancelled {
					morphingTag = nil
				}
			}
		}
	}
}

#Preview("LiquidGlassSegmentedPicker") {
	enum SampleTab: Hashable {
		case queue
		case results
		case history
	}

	@Previewable @State var selection: SampleTab = .queue

	let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

	return VStack(spacing: 16) {
		HStack {
			Spacer()
			LiquidGlassSegmentedPicker(
				items: [
					.init(title: "Queue", icon: "tray.full", tag: .queue),
					.init(
						title: "Results",
						icon: "checkmark.circle",
						tag: .results
					),
					.init(
						title: "History",
						icon: "clock.arrow.circlepath",
						tag: .history
					),
				],
				selection: $selection
			)
			Spacer()
		}
		Text("Selected: \(String(describing: selection))")
			.font(.system(size: 12, weight: .regular))
			.foregroundStyle(.secondary)
	}.frame(width: 400, height: 200)
		.background {
			if #available(macOS 26.0, *) {
				shape
					.fill(Color.clear)
					.glassEffect(.regular, in: shape)
					.padding(20)
			} else {
				// Fallback on earlier versions
			}
		}
		.background(JuiceGradient())
}
