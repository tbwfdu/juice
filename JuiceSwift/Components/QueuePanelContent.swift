import SwiftUI

#if os(macOS)
	import AppKit
#endif

struct QueuePanelContent<QueueContent: View, ResultsContent: View>: View {
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
	private let noticeText = "Added!"
	// Temporary override so the Results tab can be tested even when empty.
	private let enableResultsTabWhenEmpty = true
	private var panelGlassOpacity: CGFloat {
		focusObserver.isFocused ? 0.99 : 0.9
	}
	private var panelGlassBaseOpacity: CGFloat {
		focusObserver.isFocused ? 0.62 : 0.3
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

	var body: some View {
		let resultsTabEnabled = enableResultsTabWhenEmpty || !resultsIsEmpty
		ZStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 12) {
				#if os(macOS)
					//				GlassSegmentedControl(
					//					items: [
					//						.init(title: "Queue", tag: .queue),
					//						.init(title: "Results", tag: .results, isEnabled: resultsTabEnabled)
					//					],
					//					selection: $tab,
					//					glassOpacity: glassOpacity,
					//					backgroundGlassOpacity: glassOpacity,
					//					backgroundGlassBaseOpacity: glassBaseOpacity
					//				)
					//				.onChange(of: resultsIsEmpty) { _, isEmpty in
					//					if isEmpty && tab == .results {
					//						tab = .queue
					//					}
					//				}
					//				HStack(){
					//					Spacer()
					//				GlassTabControl(
					//					isQueueSelected: tab == .queue,
					//					onSelectQueue: { tab = .queue },
					//					isResultsSelected: tab == .results,
					//					onSelectResults: { tab = .results }
					//				)
					//						.frame(
					//							maxWidth: 150, alignment: .trailing
					//						)
					//				}
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
					.animation(.easeInOut(duration: 0.18), value: tab)
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
		.onAppear {
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
		// Keep a consistent panel width and ensure it hugs the right edge on resize
		.frame(maxWidth: 400)
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
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				VStack(alignment: .leading, spacing: 4) {
					Text(title)
						.font(.title.weight(.semibold))
					Text(countText)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				Spacer()
				if #available(macOS 26.0, iOS 26.0, *) {
					HStack(spacing: 8) {
						SingleGlassButtonSml(icon: "trash", action: action)
							.disabled(isActionDisabled)
						if let isPinned {
							Button {
								isPinned.wrappedValue.toggle()
							} label: {
								Image(
									systemName: isPinned.wrappedValue
										? "pin.fill" : "pin"
								)
							}
							.buttonStyle(.plain)
							.controlSize(.large)
							.buttonBorderShape(.circle)
							.tint(
								isPinned.wrappedValue ? .accentColor : .secondary
							)
							.rotationEffect(
								.degrees(isPinned.wrappedValue ? 0 : 30)
							)
							.animation(
								.easeInOut(duration: 0.18),
								value: isPinned.wrappedValue
							)
						}
					}
				} else {
					HStack(spacing: 8) {
						Button(actionTitle, action: action)
							.buttonStyle(.juiceGlass(.primary))
							.controlSize(.large)
							.disabled(isActionDisabled)
						if let isPinned {
							Button(action: { isPinned.wrappedValue.toggle() }) {
								Image(
									systemName: isPinned.wrappedValue
										? "pin.fill" : "pin"
								)
							}
							.rotationEffect(.degrees(isPinned.wrappedValue ? 30 : 0))
							.buttonStyle(isPinned.wrappedValue ? .juiceGlass(.primary) : .juiceGlass(.secondary))
							.controlSize(.large)
							.animation(.easeInOut(duration: 0.18), value: isPinned.wrappedValue)
						}
					}
				}
			}
			ZStack(alignment: .bottomTrailing) {
				ScrollView {
					content()
						.padding(.vertical, 14)
						.padding(.horizontal, 10)
				}
				if let bottomActions {
					bottomActions
						.padding(.trailing, 12)
						.padding(.bottom, 12)
				}
			}
			.frame(maxHeight: .infinity)
			.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
			// This "expands" container that holds the list items
			.padding(-16)
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
		let glassOpacity: CGFloat = 0.3
		return
			shape
			.fill(Color.clear)
			.background {
				if #available(macOS 26.0, iOS 26.0, *) {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.clear, in: shape)
					}
					.opacity(glassOpacity)
				} else {
					shape.fill(.ultraThinMaterial)
						.opacity(glassOpacity)
				}
			}
			.overlay(shape.strokeBorder(.white.opacity(0.12)))
			.shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
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
			ExpandableMenu_AvailabilityAdapter(
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
		.timingCurve(0.22, 0.88, 0.3, 1.0, duration: 0.28)
	}

	static let entryStagger: Double = 0.035
	static let exitDuration: UInt64 = 280_000_000

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
			.onAppear {
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

		var body: some View {
			HStack(spacing: segmentSpacing) {
				ForEach(items) { item in
					segmentButton(for: item)
				}
			}
			.frame(maxWidth: .infinity, alignment: .center)
			.padding(6)
			.background {
				let shape = RoundedRectangle(
					cornerRadius: 16,
					style: .continuous
				)
				if #available(macOS 26.0, iOS 26.0, *) {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
					.overlay {
						shape
							.fill(
								Color.white.opacity(backgroundGlassBaseOpacity)
							)
							.opacity(backgroundGlassOpacity)
					}
				} else {
					shape.fill(.ultraThinMaterial)
						.opacity(backgroundGlassOpacity)
				}
			}
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.strokeBorder(.white.opacity(0.12))
			}
			.shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
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
			let textOpacity: CGFloat =
				item.isEnabled ? (isSelected ? 0.95 : 0.8) : 0.4
			let backgroundOpacity: CGFloat =
				isPressed ? 0.16 : (isHovered ? 0.12 : 0)

			return Button {
				if item.isEnabled {
					selection = item.tag
				}
			} label: {
				Text(item.title)
					.font(.system(.callout, weight: .semibold))
					.foregroundStyle(Color.primary.opacity(textOpacity))
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
						.fill(Color.white.opacity(backgroundOpacity))
				}
			}
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

		private var segmentSelectionPill: some View {
			let shape = Capsule(style: .continuous)
			return ZStack {
				if #available(macOS 26.0, iOS 26.0, *) {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
				} else {
					shape.fill(.ultraThinMaterial)
				}
				shape
					.fill(Color.white)
					.opacity(0.05)
			}
			.glassPopHighlight(usesColorGradient: false)
			.overlay(
				shape.strokeBorder(
					LinearGradient(
						gradient: Gradient(stops: [
							.init(
								color: Color.white.opacity(0.26),
								location: 0.0
							),
							.init(
								color: Color.white.opacity(0.08),
								location: 1.0
							),
						]),
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 0.8
				)
			)
			.shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
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
				.foregroundStyle(Color.primary.opacity(isDisabled ? 0.4 : 0.9))
				.padding(padding)
				.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.disabled(isDisabled)
		.background {
			ZStack {
				if #available(macOS 26.0, iOS 26.0, *) {
					GlassEffectContainer {
						shape
							.fill(Color.clear)
							.glassEffect(.regular, in: shape)
					}
				} else {
					shape.fill(.ultraThinMaterial)
				}
				shape
					.fill(Color.white)
					.opacity(hoverOpacity)
			}
		}
		.overlay(
			shape.strokeBorder(
				LinearGradient(
					gradient: Gradient(stops: [
						.init(
							color: Color.white.opacity(
								isPressed ? 0.16 : (isHovered ? 0.2 : 0.22)
							),
							location: 0.0
						),
						.init(color: Color.white.opacity(0.08), location: 1.0),
					]),
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				),
				lineWidth: 0.8
			)
		)
		.glassPopHighlight(usesColorGradient: false)
		.shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
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
		.frame(width: 420, height: 620)
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
	let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
		content
			.padding(20)
			.frame(width: 480, height: 620, alignment: .top)
			.background {
				if #available(macOS 26.0, iOS 26.0, *) {
					ZStack {
						shape
							.fill(
								Color(red: 1.0, green: 0.965, blue: 0.93)
									.opacity(0.2)
							)
						GlassEffectContainer {
							shape
								.fill(Color.clear)
								.glassEffect(.regular, in: shape)
						}
					}
				} else {
					shape.fill(.ultraThinMaterial)
						.opacity(0.7)
				}
			}
			.clipShape(shape)
			.overlay(shape.strokeBorder(.white.opacity(0.12)))
			.shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 8)
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
		return
			shape
			.fill(Color.white.opacity(0.6))
			.overlay(shape.strokeBorder(.white.opacity(0.2)))
			.shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
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
		.frame(width: 920, height: 600)
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
