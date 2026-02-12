import SwiftUI

#if os(macOS)
	import AppKit
#endif

// Consolidated queue/results inspector panel components.
// Used by: SearchView, UpdatesView, ImportView, DownloadQueuePanelContent.

private struct QueuePinnedGlassSection<Content: View>: View {
	let corners: CustomRoundedCorners.Corner
	var cornerRadius: CGFloat = 20
	var showsBorder: Bool = true
	@ViewBuilder let content: () -> Content

	var body: some View {
		let shape = CustomRoundedCorners(radius: cornerRadius, corners: corners)
		if #available(macOS 26.0, iOS 16.0, *) {
			content()
				.background {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
				}
				.overlay {
					if showsBorder {
						shape.strokeBorder(.white.opacity(0.15))
					}
				}
				.clipShape(shape)
		} else {
			content()
				.background(
					shape
						.fill(.ultraThinMaterial)
						.overlay {
							if showsBorder {
								shape.strokeBorder(.white.opacity(0.15))
							}
						}
				)
				.clipShape(shape)
		}
	}
}

private struct QueuePanelHeaderHeightKey: PreferenceKey {
	static let defaultValue: CGFloat = 0
	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		let next = nextValue()
		if next > 0 {
			value = next
		}
	}
}

private struct QueuePanelBottomBarHeightKey: PreferenceKey {
	static let defaultValue: CGFloat = 0
	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		value = nextValue()
	}
}

struct QueuePanelContent<QueueContent: View, ResultsContent: View>: View {
	// MARK: - Inputs & State

	@Environment(\.colorScheme) private var colorScheme
	enum Tab: Hashable {
		case queue
		case results
	}

	struct Notice: Equatable {
		let message: String
		let isDuplicate: Bool
	}

	@Binding var tab: Tab
	@Binding var notice: Notice?
	let queueTitle: String
	let resultsTitle: String
	let queueCountText: String
	let resultsCountText: String
	let queueIsEmpty: Bool
	var resultsIsEmpty: Bool
	let queueActionTitle: String
	let resultsActionTitle: String
	let onQueueAction: () -> Void
	let onResultsAction: () -> Void
	let isPinned: Binding<Bool>?
	let bottomActions: AnyView?
	let queueContent: () -> QueueContent
	let resultsContent: () -> ResultsContent
	@State private var noticeTask: Task<Void, Never>?
	@State private var displayNotice: Notice?
	@State private var isDismissingNotice = false
	@State private var previousTab: Tab = .queue
	@State private var panelHeaderHeight: CGFloat = 0
	private let noticeText = "Added!"
	// Temporary override so the Results tab can be tested even when empty.
	private let enableResultsTabWhenEmpty = true
	private var panelState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: focusObserver.isFocused
		)
	}
	private var panelGlassOpacity: CGFloat {
		GlassThemeTokens.panelSurfaceOpacity(for: panelState)
	}
	private var panelGlassBaseOpacity: CGFloat {
		GlassThemeTokens.panelBaseTintOpacity(for: panelState)
	}
	@StateObject private var focusObserver = WindowFocusObserver()

	init(
		tab: Binding<Tab>,
		notice: Binding<Notice?> = .constant(nil),
		queueTitle: String,
		resultsTitle: String,
		queueCountText: String,
		resultsCountText: String,
		queueIsEmpty: Bool,
		resultsIsEmpty: Bool,
		queueActionTitle: String = "Remove All",
		resultsActionTitle: String = "Clear",
		onQueueAction: @escaping () -> Void = {},
		onResultsAction: @escaping () -> Void = {},
		isPinned: Binding<Bool>? = nil,
		bottomActions: AnyView? = nil,
		@ViewBuilder queueContent: @escaping () -> QueueContent,
		@ViewBuilder resultsContent: @escaping () -> ResultsContent
	) {
		self._tab = tab
		self._notice = notice
		self.queueTitle = queueTitle
		self.resultsTitle = resultsTitle
		self.queueCountText = queueCountText
		self.resultsCountText = resultsCountText
		self.queueIsEmpty = queueIsEmpty
		self.resultsIsEmpty = resultsIsEmpty
		self.queueActionTitle = queueActionTitle
		self.resultsActionTitle = resultsActionTitle
		self.onQueueAction = onQueueAction
		self.onResultsAction = onResultsAction
		self.isPinned = isPinned
		self.bottomActions = bottomActions
		self.queueContent = queueContent
		self.resultsContent = resultsContent

	}

	// MARK: - Body

	var body: some View {
		let resultsTabEnabled = enableResultsTabWhenEmpty || !resultsIsEmpty
		ZStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 12) {
				#if os(macOS)
				#else
					Picker("", selection: $tab) {
						Text("Queue").tag(Tab.queue)
						Text("Results").tag(Tab.results).disabled(
							!resultsTabEnabled
						)
					}
					.pickerStyle(.segmented)
					.tint(.secondary)
					.labelsHidden()
				#endif

				// Shared panel chrome; tab switch swaps inner queue/results content only.
				panelContainer {
					ZStack {
						if tab == .queue {
							panelContent(
								title: queueTitle,
								countText: queueCountText,
								actionTitle: queueActionTitle,
								action: onQueueAction,
								bottomActions: bottomActions,
								content: queueContent,
								isActionDisabled: queueIsEmpty
							)
							.transition(tabTransition(for: .queue))
						} else {
							panelContent(
								title: resultsTitle,
								countText: resultsCountText,
								actionTitle: resultsActionTitle,
								action: onResultsAction,
								bottomActions: nil,
								content: resultsContent,
								isActionDisabled: resultsIsEmpty
							)
							.transition(tabTransition(for: .results))
						}
					}
					.animation(.easeInOut(duration: 0.12), value: tab)
				}
			}

			if tab == .queue, let notice = displayNotice {
				HStack(spacing: 8) {
					Image(
						systemName: notice.isDuplicate
							? "exclamationmark.triangle.fill"
							: "checkmark.circle.fill"
					)
					.foregroundStyle(
						notice.isDuplicate ? Color.orange : Color.green
					)
					.font(.system(size: 14, weight: .bold))
					BouncingNoticeText(text: noticeText)
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
				.background(
					notificationBackground
				)
				.scaleEffect(isDismissingNotice ? 1.06 : 1, anchor: .center)
				.blur(radius: isDismissingNotice ? 10 : 0)
				.opacity(isDismissingNotice ? 0 : 1)
				.frame(maxWidth: .infinity, alignment: .center)
				.transition(MacNotificationAnimation.transition)
				.transaction {
					$0.animation = MacNotificationAnimation.animation
				}
				.allowsHitTesting(false)
			}
		}
		.background(WindowFocusReader { focusObserver.attach($0) })
		.onAppearUnlessPreview {
			displayNotice = notice
			if let notice {
				scheduleNoticeDismiss(for: notice)
			}
		}
		.onChange(of: tab) { oldValue, _ in
			previousTab = oldValue
		}
		.onChange(of: notice) { _, newNotice in
			noticeTask?.cancel()
			guard let newNotice else {
				beginNoticeDismiss()
				return
			}
			isDismissingNotice = false
			withAnimation(MacNotificationAnimation.animation) {
				displayNotice = newNotice
			}
			scheduleNoticeDismiss(for: newNotice)
		}
		.frame(maxHeight: .infinity, alignment: .top)
		.frame(maxWidth: .infinity, alignment: .trailing)
	}

	private func panelContainer<Content: View>(
		@ViewBuilder content: @escaping () -> Content
	) -> some View {
		content()
			
	}

	private func panelContent<Content: View>(
		title: String,
		countText: String,
		actionTitle: String,
		action: @escaping () -> Void,
		bottomActions: AnyView?,
		@ViewBuilder content: @escaping () -> Content,
		isActionDisabled: Bool
	) -> some View {
		let titleBlock = VStack(alignment: .leading, spacing: 0) {
			Text(title)
				.font(.title2.weight(.semibold))
				.lineLimit(1)
				.minimumScaleFactor(0.85)
				.truncationMode(.tail)
			Text(countText)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.truncationMode(.tail)
		}
		let hasBottomBar = bottomActions != nil
		let bottomContentInset: CGFloat = hasBottomBar ? 60 : 20
		let bottomIndicatorInset: CGFloat = hasBottomBar ? (bottomContentInset + 2) : 10

		return ZStack(alignment: .bottomTrailing) {
			ZStack(alignment: .top) {
				ScrollView {
					content()
						.padding(.top, panelHeaderHeight + 12)
				}
				.scrollContentBackground(.hidden)
				.background(Color.clear)
				.background {
					QueuePinnedGlassSection(
						corners: [.allCorners],
						cornerRadius: 14
					) {
						Color.clear
					}
				}
				.panelContentScrollChrome(
					topInset: 0,
					bottomContentInset: bottomContentInset,
					applyMask: false
				)
				.contentMargins(.top, panelHeaderHeight + 2, for: .scrollIndicators)
				.contentMargins(.bottom, bottomIndicatorInset, for: .scrollIndicators)
				.contentMargins(.trailing, 8, for: .scrollIndicators)
				.contentMargins(.leading, 10, for: .scrollContent)
				.contentMargins(.trailing, 10, for: .scrollContent)
				.frame(maxHeight: .infinity, alignment: .top)
	

				QueuePinnedGlassSection(corners: [.topLeft, .topRight]) {
					ViewThatFits(in: .horizontal) {
						HStack(alignment: .top, spacing: 8) {
							titleBlock
							Spacer(minLength: 8)
							headerActions(
								actionTitle: actionTitle,
								action: action,
								isPinned: isPinned,
								isActionDisabled: isActionDisabled
							)
						}
						VStack(alignment: .leading, spacing: 10) {
							titleBlock
							HStack(spacing: 8) {
								Spacer(minLength: 0)
								headerActions(
									actionTitle: actionTitle,
									action: action,
									isPinned: isPinned,
									isActionDisabled: isActionDisabled
								)
							}
						}
					}
					.padding(.horizontal, 12)
					.padding(.top, 30)
					.padding(.bottom, 10)
				}
				.background(
					GeometryReader { proxy in
						Color.clear.preference(
							key: QueuePanelHeaderHeightKey.self,
							value: proxy.size.height - 10
						)
					}
				)
			}

			if let bottomActions {
				bottomActions
					.padding(.trailing, 18)
					.padding(.bottom, 12)
			}
		}
		.frame(maxHeight: .infinity)
		.onPreferenceChange(QueuePanelHeaderHeightKey.self) { newValue in
			if newValue > 0 {
				panelHeaderHeight = newValue
			}
		}
	}

	@ViewBuilder
	private func headerActions(
		actionTitle: String,
		action: @escaping () -> Void,
		isPinned: Binding<Bool>?,
		isActionDisabled: Bool
	) -> some View {
		if !queueIsEmpty {
			
			if #available(macOS 26.0, iOS 26.0, *) {
				HStack(spacing: 8) {
					if !actionTitle.isEmpty {
						Button {
							action()
						} label: {
							Image(systemName: "trash")
						}
						.buttonStyle(.plain)
						.controlSize(.large)
						.buttonBorderShape(.circle)
					}
					if let isPinned {
						Button {
							isPinned.wrappedValue.toggle()
						} label: {
							Image(systemName: isPinned.wrappedValue ? "pin.fill" : "pin")
								.font(.system(size: 11, weight: .semibold))
						}
						.buttonStyle(.plain)
						.controlSize(.large)
						.buttonBorderShape(.circle)
						.tint(isPinned.wrappedValue ? .accentColor : .secondary)
						.rotationEffect(.degrees(isPinned.wrappedValue ? 0 : 30))
						.animation(.easeInOut(duration: 0.18), value: isPinned.wrappedValue)
						.padding(.top, 2)
					}
				}.padding(.top, 16)
//					.border(.red, width: 2)
					.fixedSize(horizontal: true, vertical: false)
					.layoutPriority(1)
			} else {
				HStack(spacing: 8) {
					if !actionTitle.isEmpty {
						Button(actionTitle, action: action)
							.nativeActionButtonStyle(.primary, controlSize: .large)
							.disabled(isActionDisabled)
					}
					if let isPinned {
						if isPinned.wrappedValue {
							Button(action: { isPinned.wrappedValue.toggle() }) {
								Image(systemName: "pin.fill")
									.font(.system(size: 10, weight: .semibold))
							}
							.rotationEffect(.degrees(30))
							.nativeActionButtonStyle(.primary, controlSize: .large)
							.animation(.easeInOut(duration: 0.18), value: isPinned.wrappedValue)
						} else {
							Button(action: { isPinned.wrappedValue.toggle() }) {
								Image(systemName: "pin")
									.font(.system(size: 10, weight: .semibold))
							}
							.rotationEffect(.degrees(0))
							.nativeActionButtonStyle(.secondary, controlSize: .large)
							.animation(.easeInOut(duration: 0.18), value: isPinned.wrappedValue)
						}
					}
				}
				.fixedSize(horizontal: true, vertical: false)
				.layoutPriority(1)
			}
		}
	}

	private func tabTransition(for tab: Tab) -> AnyTransition {
		let insertion = AnyTransition.opacity
			.combined(
				with: .modifier(
					active: BlurFadeTransitionState(amount: 5),
					identity: BlurFadeTransitionState(amount: 0)
				)
			)
		let removal = AnyTransition.opacity
			.combined(
				with: .modifier(
					active: BlurFadeTransitionState(amount: 5),
					identity: BlurFadeTransitionState(amount: 0)
				)
			)
		return .asymmetric(insertion: insertion, removal: removal)
	}

	private struct BlurFadeTransitionState: ViewModifier {
		let amount: CGFloat
		func body(content: Content) -> some View {
			content.blur(radius: amount)
		}
	}

	private var notificationBackground: some View {
		let shape = Capsule()
		return
			Color.clear
			.glassCompatSurface(
				in: shape,
				style: .clear,
				context: panelState,
				fillColor: GlassThemeTokens.controlBackgroundBase(for: panelState),
				fillOpacity: panelGlassBaseOpacity,
				surfaceOpacity: panelGlassOpacity
			)
			.glassCompatBorder(in: shape, context: panelState, role: .standard)
			.glassCompatShadow(context: panelState, elevation: .panel)
	}

}

struct QueueBottomActions: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let queueCount: Int
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	var body: some View {
		HStack {
			Spacer()
			ExpandableJuiceMenu_AvailabilityAdapter(
				primaryTitle: primaryTitle,
				secondaryTitle: secondaryTitle,
				isEnabled: isEnabled,
				queueCount: queueCount,
				onPrimary: onPrimary,
				onSecondary: onSecondary
			)
		}
	}
}

extension QueuePanelContent {
	@MainActor
	fileprivate func scheduleNoticeDismiss(for noticeValue: Notice) {
		noticeTask?.cancel()
		noticeTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 1_500_000_000)
			if notice == noticeValue {
				beginNoticeDismiss()
			}
		}
	}

	@MainActor
	fileprivate func beginNoticeDismiss() {
		withAnimation(MacNotificationAnimation.animation) {
			isDismissingNotice = true
		}
		noticeTask?.cancel()
		noticeTask = Task { @MainActor in
			try? await Task.sleep(
				nanoseconds: MacNotificationAnimation.exitDuration
			)
			displayNotice = nil
			notice = nil
			isDismissingNotice = false
		}
	}
}

private enum MacNotificationAnimation {
	static var animation: Animation {
		.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.22)
	}

	static let entryStagger: Double = 0.025
	static let exitDuration: UInt64 = 220_000_000

	static var transition: AnyTransition {
		.asymmetric(
			insertion: .modifier(
				active: NotificationTransitionState(
					opacity: 0,
					scale: 0.985,
					blur: 6,
					offsetY: -12
				),
				identity: NotificationTransitionState(
					opacity: 1,
					scale: 1,
					blur: 0,
					offsetY: 0
				)
			),
			removal: .identity
		)
	}
}

private struct NotificationTransitionState: ViewModifier {
	let opacity: Double
	let scale: CGFloat
	let blur: CGFloat
	let offsetY: CGFloat

	func body(content: Content) -> some View {
		content
			.opacity(opacity)
			.scaleEffect(scale, anchor: .top)
			.blur(radius: blur)
			.offset(y: offsetY)
	}
}

private struct BouncingNoticeText: View {
	let text: String
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var animate = false

	var body: some View {
		if reduceMotion {
			Text(text)
				.font(.system(size: 13, weight: .semibold))
		} else {
			HStack(spacing: 0) {
				ForEach(Array(text.enumerated()), id: \.offset) {
					index,
					character in
					Text(String(character))
						.offset(y: letterOffset)
						.animation(
							.interpolatingSpring(stiffness: 260, damping: 16)
								.delay(
									Double(index)
										* MacNotificationAnimation.entryStagger
								),
							value: animate
						)
				}
			}
			.font(.system(size: 13, weight: .semibold))
			.onAppearUnlessPreview {
				animate = false
				DispatchQueue.main.async {
					animate = true
				}
			}
		}
	}

	private var letterOffset: CGFloat {
		animate ? 0 : -6
	}
}

#if os(macOS)
	private struct GlassSegmentedControl<Tag: Hashable>: View {
		@Environment(\.colorScheme) private var colorScheme
		@Environment(\.controlActiveState) private var controlActiveState

		struct Item: Identifiable {
			let id = UUID()
			let title: String
			let tag: Tag
			let isEnabled: Bool

			init(title: String, tag: Tag, isEnabled: Bool = true) {
				self.title = title
				self.tag = tag
				self.isEnabled = isEnabled
			}
		}

		let items: [Item]
		@Binding var selection: Tag
		let glassOpacity: CGFloat
		let backgroundGlassOpacity: CGFloat
		let backgroundGlassBaseOpacity: CGFloat

		@State private var hoveredTag: Tag?
		@State private var pressedTag: Tag?
		@State private var morphPulse = false
		@State private var morphTask: Task<Void, Never>?
		@Namespace private var selectionNamespace

		private let segmentPadding = EdgeInsets(
			top: 9,
			leading: 16,
			bottom: 9,
			trailing: 16
		)
		private let segmentSpacing: CGFloat = 12

		private var glassState: GlassStateContext {
			GlassStateContext(
				colorScheme: colorScheme,
				isFocused: controlActiveState == .active
			)
		}

		var body: some View {
			let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
			HStack(spacing: segmentSpacing) {
				ForEach(items) { item in
					segmentButton(for: item)
				}
			}
			.frame(maxWidth: .infinity, alignment: .center)
			.padding(6)
			.background {
				Color.clear
					.glassCompatSurface(
						in: shape,
						style: .regular,
						context: glassState,
						fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
						fillOpacity: min(
							1,
							backgroundGlassBaseOpacity
								+ GlassThemeTokens.panelNeutralOverlayOpacity(for: glassState)
						),
						surfaceOpacity: max(glassOpacity, backgroundGlassOpacity)
					)
			}
			.clipShape(shape)
			.glassCompatBorder(in: shape, context: glassState, role: .standard, lineWidth: 1)
			.glassCompatShadow(context: glassState, elevation: .small)
			.onChange(of: selection) { oldValue, newValue in
				triggerMorph(from: oldValue, to: newValue)
			}
			.animation(
				.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.32),
				value: selection
			)
		}

		private func segmentButton(for item: Item) -> some View {
			let isSelected = selection == item.tag
			let isHovered = hoveredTag == item.tag
			let isPressed = pressedTag == item.tag
			let textOpacity: CGFloat = item.isEnabled ? (isSelected ? 0.95 : 0.8) : 0.4
			let backgroundOpacity: CGFloat = isPressed ? 1 : (isHovered ? 0.7 : 0)
			let hoverRole: GlassOverlayRole = isPressed ? .pressed : .hover

			return Button {
				if item.isEnabled {
					selection = item.tag
				}
			} label: {
				Text(item.title)
					.font(.system(.callout, weight: .semibold))
					.foregroundStyle(GlassThemeTokens.textPrimary(for: glassState).opacity(textOpacity))
					.padding(segmentPadding)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.disabled(!item.isEnabled)
			.background {
				if isSelected {
					segmentSelectionPill
						.matchedGeometryEffect(
							id: "segmentedSelection",
							in: selectionNamespace
						)
				} else if backgroundOpacity > 0 {
					Capsule(style: .continuous)
						.fill(GlassThemeTokens.overlayColor(for: glassState, role: hoverRole))
						.opacity(backgroundOpacity)
				}
			}
			.onHover { hovering in
				hoveredTag = hovering ? item.tag : (hoveredTag == item.tag ? nil : hoveredTag)
			}
			.onLongPressGesture(
				minimumDuration: 0.01,
				maximumDistance: 12,
				pressing: { pressing in
					pressedTag = pressing ? item.tag : (pressedTag == item.tag ? nil : pressedTag)
				},
				perform: {}
			)
		}

		private var segmentSelectionPill: some View {
			let shape = Capsule(style: .continuous)
			return Color.clear
				.glassCompatSurface(
					in: shape,
					style: .regular,
					context: glassState,
					fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
					fillOpacity: 0.18,
					surfaceOpacity: 1
				)
				.overlay {
					shape.fill(GlassThemeTokens.overlayColor(for: glassState, role: .standard)).opacity(0.25)
				}
				.glassPopHighlight(usesColorGradient: false)
				.glassCompatBorder(in: shape, context: glassState, role: .strong, lineWidth: 0.8)
				.glassCompatShadow(context: glassState, elevation: .small)
				.scaleEffect(morphPulse ? 1.06 : 1)
				.animation(
					.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.22),
					value: morphPulse
				)
		}

		private func triggerMorph(from oldValue: Tag, to newValue: Tag) {
			guard oldValue != newValue else { return }
			morphTask?.cancel()
			morphTask = Task { @MainActor in
				morphPulse = true
				try? await Task.sleep(nanoseconds: 180_000_000)
				if !Task.isCancelled {
					morphPulse = false
				}
			}
		}
	}
#endif

private struct SegmentedActionButton: View {
	@Environment(\.colorScheme) private var colorScheme
	#if os(macOS)
	@Environment(\.controlActiveState) private var controlActiveState
	#endif
	let title: String
	let glassOpacity: CGFloat
	let isDisabled: Bool
	let action: () -> Void

	@State private var isHovered = false
	@State private var isPressed = false

	private let padding = EdgeInsets(
		top: 9,
		leading: 16,
		bottom: 9,
		trailing: 16
	)

	private var isWindowActive: Bool {
		#if os(macOS)
		return controlActiveState == .active
		#else
		return true
		#endif
	}

	private var glassState: GlassStateContext {
		GlassStateContext(
			colorScheme: colorScheme,
			isFocused: isWindowActive,
			isEnabled: !isDisabled,
			isHovered: isHovered,
			isPressed: isPressed
		)
	}

	var body: some View {
		let shape = Capsule(style: .continuous)
		let hoverOpacity: CGFloat = isPressed ? 0.06 : (isHovered ? 0.05 : 0.03)

		return Button {
			if !isDisabled {
				action()
			}
			} label: {
				Text(title)
					.font(.system(.callout, weight: .regular))
					.foregroundStyle(
						GlassThemeTokens.textPrimary(for: glassState).opacity(isDisabled ? 0.4 : 0.9)
					)
					.padding(padding)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.disabled(isDisabled)
			.background {
				Color.clear
					.glassCompatSurface(
						in: shape,
						style: .regular,
						context: glassState,
						fillColor: GlassThemeTokens.controlBackgroundBase(for: glassState),
						fillOpacity: hoverOpacity,
						surfaceOpacity: glassOpacity
					)
			}
			.glassCompatBorder(in: shape, context: glassState, role: .standard, lineWidth: 0.8)
			.glassPopHighlight(usesColorGradient: false)
			.glassCompatShadow(context: glassState, elevation: .small)
			.opacity(isDisabled ? 0.45 : 1)
		.onHover { hovering in
			isHovered = hovering
		}
		.onLongPressGesture(
			minimumDuration: 0.01,
			maximumDistance: 12,
			pressing: { pressing in
				isPressed = pressing
			},
			perform: {}
		)
	}
}

private struct RightPanelView_PreviewWrapper: View {
	@State private var tab: QueuePanelContent<AnyView, AnyView>.Tab
	@State private var notice: QueuePanelContent<AnyView, AnyView>.Notice?
	@State private var demoTaskStarted = false
	let showsNoticeDemo: Bool

	private let sampleQueue: [CaskApplication] = [
		CaskApplication(
			token: "omnissa-horizon-client",
			fullToken: "omnissa-horizon-client",
			name: ["Omnissa Horizon Client"],
			desc: "Virtual machine client for macOS",
			url: "https://download3.omnissa.com/Omnissa-Horizon-Client.pkg",
			version: "8.16.0",
			autoUpdates: true,
			matchingRecipeId:
				"com.github.dataJAR-recipes.munki.Omnissa Horizon Client"
		),
		CaskApplication(
			token: "microsoft-outlook",
			fullToken: "microsoft-outlook",
			name: ["Microsoft Outlook"],
			desc: "Email and calendar",
			url: "https://example.com/Outlook.pkg",
			version: "16.95.0"
		),
		CaskApplication(
			token: "omnissa-horizon-client1",
			fullToken: "omnissa-horizon-client1",
			name: ["Omnissa Horizon Client1"],
			desc: "Virtual machine client for macOS1",
			url: "https://download31.omnissa.com/Omnissa-Horizon-Client.pkg",
			version: "8.16.1",
			autoUpdates: true,
			matchingRecipeId:
				"com.github.dataJAR-recipes.munki.Omnissa Horizon Client"
		),
		CaskApplication(
			token: "microsoft-outlook3",
			fullToken: "microsoft-outlook3",
			name: ["Microsoft Outlook3"],
			desc: "Email and calendar3",
			url: "https://example.com/Outlook.pkg",
			version: "16.95.0"
		),
	]

	private let sampleResults: [CaskApplication] = [
		CaskApplication(
			token: "zoom",
			fullToken: "zoom",
			name: ["Zoom"],
			desc: "Video conferencing",
			url: "https://example.com/Zoom.dmg",
			version: "6.1.0"
		)
	]

	init(
		tab: QueuePanelContent<AnyView, AnyView>.Tab = .queue,
		notice: QueuePanelContent<AnyView, AnyView>.Notice? = nil,
		showsNoticeDemo: Bool = false
	) {
		self._tab = State(initialValue: tab)
		self._notice = State(initialValue: notice)
		self.showsNoticeDemo = showsNoticeDemo
	}

	var body: some View {
		QueuePanelContent(
			tab: $tab,
			notice: $notice,
			queueTitle: "Queue",
			resultsTitle: "Results",
			queueCountText: "\(sampleQueue.count) items",
			resultsCountText: "\(sampleResults.count) processed",
			queueIsEmpty: sampleQueue.isEmpty,
			resultsIsEmpty: sampleResults.isEmpty
		) {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(sampleQueue) { item in
						AppDetailListItem(item: item, label: "Version")
					}
				}
			)
		} resultsContent: {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(sampleResults) { item in
						AppDetailListItem(item: item, label: "Version")
					}
				}
			)
		}
		.padding()
		.background(JuiceGradient())
		.frame(width: 420, height: 520)
		.task {
			guard showsNoticeDemo, !demoTaskStarted else { return }
			demoTaskStarted = true
			while !Task.isCancelled {
				notice = .init(message: "Added to queue", isDuplicate: false)
				try? await Task.sleep(nanoseconds: 2_500_000_000)
			}
		}
	}
}

#Preview("RightPanelView") {
	RightPanelView_PreviewWrapper(
		tab: .queue,
		notice: .init(message: "Added to queue", isDuplicate: false)
	)
}

#Preview("RightPanelView Results") {
	RightPanelView_PreviewWrapper(tab: .results)
}

#Preview("RightPanelView Notice Animation") {
	RightPanelView_PreviewWrapper(
		tab: .queue,
		notice: nil,
		showsNoticeDemo: true
	)
}

private struct InspectorOverlayPreviewContainer<Content: View>: View {
	@Environment(\.colorScheme) private var colorScheme
	let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		let context = GlassStateContext(colorScheme: colorScheme, isFocused: true)
		content
			.padding(20)
			.frame(width: 480, height: 620, alignment: .top)
			.background {
				Color.clear
					.glassCompatSurface(
						in: shape,
						style: .regular,
						context: context,
						fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
						fillOpacity: GlassThemeTokens.panelBaseTintOpacity(for: context),
						surfaceOpacity: GlassThemeTokens.panelSurfaceOpacity(for: context)
					)
			}
			.clipShape(shape)
			.glassCompatBorder(in: shape, context: context, role: .standard)
			.glassCompatShadow(context: context, elevation: .panel)
			.padding(30)
	}
}

private struct QueuePanelContentInspectorPreview: View {
	@State private var tab: QueuePanelContent<AnyView, AnyView>.Tab = .queue
	@State private var notice: QueuePanelContent<AnyView, AnyView>.Notice? = nil

	private let sampleQueue: [CaskApplication] = [
		CaskApplication(
			token: "omnissa-horizon-client",
			fullToken: "omnissa-horizon-client",
			name: ["Omnissa Horizon Client"],
			desc: "Virtual machine client for macOS",
			url: "https://download3.omnissa.com/Omnissa-Horizon-Client.pkg",
			version: "8.16.0",
			autoUpdates: true,
			matchingRecipeId:
				"com.github.dataJAR-recipes.munki.Omnissa Horizon Client"
		),
		CaskApplication(
			token: "microsoft-outlook",
			fullToken: "microsoft-outlook",
			name: ["Microsoft Outlook"],
			desc: "Email and calendar",
			url: "https://example.com/Outlook.pkg",
			version: "16.95.0"
		),
	]

	private let sampleResults: [CaskApplication] = [
		CaskApplication(
			token: "zoom",
			fullToken: "zoom",
			name: ["Zoom"],
			desc: "Video conferencing",
			url: "https://example.com/Zoom.dmg",
			version: "6.1.0"
		)
	]

	private var leftPanel: some View {
		let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		let context = GlassStateContext(colorScheme: .light, isFocused: true)
		return
			Color.clear
			.glassCompatSurface(
				in: shape,
				style: .regular,
				context: context,
				fillColor: GlassThemeTokens.controlBackgroundBase(for: context),
				fillOpacity: 0.6,
				surfaceOpacity: 1
			)
			.glassCompatBorder(in: shape, context: context, role: .strong)
			.glassCompatShadow(context: context, elevation: .panel)
			.frame(width: 600)
			.padding(.leading, 12)
			.padding(.vertical, 100)
	}

	var body: some View {
		ZStack {
			JuiceGradient()
				.ignoresSafeArea()
			leftPanel
				.frame(width: 600)
			//.ignoresSafeArea()
			HStack {
				InspectorOverlayPreviewContainer {
					QueuePanelContent(
						tab: $tab,
						notice: $notice,
						queueTitle: "Queue",
						resultsTitle: "Results",
						queueCountText: "\(sampleQueue.count) apps added",
						resultsCountText: "\(sampleResults.count) processed",
						queueIsEmpty: sampleQueue.isEmpty,
						resultsIsEmpty: sampleResults.isEmpty
					) {
						AnyView(
							LazyVStack(spacing: 8) {
								ForEach(sampleQueue) { item in
									AppDetailListItem(
										item: item,
										label: "Version"
									)
								}
							}
						)
					} resultsContent: {
						AnyView(
							LazyVStack(spacing: 8) {
								ForEach(sampleResults) { item in
									AppDetailListItem(
										item: item,
										label: "Version"
									)
								}
							}
						)
					}
				}
			}
		}
		.frame(width: 920, height: 400)
		.padding(10)
	}
}

#Preview("QueuePanelContent Inspector Overlay") {
	QueuePanelContentInspectorPreview()
}

#Preview("QueuePanelContent") {
	@Previewable @State var tab: QueuePanelContent<AnyView, AnyView>.Tab =
		.queue
	@Previewable @State var notice:
		QueuePanelContent<AnyView, AnyView>.Notice? = .init(
			message: "Added to queue",
			isDuplicate: false
		)

	return QueuePanelContent(
		tab: $tab,
		notice: $notice,
		queueTitle: "Queue",
		resultsTitle: "Results",
		queueCountText: "2 items",
		resultsCountText: "1 processed",
		queueIsEmpty: false,
		resultsIsEmpty: false
	) {
		AnyView(
			VStack {
				Text("Queue Item 1")
				Text("Queue Item 2")
			}
		)
	} resultsContent: {
		AnyView(
			VStack {
				Text("Result Item 1")
			}
		)
	}
	.padding()
}
struct InspectorSearchQueuePanelView: View {
	@EnvironmentObject private var inspector: InspectorCoordinator
	@Binding var tab: QueuePanelContent<AnyView, AnyView>.Tab
	@Binding var notice: QueuePanelContent<AnyView, AnyView>.Notice?
	@Binding var queueItems: [CaskApplication]
	@Binding var resultsItems: [CaskApplication]
	let panelMinHeight: CGFloat
	let onPrimaryAction: () -> Void
	let onSecondaryAction: () -> Void

	var body: some View {
		QueuePanelContent(
			tab: $tab,
			notice: $notice,
			queueTitle: "Queue",
			resultsTitle: "Results",
			queueCountText: "\(queueItems.count) apps added",
			resultsCountText: "\(resultsItems.count) processed",
			queueIsEmpty: queueItems.isEmpty,
			resultsIsEmpty: resultsItems.isEmpty,
			onQueueAction: {
				withAnimation(.easeInOut(duration: 0.2)) {
					queueItems.removeAll()
				}
			},
			onResultsAction: {
				withAnimation(.easeInOut(duration: 0.2)) {
					resultsItems.removeAll()
				}
			},
			isPinned: nil,
			bottomActions: AnyView(
				QueueBottomActions(
					primaryTitle: "Upload to UEM",
					secondaryTitle: "Download Only",
					isEnabled: !queueItems.isEmpty,
					queueCount: queueItems.count,
					onPrimary: onPrimaryAction,
					onSecondary: onSecondaryAction
				)
			)
		) {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(queueItems) { item in
						AppDetailListItem(item: item, label: "Version")
							.transition(.opacity.combined(with: .move(edge: .top)))
							}
				}
				.padding(.leading, 10)
			)
		} resultsContent: {
			AnyView(LazyVStack(spacing: 8) {
				ForEach(resultsItems) { item in
					AppDetailListItem(item: item, label: "Version")
						.transition(.opacity.combined(with: .move(edge: .top)))
				}
			}
			.padding(.leading, 10))
		}
		.frame(alignment: .leading)
		.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
		.frame(maxWidth: .infinity, alignment: .trailing)
		.background(Color.clear)
	}
}

struct InspectorUpdatesQueuePanelView: View {
	@EnvironmentObject private var inspector: InspectorCoordinator
	@Binding var tab: QueuePanelContent<AnyView, AnyView>.Tab
	@Binding var notice: QueuePanelContent<AnyView, AnyView>.Notice?
	@Binding var queueItems: [CaskApplication]
	@Binding var resultsItems: [CaskApplication]
	@Binding var selectedAppKeys: Set<String>
	let panelMinHeight: CGFloat
	let onPrimaryAction: () -> Void
	let onSecondaryAction: () -> Void
	let onQueueItemsRemoved: ([CaskApplication]) -> Void

	var body: some View {
		QueuePanelContent(
			tab: $tab,
			notice: $notice,
			queueTitle: "Queue",
			resultsTitle: "Results",
			queueCountText: "\(queueItems.count) selected",
			resultsCountText: "\(resultsItems.count) processed",
			queueIsEmpty: queueItems.isEmpty,
				resultsIsEmpty: resultsItems.isEmpty,
				onQueueAction: {
					let removedItems = queueItems
					withAnimation(.easeInOut(duration: 0.2)) {
						queueItems.removeAll()
						selectedAppKeys.removeAll()
					}
					onQueueItemsRemoved(removedItems)
				},
			onResultsAction: {
				withAnimation(.easeInOut(duration: 0.2)) {
					resultsItems.removeAll()
				}
			},
			isPinned: nil,
			bottomActions: AnyView(
				QueueBottomActions(
					primaryTitle: "Upload to UEM",
					secondaryTitle: "Download Only",
					isEnabled: !queueItems.isEmpty,
					queueCount: queueItems.count,
					onPrimary: onPrimaryAction,
					onSecondary: onSecondaryAction
				)
			)
		) {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(queueItems) { item in
						AppDetailListItem(
							item: item,
							label: "New Version"
						)
						.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
				.padding(.leading, 10)
			)
		} resultsContent: {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(resultsItems) { item in
						AppDetailListItem(
							item: item,
							label: "New Version"
						)
						.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
				.padding(.leading, 10)
			)
		}
		.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
		.frame(maxWidth: .infinity, alignment: .trailing)
	}
}

struct InspectorImportQueuePanelView: View {
	@EnvironmentObject private var inspector: InspectorCoordinator
	@Binding var tab: QueuePanelContent<AnyView, AnyView>.Tab
	@Binding var queueItems: [ImportedApplication]
	@Binding var resultsItems: [ImportedApplication]
	let panelMinHeight: CGFloat
	let onPrimaryAction: () -> Void
	let onSecondaryAction: () -> Void
	let onQueueItemsRemoved: ([ImportedApplication]) -> Void

	var body: some View {
		QueuePanelContent(
			tab: $tab,
			queueTitle: "Queue",
			resultsTitle: "Results",
			queueCountText: "\(queueItems.count) items",
			resultsCountText: "\(resultsItems.count) completed",
			queueIsEmpty: queueItems.isEmpty,
			resultsIsEmpty: resultsItems.isEmpty,
			onQueueAction: {
				let removedItems = queueItems
				withAnimation(.easeInOut(duration: 0.2)) {
					queueItems.removeAll()
				}
				onQueueItemsRemoved(removedItems)
			},
			onResultsAction: {
				withAnimation(.easeInOut(duration: 0.2)) {
					resultsItems.removeAll()
				}
			},
			isPinned: nil,
			bottomActions: AnyView(
				QueueBottomActions(
					primaryTitle: "Upload to UEM",
					secondaryTitle: "Download Only",
					isEnabled: !queueItems.isEmpty,
					queueCount: queueItems.count,
					onPrimary: onPrimaryAction,
					onSecondary: onSecondaryAction
				)
			)
		) {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(queueItems) { item in
						ImportAppDetailListItem(item: item, label: "Version")
							.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
				.padding(.leading, 10)
			)
		} resultsContent: {
			AnyView(
				LazyVStack(spacing: 8) {
					ForEach(resultsItems) { item in
						ImportAppDetailListItem(item: item, label: "Version")
							.transition(.opacity.combined(with: .move(edge: .top)))
					}
				}
				.padding(.leading, 10)
			)
		}
		.frame(minHeight: panelMinHeight, maxHeight: .infinity, alignment: .top)
		.frame(maxWidth: .infinity, alignment: .trailing)
	}
}
