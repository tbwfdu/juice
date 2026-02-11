//
//  ExpandableMenu.swift
//  Juice
//
//  Created by Pete Lindley on 2/2/2026.
//

import SwiftUI

// Temporary compatibility aliases during naming migration.
typealias ExpandableJuiceMenu_PrebigSurFallback = ExpandableJuiceMenuFallback
typealias ExpandableJuiceMenu_AvailabilityAdapter =
	ExpandableJuiceMenuAvailabilityAdapter
typealias ExpandingJuiceButtons_AvailabilityAdapter =
	ExpandingJuiceButtonsAvailabilityAdapter
typealias ExpandingJuiceButtons_PrebigSurFallback =
	ExpandingJuiceButtonsFallback

@available(macOS 26.0, *)
struct ExpandableJuiceMenu: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let queueCount: Int
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false
	@Namespace private var namespace

	var body: some View {
		GlassEffectContainer(spacing: 5) {
			VStack(alignment: .trailing, spacing: 12) {
				if isExpanded {
					VStack(spacing: 12) {
						JuiceButtons.primary(primaryTitle) {
							guard isEnabled else { return }
							onPrimary()
						}
						.disabled(!isEnabled)

						JuiceButtons.secondary(
							secondaryTitle,
							usesColorGradient: false
						) {
							guard isEnabled else { return }
							onSecondary()
						}
						.disabled(!isEnabled)
					}
					.transition(.move(edge: .bottom).combined(with: .opacity))
				}
				ZStack(alignment: .topTrailing) {
					SingleGlassButtonImageRound(
						image: "JuiceLogo",
						buttonDiameter: 10
					) {
						withAnimation(.bouncy) {
							isExpanded.toggle()
						}
					}
					.glassEffectID("toggle", in: namespace)

					if queueCount > 0 {
						Text("\(queueCount)")
							.font(.system(size: 9, weight: .bold))
							.foregroundStyle(Color.white)
							.frame(minWidth: 16, minHeight: 16)
							.background(
								Circle().fill(Color.accentColor)
							)
							.offset(x: 4, y: -4)
					}
				}
				//				SingleGlassButton(icon: "plus") {
				//					withAnimation(.bouncy) {
				//						isExpanded.toggle()
				//					}
				//				}

			}
		}
		.background(
			WindowClickMonitor(isExpanded: isExpanded) {
				withAnimation(.bouncy) {
					isExpanded = false
				}
			}
		)
	}
}

@available(macOS 26.0, *)
struct ExpandableMenuGlassSplit: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let queueCount: Int
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false
	@State private var isAllExpanded = false
	@State private var glassSpacing: CGFloat = 40
	@State private var buttonSpacing: CGFloat = 25
	@State private var expandTask: Task<Void, Never>?
	@Namespace private var namespace

	var body: some View {
		ZStack {
			GlassEffectContainer(spacing: glassSpacing) {
				VStack(spacing: buttonSpacing) {
					if isAllExpanded && isExpanded {
						Button(action: onPrimary) {
							Text(primaryTitle)
								.font(.system(size: 12, weight: .regular))
								.padding(.horizontal, 0)
								.padding(.vertical, 4)
						}
						.buttonStyle(.glassProminent)
						.controlSize(.large)
						.disabled(!isEnabled)
						.glassEffectID("glassPrimary", in: namespace)
					}
					if isExpanded {
						Button(action: onSecondary) {
							Text(secondaryTitle)
								.font(.system(size: 12, weight: .regular))
								.padding(.horizontal, 0)
								.padding(.vertical, 4)
						}
						.padding(1)
						.buttonStyle(.glass)
						.controlSize(.large)
						.disabled(!isEnabled)
						.glassEffectID("glassSecondary", in: namespace)
					}
				}
				.frame(width: 150, alignment: .trailing)

				HStack {
					Spacer()
					ZStack(alignment: .trailing) {
						SingleGlassButtonImageRound(
							image: "JuiceLogo",
							buttonDiameter: 10
						) {
							toggleExpanded()
						}
						.glassEffectID("glassToggle", in: namespace)

						if queueCount > 0 {
							Text("\(queueCount)")
								.font(.system(size: 9, weight: .bold))
								.foregroundStyle(Color.white)
								.frame(minWidth: 16, minHeight: 16)
								.background(
									Circle().fill(Color.accentColor)
								)
								.offset(x: 4, y: -15)
						}
					}
					.frame(width: 40)
				}
				.frame(
					alignment: .init(
						horizontal: .trailing,
						vertical: .bottom
					)
				)
			}
		}
		.frame(maxWidth: 150, alignment: .trailing)
		.background(
			WindowClickMonitor(isExpanded: isExpanded) {
				collapseExpanded()
			}
		)
	}

	private func toggleExpanded() {
		if isExpanded {
			collapseExpanded()
		} else {
			expandActions()
		}
	}

	private func expandActions() {
		expandTask?.cancel()
		withAnimation(.bouncy) {
			isExpanded.toggle()
		}
		expandTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.1))
			withAnimation(.bouncy) {
				isAllExpanded.toggle()
			}
			try? await Task.sleep(for: .seconds(0.3))
			glassSpacing = 10
			buttonSpacing = 10
		}
	}

	private func collapseExpanded() {
		expandTask?.cancel()
		glassSpacing = 40
		buttonSpacing = 25
		withAnimation(.bouncy) {
			isAllExpanded = false
			isExpanded = false
		}
	}
}

private struct WindowClickMonitor: NSViewRepresentable {
	let isExpanded: Bool
	let onCollapse: () -> Void

	func makeNSView(context: Context) -> WindowClickMonitorView {
		let view = WindowClickMonitorView()
		view.isExpanded = isExpanded
		view.onCollapse = onCollapse
		return view
	}

	func updateNSView(_ nsView: WindowClickMonitorView, context: Context) {
		nsView.isExpanded = isExpanded
		nsView.onCollapse = onCollapse
	}
}

private final class WindowClickMonitorView: NSView {
	var isExpanded = false
	var onCollapse: (() -> Void)?
	nonisolated(unsafe) private var monitor: Any?

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		startMonitoring()
	}

	deinit {
		stopMonitoring()
	}

	private func startMonitoring() {
		stopMonitoring()
		guard window != nil else { return }
		monitor = NSEvent.addLocalMonitorForEvents(matching: [
			.leftMouseUp, .rightMouseUp,
		]) { [weak self] event in
			guard let self else { return event }
			guard self.isExpanded, let window = self.window,
				event.window === window
			else {
				return event
			}
			let frameInWindow = self.convert(self.bounds, to: nil)
			if !frameInWindow.contains(event.locationInWindow) {
				DispatchQueue.main.async { [weak self] in
					self?.onCollapse?()
				}
			}
			return event
		}
	}

	nonisolated private func stopMonitoring() {
		let existingMonitor = monitor
		monitor = nil
		guard let existingMonitor else { return }
		DispatchQueue.main.async {
			NSEvent.removeMonitor(existingMonitor)
		}
	}
}

// Fallback for earlier macOS versions where GlassEffectContainer is unavailable
struct ExpandableJuiceMenuFallback: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let queueCount: Int
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false

	var body: some View {
		HStack(spacing: 16) {
			if isExpanded {
				Button(primaryTitle) {
					guard isEnabled else { return }
					onPrimary()
				}
				.disabled(!isEnabled)
				Button(secondaryTitle) {
					guard isEnabled else { return }
					onSecondary()
				}
				.disabled(!isEnabled)
			}
			ZStack(alignment: .topTrailing) {
				Button {
					withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
					{
						isExpanded.toggle()
					}
				} label: {
					Image(systemName: isExpanded ? "xmark" : "plus")
						.frame(width: 44, height: 44)
				}
				.buttonStyle(.borderedProminent)
				.buttonBorderShape(.capsule)

				if queueCount > 0 {
					Text("\(queueCount)")
						.font(.system(size: 9, weight: .bold))
						.foregroundStyle(Color.white)
						.frame(minWidth: 16, minHeight: 16)
						.background(
							Circle().fill(Color.accentColor)
						)
						.offset(x: 4, y: -4)
				}
			}
		}
		.padding(12)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(.ultraThinMaterial)
		)
	}
}

struct ExpandableJuiceMenuAvailabilityAdapter: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let queueCount: Int
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	var body: some View {
		if #available(macOS 26.0, *) {
			ExpandableMenuGlassSplit(
				primaryTitle: primaryTitle,
				secondaryTitle: secondaryTitle,
				isEnabled: isEnabled,
				queueCount: queueCount,
				onPrimary: onPrimary,
				onSecondary: onSecondary
			)
		} else {
			ExpandableJuiceMenuFallback(
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

//Expand out to Right

@available(macOS 26.0, *)
struct ExpandingButtonsGlass: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false
	@State private var isAllExpanded = false
	@State private var glassSpacing: CGFloat = 40
	@State private var buttonSpacing: CGFloat = 25
	@State private var expandTask: Task<Void, Never>?
	@Namespace private var namespace

	var body: some View {
		VStack {
			Button(action: { expandActions() }) {
				Text("Open")
					.font(.system(size: 12, weight: .regular))
					.padding(.horizontal, 0)
					.padding(.vertical, 4)
			}
			.buttonStyle(.glassProminent)
			.controlSize(.large)

			ZStack {
				GlassEffectContainer(spacing: glassSpacing) {
					HStack(spacing: buttonSpacing) {
						if isAllExpanded && isExpanded {
							Button(action: onPrimary) {
								Text(primaryTitle)
									.font(.system(size: 12, weight: .regular))
									.padding(.horizontal, 0)
									.padding(.vertical, 4)
							}
							.buttonStyle(.glassProminent)
							.controlSize(.large)
							.disabled(!isEnabled)
							.glassEffectID("glassPrimary", in: namespace)
						}
						if isExpanded {
							Button(action: onSecondary) {
								Text(secondaryTitle)
									.font(.system(size: 12, weight: .regular))
									.padding(.horizontal, 0)
									.padding(.vertical, 4)
							}
							.padding(1)
							.buttonStyle(.glass)
							.controlSize(.large)
							.disabled(!isEnabled)
							.glassEffectID("glassSecondary", in: namespace)
						}
					}
					.frame(width: 150, alignment: .trailing)

					//				HStack {
					//					Spacer()
					//					ZStack(alignment: .trailing) {
					//						SingleGlassButtonImageRound(
					//							image: "JuiceLogo",
					//							buttonDiameter: 10
					//						) {
					//							toggleExpanded()
					//						}
					//						.glassEffectID("glassToggle", in: namespace)
					//					}
					//					.frame(width: 40)
					//				}
					//				.frame(
					//					alignment: .init(
					//						horizontal: .trailing,
					//						vertical: .bottom
					//					)
					//				)
				}
			}
			.frame(maxWidth: 150, alignment: .trailing)
			//		.background(
			//			WindowClickMonitor(isExpanded: isExpanded) {
			//				collapseExpanded()
			//			}
			//		)

		}
	}

	private func toggleExpanded() {
		if isExpanded {
			collapseExpanded()
		} else {
			expandActions()
		}
	}

	private func expandActions() {
		expandTask?.cancel()
		withAnimation(.bouncy) {
			isExpanded.toggle()
		}
		expandTask = Task { @MainActor in
			try? await Task.sleep(for: .seconds(0.1))
			withAnimation(.bouncy) {
				isAllExpanded.toggle()
			}
			try? await Task.sleep(for: .seconds(0.3))
			glassSpacing = 10
			buttonSpacing = 10
		}
	}

	private func collapseExpanded() {
		expandTask?.cancel()
		glassSpacing = 40
		buttonSpacing = 25
		withAnimation(.bouncy) {
			isAllExpanded = false
			isExpanded = false
		}
	}
}

struct ExpandingJuiceButtonsAvailabilityAdapter: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let isFolderSelected: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	var body: some View {
		if #available(macOS 26.0, *) {
			ExpandingButtonsGlass(
				primaryTitle: primaryTitle,
				secondaryTitle: secondaryTitle,
				isEnabled: isEnabled,
				onPrimary: onPrimary,
				onSecondary: onSecondary,
			)
		} else {
			ExpandingJuiceButtonsFallback(
				primaryTitle: primaryTitle,
				secondaryTitle: secondaryTitle,
				isEnabled: isEnabled,
				onPrimary: onPrimary,
				onSecondary: onSecondary,
			)
		}
	}
}

struct ExpandingJuiceButtonsFallback: View {
	let primaryTitle: String
	let secondaryTitle: String
	let isEnabled: Bool
	let onPrimary: () -> Void
	let onSecondary: () -> Void

	@State private var isExpanded = false

	var body: some View {
		HStack(spacing: 16) {
			if isExpanded {
				Button(primaryTitle) {
					guard isEnabled else { return }
					onPrimary()
				}
				.disabled(!isEnabled)
				Button(secondaryTitle) {
					guard isEnabled else { return }
					onSecondary()
				}
				.disabled(!isEnabled)
			}
			ZStack(alignment: .topTrailing) {
				Button {
					withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
					{
						isExpanded.toggle()
					}
				} label: {
					Image(systemName: isExpanded ? "xmark" : "plus")
						.frame(width: 44, height: 44)
				}
				.buttonStyle(.borderedProminent)
				.buttonBorderShape(.capsule)

			}
		}
		.padding(12)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(.ultraThinMaterial)
		)
	}
}

////Expand out to Right
//
//@available(macOS 26.0, *)
//struct ExpandingButtonsGlass: View {
//	let primaryTitle: String
//	let secondaryTitle: String
//	let isEnabled: Bool
//	let isFolderSelected: Bool
//	let onPrimary: () -> Void
//	let onSecondary: () -> Void
//	let onTertiary: () -> Void
//
//	@State private var isSelectBtnExpanded = true
//	@State private var isScanBtnExpanded = false
//	@State private var isClearBtnExpanded = false
//	@State private var glassSpacing: CGFloat = 40
//	@State private var buttonSpacing: CGFloat = 25
//	@State private var selectButtonTask: Task<Void, Never>?
//	@State private var scanButtonTask: Task<Void, Never>?
//	@State private var clearButtonTask: Task<Void, Never>?
//	@State private var collapseAllTask: Task<Void, Never>?
//	@State private var spacingUpdateTask: Task<Void, Never>?
//	@State private var selectFolderBtnOpacity: Double = 1.0
//	private let selectFolderFadeDuration: Double = 0.25
//	private let selectFolderFadeEase = Animation.easeInOut(duration: 0.3)
//	private let defaultGlassSpacing: CGFloat = 40
//	private let defaultButtonSpacing: CGFloat = 25
//	private let compactSpacing: CGFloat = 10
//
//	@Namespace private var namespace
//
//	var body: some View {
//		ZStack {
//			GlassEffectContainer(spacing: glassSpacing) {
//				HStack {
//					ZStack(alignment: .trailing) {
//						if isSelectBtnExpanded {
//
//							Button(action: selectFolderButtonActions) {
//								Text("Select Folder")
//									.font(.system(size: 12, weight: .regular))
//									.padding(.horizontal, 5)
//									.padding(.vertical, 4)
//							}
//							.padding(1)
//							.buttonStyle(.glass)
//							.controlSize(.large)
//							.disabled(!isEnabled)
//							.glassEffectID("glassToggle", in: namespace)
//							.frame(minWidth: 10)
//							.allowsHitTesting(!isFolderSelected)
//							.background(selectFolderCardBackground)
//							.frame(width: isFolderSelected ? 0 : nil)
//							.clipped()
//							.opacity(selectFolderBtnOpacity)
//							.scaleEffect(
//								selectFolderBtnOpacity < 1.0 ? 0.96 : 1.0
//							)
//							.offset(
//								y: selectFolderBtnOpacity < 1.0 ? 2 : 0
//							)
//							.animation(
//								selectFolderFadeEase,
//								value: selectFolderBtnOpacity
//							)
//							.animation(
//								selectFolderFadeEase,
//								value: isFolderSelected
//							)
//						}
//					}
//					HStack(spacing: buttonSpacing) {
//						if isScanBtnExpanded {
//							Button(action: scanButtonActions) {
//								Text(primaryTitle)
//									.font(.system(size: 12, weight: .regular))
//									.padding(.horizontal, 10)
//									.padding(.vertical, 4)
//							}
//							.buttonStyle(.glassProminent)
//							.controlSize(.large)
//							.disabled(!isEnabled)
//							.glassEffectID("glassPrimary", in: namespace)
//							.frame(minWidth: 10)
//						}
//						if isClearBtnExpanded {
//							Button(action: clearButtonActions) {
//								Text(secondaryTitle)
//									.font(.system(size: 12, weight: .regular))
//									.padding(.horizontal, 10)
//									.padding(.vertical, 4)
//							}
//							.padding(1)
//							.buttonStyle(.glass)
//							.controlSize(.large)
//							.disabled(!isEnabled)
//							.glassEffectID("glassSecondary", in: namespace)
//							.frame(minWidth: 10)
//						}
//					}
//				}
//			}
//		}
//		.onAppear {
//			updateSelectFolderVisibility(animated: false)
//		}
//		.onChange(of: isFolderSelected) { _, isSelected in
//			updateSelectFolderVisibility(animated: true)
//		}
//	}
//
//	private func toggleExpanded() {
//		if isScanBtnExpanded || isClearBtnExpanded {
//			collapseExpanded()
//			//selectFolderBtnOpacity = 1.0
//		}
//	}
//
//	private func selectFolderButtonActions() {
//		if isScanBtnExpanded || isClearBtnExpanded {
//			selectButtonTask?.cancel()
//			scanButtonTask?.cancel()
//			clearButtonTask?.cancel()
//			withAnimation(.bouncy) {
//				collapseExpanded()
//			}
//		} else {
//			selectButtonTask = Task { @MainActor in
//				try? await Task.sleep(for: .seconds(0.1))
//				withAnimation(.bouncy) {
//					isClearBtnExpanded = true
//					isScanBtnExpanded = true
//				}
//				try? await Task.sleep(for: .seconds(0.2))
//				glassSpacing = 10
//				buttonSpacing = 10
//			}
//			onPrimary()
//		}
//	}
//	private func scanButtonActions() {
//
//		scanButtonTask?.cancel()
//		scanButtonTask = Task { @MainActor in
//			try? await Task.sleep(for: .seconds(0.1))
//			withAnimation(.bouncy) {
//				isSelectBtnExpanded = false
//			}
//			try? await Task.sleep(for: .seconds(0.1))
//			withAnimation(.bouncy) {
//				//isClearBtnExpanded = true
//				//isScanBtnExpanded = true
//			}
//			onSecondary()
//		}
//	}
//	private func clearButtonActions() {
//		clearButtonTask?.cancel()
//		clearButtonTask = Task { @MainActor in
//			try? await Task.sleep(for: .seconds(0.1))
//			withAnimation(.bouncy) {
//				isScanBtnExpanded = false
//			}
//			try? await Task.sleep(for: .seconds(0.2))
//			withAnimation(.bouncy) {
//				isClearBtnExpanded = false
//				isSelectBtnExpanded = true
//			}
//			onTertiary()
//		}
//	}
//
//	private func collapseAll() {
//		scanButtonTask?.cancel()
//		clearButtonTask?.cancel()
//		withAnimation(.bouncy) {
//			isSelectBtnExpanded = false
//		}
//		collapseAllTask = Task { @MainActor in
//			try? await Task.sleep(for: .seconds(0.1))
//			withAnimation(.bouncy) {
//				toggleExpanded()
//			}
//		}
//	}
//
//	private func collapseExpanded() {
//		scanButtonTask?.cancel()
//		clearButtonTask?.cancel()
//		glassSpacing = defaultGlassSpacing
//		buttonSpacing = defaultButtonSpacing
//		withAnimation(.bouncy) {
//			isScanBtnExpanded = false
//			isClearBtnExpanded = false
//			isSelectBtnExpanded = !isFolderSelected
//		}
//		updateSelectFolderVisibility(animated: false)
//	}
//
//	@ViewBuilder
//	private var selectFolderCardBackground: some View {
//		let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
//		if #available(macOS 26.0, iOS 26.0, *) {
//			shape
//				.fill(Color.white.opacity(0.12))
//				.glassEffect(.regular, in: shape)
//				.padding(4)
//		} else {
//			shape
//				.fill(.ultraThinMaterial)
//				.padding(4)
//		}
//	}
//
//	private func updateSelectFolderVisibility(animated: Bool) {
//		spacingUpdateTask?.cancel()
//		if animated {
//			withAnimation(selectFolderFadeEase) {
//				selectFolderBtnOpacity = isFolderSelected ? 0.0 : 1.0
//			}
//		} else {
//			selectFolderBtnOpacity = isFolderSelected ? 0.0 : 1.0
//		}
//
//		if isFolderSelected {
//			spacingUpdateTask = Task { @MainActor in
//				if animated {
//					try? await Task.sleep(for: .seconds(selectFolderFadeDuration))
//				}
//				withAnimation(selectFolderFadeEase) {
//					glassSpacing = compactSpacing + 10
//					buttonSpacing = compactSpacing + 10
//				}
//			}
//		} else {
//			withAnimation(animated ? selectFolderFadeEase : nil) {
//				glassSpacing = defaultGlassSpacing
//				buttonSpacing = defaultButtonSpacing
//			}
//		}
//	}
//}
//
//struct ExpandingButtonsAvailabilityAdapter: View {
//	let primaryTitle: String
//	let secondaryTitle: String
//	let isEnabled: Bool
//	let isFolderSelected: Bool
//	let onPrimary: () -> Void
//	let onSecondary: () -> Void
//	let onTertiary: () -> Void
//
//	var body: some View {
//		if #available(macOS 26.0, *) {
//			ExpandingButtonsGlass(
//				primaryTitle: primaryTitle,
//				secondaryTitle: secondaryTitle,
//				isEnabled: isEnabled,
//				isFolderSelected: isFolderSelected,
//				onPrimary: onPrimary,
//				onSecondary: onSecondary,
//				onTertiary: onTertiary
//			)
//		} else {
//			ExpandingButtonsFallback(
//				primaryTitle: primaryTitle,
//				secondaryTitle: secondaryTitle,
//				isEnabled: isEnabled,
//				isFolderSelected: isFolderSelected,
//				onPrimary: onPrimary,
//				onSecondary: onSecondary,
//				onTertiary: onTertiary
//			)
//		}
//	}
//}
//
//struct ExpandingButtonsFallback: View {
//	let primaryTitle: String
//	let secondaryTitle: String
//	let isEnabled: Bool
//	let isFolderSelected: Bool
//	let onPrimary: () -> Void
//	let onSecondary: () -> Void
//	let onTertiary: () -> Void
//
//	@State private var isExpanded = false
//
//	var body: some View {
//		HStack(spacing: 16) {
//			if isExpanded {
//				Button(primaryTitle) {
//					guard isEnabled else { return }
//					onPrimary()
//				}
//				.disabled(!isEnabled)
//				Button(secondaryTitle) {
//					guard isEnabled else { return }
//					onSecondary()
//				}
//				.disabled(!isEnabled)
//			}
//			ZStack(alignment: .topTrailing) {
//				Button {
//					withAnimation(.spring(response: 0.4, dampingFraction: 0.8))
//					{
//						isExpanded.toggle()
//					}
//				} label: {
//					Image(systemName: isExpanded ? "xmark" : "plus")
//						.frame(width: 44, height: 44)
//				}
//				.buttonStyle(.borderedProminent)
//				.buttonBorderShape(.capsule)
//				.opacity(isFolderSelected ? 0.0 : 1.0)
//				.allowsHitTesting(!isFolderSelected)
//			}
//		}
//		.padding(12)
//		.background(
//			RoundedRectangle(cornerRadius: 16, style: .continuous)
//				.fill(.ultraThinMaterial)
//		)
//	}
//}

#Preview("ExpandingButtons") {
	struct PreviewHost: View {

		var body: some View {
			ExpandingJuiceButtonsAvailabilityAdapter(
				primaryTitle: "Scan Folder",
				secondaryTitle: "Clear",
				isEnabled: true,
				isFolderSelected: false,
				onPrimary: {},
				onSecondary: {}
			)
			.frame(width: 500, height: 200, alignment: .leading)
			.preferredColorScheme(.light)
			.background(
				// A background is needed to see the blur/reflection effect
				LinearGradient(
					gradient: Gradient(colors: [.blue, .purple]),
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
		}

	}

	return PreviewHost()
}

#Preview("Expandable") {
	struct PreviewHost: View {

		var body: some View {
			ExpandableJuiceMenuAvailabilityAdapter(
				primaryTitle: "Upload to UEM",
				secondaryTitle: "Download Only",
				isEnabled: true,
				queueCount: 3,
				onPrimary: {},
				onSecondary: {}
			)
			.frame(width: 300, height: 400)
			.preferredColorScheme(.light)
			.background(
				// A background is needed to see the blur/reflection effect
				LinearGradient(
					gradient: Gradient(colors: [.blue, .purple]),
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
		}

	}

	return PreviewHost()
}

@available(macOS 26.0, *)
#Preview("Test") {
	struct PreviewHost: View {
		@State private var isExpanded: Bool = false
		@Namespace private var namespace
		@State private var isAllExpanded: Bool = false
		var body: some View {
			ZStack {
				GlassEffectContainer(spacing: 5) {
					HStack(spacing: 5.0) {
						if isExpanded {
							Button(action: {
								withAnimation(.bouncy) {
									isExpanded.toggle()
								}
								Task { @MainActor in
									try? await Task.sleep(for: .seconds(0.2))
									withAnimation(.bouncy) {
										isAllExpanded.toggle()
									}
								}
							}) {
								Image(systemName: "scribble.variable")
									.frame(width: 10, height: 10)
									.padding(2)
							}
							.buttonStyle(.glass)
							.controlSize(.mini)
							.buttonBorderShape(.circle)
						}
						if isAllExpanded && isExpanded {
							Button(action: {
								withAnimation(.bouncy) {
									isExpanded.toggle()
								}
								Task { @MainActor in
									try? await Task.sleep(for: .seconds(0.2))
									withAnimation(.bouncy) {
										isAllExpanded.toggle()
									}
								}
							}) {
								Image(systemName: "eraser.fill")
									.frame(width: 10, height: 10)
									.padding(2)
							}
							.buttonStyle(.glass)
							.controlSize(.mini)
							.buttonBorderShape(.circle)
						}
						if !isAllExpanded && !isExpanded {
							Button(action: {
								withAnimation(.bouncy) {
									isExpanded.toggle()
								}
								Task { @MainActor in
									try? await Task.sleep(for: .seconds(0.2))
									withAnimation(.bouncy) {
										isAllExpanded.toggle()
									}
								}
							}) {
								Image(systemName: "ellipsis")
									.frame(width: 10, height: 10)
									.padding(2)
							}
							.buttonStyle(.glass)
							.controlSize(.mini)
							.buttonBorderShape(.circle)
						}
					}.frame(
						alignment: .init(
							horizontal: .trailing,
							vertical: .bottom
						)
					)
				}
			}
			.frame(width: 300, height: 300, alignment: .bottom)
			.preferredColorScheme(.light)
			.background(
				// A background is needed to see the blur/reflection effect
				LinearGradient(
					gradient: Gradient(colors: [.blue, .purple]),
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
		}
	}
	return PreviewHost()
}

@available(macOS 26.0, *)
#Preview("ExpandableMenuGlassSplit") {
	struct PreviewHost: View {
		@State private var isExpanded: Bool = false
		@Namespace private var namespace
		@State private var isAllExpanded: Bool = false
		let queueCount: Int = 3
		var body: some View {
			ZStack {
				GlassEffectContainer(spacing: 40.0) {
					VStack(spacing: 40.0) {
						if isAllExpanded && isExpanded {
							Button(action: {}) {
								Text("Download")
									.font(.system(size: 12, weight: .semibold))
									.padding(.horizontal, 14)
									.padding(.vertical, 8)
							}
							.buttonStyle(.glass)
							//.disabled(!isEnabled)
							.glassEffect()
							.glassEffectID("1", in: namespace)
						}
						if isExpanded {
							Button(action: {}) {
								Text("Upload")
									.font(.system(size: 12, weight: .semibold))
									.padding(.horizontal, 14)
									.padding(.vertical, 8)
							}
							.buttonStyle(.glass)
							//.disabled(!isEnabled)
							.glassEffect()
							.glassEffectID("2", in: namespace)
						}
						ZStack(alignment: .topTrailing) {
							SingleGlassButtonImageRound(
								image: "JuiceLogo",
								buttonDiameter: 10
							) {
								withAnimation(.bouncy) {
									isExpanded.toggle()
								}
								Task { @MainActor in
									try? await Task.sleep(for: .seconds(0.2))
									withAnimation(.bouncy) {
										isAllExpanded.toggle()
									}
								}
							}
							.glassEffectID("toggle", in: namespace)

							if queueCount > 0 {
								Text("\(queueCount)")
									.font(.system(size: 9, weight: .bold))
									.foregroundStyle(Color.white)
									.frame(minWidth: 16, minHeight: 16)
									.background(
										Circle().fill(Color.accentColor)
									)
									.offset(x: 4, y: -4)
							}
						}
					}.frame(
						alignment: .init(horizontal: .center, vertical: .bottom)
					)
				}
			}
			.frame(width: 300, height: 300, alignment: .bottom)
			.background(
				// A background is needed to see the blur/reflection effect
				LinearGradient(
					gradient: Gradient(colors: [.blue, .purple]),
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
				.ignoresSafeArea()
			)
		}

	}

	return PreviewHost()
}
