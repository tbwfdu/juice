import SwiftUI

struct EnvironmentListDisplay: View {
	let environments: [UemEnvironment]
	let activeEnvironmentUuid: String?
	let onSetActiveEnvironment: (UemEnvironment) -> Void
	let onEditEnvironment: (UemEnvironment) -> Void
	let onDeleteEnvironment: (UemEnvironment) -> Void
	let onAddEnvironment: () -> Void

	@Environment(\.colorScheme) private var colorScheme
	@State private var currentStackIndex: Int
	@State private var hoveredMenuEnvironmentId: UUID? = nil
	@State private var orgGroupLogos: [String: NSImage] = [:]
	@State private var orgGroupHighlightTints: [String: Color] = [:]
	@State private var orgGroupUsesConfiguredBranding: [String: Bool] = [:]
	private let configuredTintOpacity: CGFloat = 0.14
	private let neutralBaseOpacityLight: CGFloat = 0.94
	private let neutralBaseOpacityDark: CGFloat = 0.86
	private let materialOverlayOpacity: CGFloat = 0.55
	private let configuredBlurOverlayOpacity: CGFloat = 0.22
	private let unbrandedBlurOverlayOpacity: CGFloat = 0.34
	private let backgroundBlurRadius: CGFloat = 8

	private let ellipsisColor = Color(hex: JuiceStyleConfig.defaultTintHex)

	private let stackConfig = EnvironmentStackConfiguration(
		swipeMode: .enhanced,
		cardPadding: 24,
		scaleFactorPerCard: 0.085,
		rotationDegreesPerCard: 2.0,
		swipeThreshold: 180,
		springStiffness: 300,
		springDamping: 40,
		swingOutMultiplier: 15
	)

	init(
		environments: [UemEnvironment],
		activeEnvironmentUuid: String?,
		onSetActiveEnvironment: @escaping (UemEnvironment) -> Void = { _ in },
		onEditEnvironment: @escaping (UemEnvironment) -> Void = { _ in },
		onDeleteEnvironment: @escaping (UemEnvironment) -> Void = { _ in },
		onAddEnvironment: @escaping () -> Void = {}
	) {
		self.environments = environments
		self.activeEnvironmentUuid = activeEnvironmentUuid
		self.onSetActiveEnvironment = onSetActiveEnvironment
		self.onEditEnvironment = onEditEnvironment
		self.onDeleteEnvironment = onDeleteEnvironment
		self.onAddEnvironment = onAddEnvironment

		let initialIndex = EnvironmentListDisplay.index(
			for: activeEnvironmentUuid,
			in: environments
		)
		_currentStackIndex = State(initialValue: initialIndex)
	}

	var body: some View {
		VStack {
			if environments.isEmpty {
				ContentUnavailableView(
					"No Saved Environments",
					systemImage: "tray",
					description: Text(
						"Save an environment in Settings to display it here."
					)
				)
				.frame(maxWidth: .infinity, alignment: .center)
				.padding(.vertical, 8)
			} else {
				let cardWidth: CGFloat = 200
				let cardHeight: CGFloat = 220
				let stackVisibleCount = 4
				let stackPadding = stackConfig.cardPadding
				let stackSpan = CGFloat(max(1, stackVisibleCount - 1))
				let stackContentWidth =
					cardWidth + (stackPadding * stackSpan * 2)

				VStack(spacing: 8) {
					EnvironmentCardStack(
						items: environments,
						currentIndex: $currentStackIndex,
						visibleCount: stackVisibleCount,
						cardWidth: cardWidth,
						cardHeight: cardHeight,
						configuration: stackConfig,
						swipeEnabled: true
					) { environment, isTop, displayScale in
						environmentCard(
							environment: environment,
							isTop: isTop,
							displayScale: displayScale
						)
					}
					.frame(
						width: stackContentWidth,
						height: cardHeight,
						alignment: .center
					)

					ZStack(alignment: .trailing) {
						//VStack(alignment: .trailing, spacing: 0){
						HStack(spacing: 4) {
							Button {
								goToPrevious()
							} label: {
								Image(systemName: "chevron.left")
									.font(.system(size: 13, weight: .semibold))
									.frame(width: 18, height: 18)
							}
							.explicitRegularGlassButtonStyle(
								controlSize: .large
							)
							.modifier(
								FallbackDarkControlContrastBoost(
									colorScheme: colorScheme
								)
							)
							Button {
								goToNext()
							} label: {
								Image(systemName: "chevron.right")
									.font(.system(size: 13, weight: .semibold))
									.frame(width: 18, height: 18)
							}
							.explicitRegularGlassButtonStyle(
								controlSize: .large
							)
							.modifier(
								FallbackDarkControlContrastBoost(
									colorScheme: colorScheme
								)
							)
						}
						.padding(.top, 30)
						.frame(maxWidth: .infinity, alignment: .center)
						
						Button {
							onAddEnvironment()
						} label: {
							Image(systemName: "plus")
								.font(.system(size: 14, weight: .semibold))
								.frame(width: 18, height: 18)
						}
						.controlSize(.large)
						.modifier(AddEnvironmentButtonShapeModifier())
						.juiceGradientGlassProminentButtonStyle(
							controlSize: .large
						)
						.padding(.top, 30)
						
						.padding(.trailing, -5)
						//}
					}
					.padding(.horizontal, 10)
					.padding(.top, -45)
					.padding(.bottom, 8)
					//							.background {
					//								let shape = RoundedRectangle(
					//									cornerRadius: 16,
					//									style: .continuous
					//								)
					//								if #available(macOS 26.0, iOS 16.0, *) {
					//									ZStack {
					//										shape.fill(Color.white.opacity(0.12))
					//										GlassEffectContainer {
					//											shape
					//												.fill(Color.clear)
					//												.glassEffect(.regular, in: shape)
					//										}
					//									}
					//								} else {
					//									shape
					//										.fill(.ultraThinMaterial)
					//										.opacity(0.9)
					//								}
					//							}
					//							.overlay {
					//								RoundedRectangle(cornerRadius: 16, style: .continuous)
					//									.strokeBorder(Color.white.opacity(0.12))
					//							}
					.frame(width: cardWidth + 40)
				}
				.frame(maxWidth: .infinity, alignment: .top)
				.frame(height: 280)
			}
		}
		.onAppear {
			syncIndexWithActiveEnvironment()
			clampStackIndex()
		}
		.onChange(of: activeEnvironmentUuid) { _, _ in
			syncIndexWithActiveEnvironment()
		}
		.onChange(of: environments.map(\.id)) { _, _ in
			clampStackIndex()
		}
		.task(id: environments.map(\.orgGroupUuid).joined(separator: "|")) {
			await loadAllSavedBrandingAssets()
		}
		.onReceive(
			NotificationCenter.default.publisher(
				for: .orgGroupLogoDidUpdate
			)
		) { notification in
			guard let orgGroupUuid = notification.object as? String else {
				return
			}
			Task {
				await loadOrgGroupLogo(for: orgGroupUuid)
				await loadCachedHighlightTint(for: orgGroupUuid)
			}
		}
	}

	private func goToPrevious() {
		guard !environments.isEmpty else { return }
		withAnimation(
			.interpolatingSpring(
				stiffness: stackConfig.springStiffness,
				damping: stackConfig.springDamping
			)
		) {
			if currentStackIndex <= 0 {
				currentStackIndex = environments.count - 1
			} else {
				currentStackIndex -= 1
			}
		}
	}

	private func goToNext() {
		guard !environments.isEmpty else { return }
		withAnimation(
			.interpolatingSpring(
				stiffness: stackConfig.springStiffness,
				damping: stackConfig.springDamping
			)
		) {
			if currentStackIndex >= environments.count - 1 {
				currentStackIndex = 0
			} else {
				currentStackIndex += 1
			}
		}
	}

	private func clampStackIndex() {
		guard !environments.isEmpty else {
			currentStackIndex = 0
			return
		}
		currentStackIndex = max(
			0,
			min(currentStackIndex, environments.count - 1)
		)
	}

	private func syncIndexWithActiveEnvironment() {
		let targetIndex = EnvironmentListDisplay.index(
			for: activeEnvironmentUuid,
			in: environments
		)
		currentStackIndex = targetIndex
	}

	private static func index(
		for activeEnvironmentUuid: String?,
		in environments: [UemEnvironment]
	) -> Int {
		guard
			let uuid = activeEnvironmentUuid?.trimmingCharacters(
				in: .whitespacesAndNewlines
			),
			!uuid.isEmpty,
			let index = environments.firstIndex(where: {
				$0.orgGroupUuid.trimmingCharacters(in: .whitespacesAndNewlines)
					== uuid
			})
		else {
			return 0
		}
		return index
	}

	@ViewBuilder
	private func environmentCard(
		environment: UemEnvironment,
		isTop: Bool,
		displayScale: CGFloat
	) -> some View {
		let usesConfigured = usesConfiguredBranding(
			for: environment.orgGroupUuid
		)
		environmentPanel(
			highlightTint: highlightTint(for: environment.orgGroupUuid),
			useUnbrandedBorder: !usesConfigured,
			usesConfiguredBranding: usesConfigured
		) {
			VStack(alignment: .center) {
				let isActive = environment.orgGroupUuid == activeEnvironmentUuid
				HStack {
					Spacer()
					activeStatusPill(isActive: isActive)
				}
				.padding(.top, -10)
				.padding(.trailing, -5)
				.frame(height: 28, alignment: .trailing)
				.zIndex(1_000)
				.allowsHitTesting(false)
				ZStack {
					if let logoImage = orgGroupLogo(
						for: environment.orgGroupUuid
					) {
						Image(nsImage: logoImage)
							.resizable()
							.interpolation(.high)
							.antialiased(true)
							.aspectRatio(contentMode: .fit)
							//.scaledToFill()
							.frame(
								maxWidth: .infinity,
								maxHeight: .infinity,
								alignment: .center
							)
							.clipped()
					} else {
						Image(systemName: "photo.fill")
							.symbolRenderingMode(.multicolor)
							.symbolVariant(.none)
							.foregroundStyle(.quinary)
							.font(.system(size: 80, weight: .regular))
							.frame(
								maxWidth: .infinity,
								maxHeight: .infinity,
								alignment: .center
							)
					}
				}
				.clipShape(
					RoundedRectangle(cornerRadius: 10, style: .continuous)
				)
				.shadow(color: .black.opacity(0.09), radius: 8, x: 0, y: 4)
				.frame(maxWidth: .infinity, alignment: .center)
				.frame(height: 64, alignment: .center)
				//.padding(.vertical, 5)

				HStack(alignment: .firstTextBaseline) {
					Text(displayName(for: environment))
						.font(
							.system(size: 12, weight: .bold)
						)
						.lineLimit(1)
					Spacer()
					if isTop {
						environmentMenuButton(for: environment)
					} else {
						Color.clear
							.frame(width: 28, height: 24)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.bottom, -10)
				HStack(alignment: .firstTextBaseline) {
					Text(environment.uemUrl)
						.font(
							.system(size: 11, weight: .regular)
						)
						.foregroundStyle(.secondary)
						.lineLimit(1)
					Spacer()
				}

				Rectangle()
					.frame(height: 2)
					.clipped()
					.foregroundStyle(
						Color(hex: JuiceStyleConfig.defaultTintHex)
					)
					.padding(.trailing, 25)
				//.padding(.top, 2)

				VStack(spacing: 2) {
					HStack(alignment: .firstTextBaseline, spacing: 6) {
						Image(systemName: "list.bullet.rectangle")
							.font(
								.system(
									size: 11,
									weight: .medium,
									design: .default
								)
							)
							.foregroundStyle(
								Color(hex: JuiceStyleConfig.defaultTintHex)
							)
						Text(environment.orgGroupName)
							.font(
								.system(size: 11, weight: .regular)
							)
							.foregroundStyle(.secondary)
							.lineLimit(1)
						Spacer()
					}

					HStack(alignment: .firstTextBaseline, spacing: 6) {
						Image(systemName: "globe.asia.australia")
							.font(
								.system(
									size: 11,
									weight: .medium,
									design: .default
								)
							)
							.foregroundStyle(
								Color(hex: JuiceStyleConfig.defaultTintHex)
							)
						Text(
							returnRegion(url: environment.oauthRegion)
								?? environment.oauthRegion
						)
						.font(
							.system(size: 11, weight: .regular)
						)
						.foregroundStyle(.secondary)
						.lineLimit(1)
						Spacer()
					}
				}
				.padding(.top, 1)
			}
			.padding(.top, 16)
			.padding(.horizontal, 16)
			.padding(.bottom, 16)
		}
	}

	private func displayName(for environment: UemEnvironment) -> String {
		let trimmed = environment.friendlyName.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		return trimmed.isEmpty ? "Environment" : trimmed
	}

	private func orgGroupLogo(for orgGroupUuid: String) -> NSImage? {
		let key = orgGroupUuid.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return nil }
		return orgGroupLogos[key]
	}

	private func loadAllSavedBrandingAssets() async {
		await withTaskGroup(of: Void.self) { group in
			for environment in environments {
				group.addTask {
					await loadBrandingAssets(for: environment)
				}
			}
		}
	}

	private func loadBrandingAssets(for environment: UemEnvironment) async {
		let key = environment.orgGroupUuid.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		guard !key.isEmpty else { return }

		await loadOrgGroupLogo(for: key)
		await loadCachedHighlightTint(for: key, environment: environment)
	}

	private func loadOrgGroupLogo(for orgGroupUuid: String) async {
		#if os(macOS)
			let image = await UEMService.instance
				.loadOrgGroupLogoSourceFromFile(
					orgGroupUUID: orgGroupUuid
				)
			await MainActor.run {
				if let image {
					orgGroupLogos[orgGroupUuid] = image
				} else {
					orgGroupLogos.removeValue(forKey: orgGroupUuid)
				}
			}
		#endif
	}

	private func loadCachedHighlightTint(
		for orgGroupUuid: String,
		environment: UemEnvironment? = nil
	) async {
		let branding = await UEMService.instance
			.loadCachedOrgGroupBrandingConfig(
				orgGroupUUID: orgGroupUuid
			)
		let friendlyName = environment?.friendlyName.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let orgGroupName = environment?.orgGroupName.trimmingCharacters(
			in: .whitespacesAndNewlines
		)
		let resolvedFriendlyName =
			(friendlyName?.isEmpty == false)
			? (friendlyName ?? "Unknown") : "Unknown"
		let resolvedOrgGroupName =
			(orgGroupName?.isEmpty == false)
			? (orgGroupName ?? "Unknown") : "Unknown"
		let isDefaultBranding = isDefaultBrandingConfig(branding)
		let usesConfiguredBranding = branding != nil && !isDefaultBranding
		let brandingClass =
			usesConfiguredBranding ? "configured" : "defaultOrUnbranded"
		let borderStyle = usesConfiguredBranding ? "default" : "darkerDefault"
		let panelGlassMode = "material"
		let highlight =
			usesConfiguredBranding
			? highlightTint(from: branding?.brandingColor?.highlightColor) : nil
		let highlightApplied = highlight != nil
		appLog(
			.debug,
			LogCategory.environmentList,
			"Loaded branding config",
			event: "branding.load",
			metadata: [
				"friendly_name": resolvedFriendlyName,
				"org_group_name": resolvedOrgGroupName,
				"org_group_uuid": orgGroupUuid,
				"is_default_branding": String(isDefaultBranding),
				"branding_class": brandingClass,
				"border_style": borderStyle,
				"panel_glass_mode": panelGlassMode,
					"configured_tint_opacity": String(describing: configuredTintOpacity),
				"highlight_applied": String(highlightApplied)
			]
		)
		await MainActor.run {
			orgGroupUsesConfiguredBranding[orgGroupUuid] =
				usesConfiguredBranding
			if let highlight {
				orgGroupHighlightTints[orgGroupUuid] = highlight
			} else {
				orgGroupHighlightTints.removeValue(forKey: orgGroupUuid)
			}
		}
	}

	private func normalizedString(_ value: String?) -> String {
		value?
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased() ?? ""
	}

	private func normalizedHex(_ value: String?) -> String {
		value?
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.uppercased() ?? ""
	}

	private func isDefaultBrandingConfig(_ config: BrandingConfig?) -> Bool {
		guard let config else { return false }
		guard let colors = config.brandingColor else { return false }

		return normalizedString(config.themeCssUrl) == ""
			&& normalizedString(config.customCss) == ""
			&& normalizedString(config.primaryLogoUrl)
				== "https://www.omnissa.com/products/workspace-one-unified-endpoint-management"
			&& normalizedString(config.logoUrl) == ""
			&& normalizedHex(colors.headerColor) == "#002538"
			&& normalizedHex(colors.headerFontColor) == "#FFFFFF"
			&& normalizedHex(colors.navigationColor) == "#FFFFFF"
			&& normalizedHex(colors.navigationFontColor) == "#3C4653"
			&& normalizedHex(colors.highlightColor) == "#007CBB"
			&& normalizedHex(colors.highlightFontColor) == "#FFFFFF"
	}

	private func highlightTint(for orgGroupUuid: String) -> Color? {
		let key = orgGroupUuid.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return nil }
		return orgGroupHighlightTints[key]
	}

	private func usesConfiguredBranding(for orgGroupUuid: String) -> Bool {
		let key = orgGroupUuid.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !key.isEmpty else { return false }
		return orgGroupUsesConfiguredBranding[key] ?? false
	}

	@ViewBuilder
	private func environmentMenuButton(for environment: UemEnvironment)
		-> some View
	{
		Menu {
			Button {
				onEditEnvironment(environment)
			} label: {
				Label("Edit", systemImage: "rectangle.and.pencil.and.ellipsis")
			}

			if environment.orgGroupUuid != activeEnvironmentUuid {
				Button {
					onSetActiveEnvironment(environment)
				} label: {
					Label("Set Active", systemImage: "checkmark.circle.fill")
				}
			}

			Divider()

			Button(role: .destructive) {
				onDeleteEnvironment(environment)
			} label: {
				Label("Delete", systemImage: "trash")
			}
		} label: {
			Image(systemName: "ellipsis")
				.symbolRenderingMode(.monochrome)
				.foregroundColor(ellipsisColor)
				.opacity(
					hoveredMenuEnvironmentId == environment.id ? 1.0 : 0.82
				)
				.scaleEffect(
					hoveredMenuEnvironmentId == environment.id ? 1.1 : 1.0
				)
				.animation(
					.easeOut(duration: 0.14),
					value: hoveredMenuEnvironmentId == environment.id
				)
				.frame(width: 34, height: 28, alignment: .center)
				.contentShape(Rectangle())
				.onHover { isHovering in
					hoveredMenuEnvironmentId = isHovering ? environment.id : nil
				}
		}
		.buttonStyle(.plain)
		.menuIndicator(.hidden)
		.padding(.trailing, 0)
	}

	@ViewBuilder
	private func activeStatusPill(isActive: Bool) -> some View {
		let shape = Capsule(style: .continuous)
		HStack(spacing: 6) {
			Text("Active")
				.font(.subheadline)
			Image(systemName: "circle.fill")
				.font(.system(size: 11, weight: .medium))
				.foregroundStyle(.green)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 4)
		.frame(minHeight: 24)
		.background {
			ZStack {
				shape.fill(Color.clear)
				if #available(macOS 26.0, iOS 26.0, *) {
					GlassEffectContainer {
						shape.fill(Color.clear).glassEffect(.regular, in: shape)
					}
				} else {
					shape.fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
				}
			}
		}
		.overlay {
			shape.strokeBorder(.white.opacity(0.16))
		}
		.clipShape(shape)
		.compositingGroup()
		.opacity(isActive ? 1 : 0)
		.zIndex(1_000)
	}

	private func highlightTint(from rawValue: String?) -> Color? {
		guard let rawValue else { return nil }
		let sanitized = rawValue.trimmingCharacters(
			in: CharacterSet.alphanumerics.inverted
		)
		guard [3, 6, 8].contains(sanitized.count) else { return nil }
		return Color(hex: sanitized)
	}

	@ViewBuilder
	private func environmentPanel<Content: View>(
		highlightTint: Color?,
		useUnbrandedBorder: Bool,
		usesConfiguredBranding: Bool,
		@ViewBuilder content: () -> Content
	) -> some View {
		let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
		let neutralBase = colorScheme == .dark ? Color.black : Color.white
		let neutralBaseOpacity =
			colorScheme == .dark
			? neutralBaseOpacityDark : neutralBaseOpacityLight
		let blurOverlayOpacity =
			useUnbrandedBorder
			? unbrandedBlurOverlayOpacity : configuredBlurOverlayOpacity

		ZStack {
			// Opaque base prevents stacked cards from color-bleeding through each other.
			shape.fill(neutralBase.opacity(neutralBaseOpacity))
			shape
				.fill(neutralBase.opacity(blurOverlayOpacity))
				.blur(radius: backgroundBlurRadius)
			#if os(macOS)
				if #available(macOS 26.0, iOS 26.0, *) {
					shape.fill(.thinMaterial.opacity(materialOverlayOpacity))
				} else {
					shape.fill(
						Color(nsColor: .windowBackgroundColor).opacity(
							colorScheme == .dark ? 0.24 : 0.18
						)
					)
				}
			#else
				shape.fill(.thinMaterial.opacity(materialOverlayOpacity))
			#endif
			if let highlightTint, usesConfiguredBranding {
				shape.fill(highlightTint.opacity(configuredTintOpacity))
			}
			shape.strokeBorder(
				useUnbrandedBorder
					? Color.secondary.opacity(0.2) : Color.white.opacity(0.14),
				lineWidth: useUnbrandedBorder ? 1.35 : 1.0
			)
			if let highlightTint {
				shape
					.strokeBorder(highlightTint.opacity(0.45), lineWidth: 1.2)
					.blur(radius: 0.25)
			}
		}
		.allowsHitTesting(false)
		.overlay {
			content()
		}
		.clipShape(shape)
	}
}

private struct FallbackDarkControlContrastBoost: ViewModifier {
	let colorScheme: ColorScheme

	func body(content: Content) -> some View {
		#if os(macOS)
			if #available(macOS 26.0, *) {
				content
			} else if colorScheme == .dark {
				content
					.background(
						RoundedRectangle(cornerRadius: 9, style: .continuous)
							.fill(Color.white.opacity(0.20))
					)
			} else {
				content
			}
		#else
			content
		#endif
	}
}

private struct AddEnvironmentButtonShapeModifier: ViewModifier {
	func body(content: Content) -> some View {
		#if os(macOS)
			if #available(macOS 26.0, *) {
				content.buttonBorderShape(.circle)
			} else {
				content.buttonBorderShape(.automatic)
			}
		#else
			content.buttonBorderShape(.automatic)
		#endif
	}
}

private struct EnvironmentStackConfiguration {
	enum SwipeMode {
		case none
		case normal
		case enhanced
	}

	var swipeMode: SwipeMode = .none
	var cardPadding: CGFloat = 35.0
	var scaleFactorPerCard: CGFloat = 0.1
	var rotationDegreesPerCard: Double = 2.0
	var swipeThreshold: CGFloat = 200.0
	var springStiffness: Double = 300.0
	var springDamping: Double = 40.0
	var swingOutMultiplier: Double = 15.0
}

private struct EnvironmentCardStack<Item: Identifiable, CardContent: View>: View
{
	let items: [Item]
	@Binding var currentIndex: Int
	let visibleCount: Int
	let cardWidth: CGFloat
	let cardHeight: CGFloat
	let configuration: EnvironmentStackConfiguration
	let swipeEnabled: Bool
	let content: (Item, Bool, CGFloat) -> CardContent

	@State private var animatedIndex: Double
	@State private var previousIndex: Double

	init(
		items: [Item],
		currentIndex: Binding<Int>,
		visibleCount: Int = 4,
		cardWidth: CGFloat,
		cardHeight: CGFloat,
		configuration: EnvironmentStackConfiguration,
		swipeEnabled: Bool = true,
		@ViewBuilder content: @escaping (Item, Bool, CGFloat) -> CardContent
	) {
		self.items = items
		_currentIndex = currentIndex
		self.visibleCount = visibleCount
		self.cardWidth = cardWidth
		self.cardHeight = cardHeight
		self.configuration = configuration
		self.swipeEnabled = swipeEnabled
		self.content = content
		_animatedIndex = State(initialValue: Double(currentIndex.wrappedValue))
		_previousIndex = State(initialValue: Double(currentIndex.wrappedValue))
	}

	var body: some View {
		Group {
			if swipeEnabled {
				stackBody
					.simultaneousGesture(dragGesture, including: .gesture)
			} else {
				stackBody
			}
		}
		.onChange(of: currentIndex) { _, newValue in
			let clamped = clampedIndex(newValue)
			if clamped != newValue {
				currentIndex = clamped
			}
			withAnimation(
				.interpolatingSpring(
					stiffness: configuration.springStiffness,
					damping: configuration.springDamping
				)
			) {
				animatedIndex = Double(clamped)
				previousIndex = Double(clamped)
			}
		}
		.onChange(of: items.count) { _, _ in
			if items.isEmpty {
				animatedIndex = 0
				previousIndex = 0
				currentIndex = 0
				return
			}
			let clamped = clampedIndex(currentIndex)
			if clamped != currentIndex {
				currentIndex = clamped
			}
			animatedIndex = Double(clamped)
			previousIndex = Double(clamped)
		}
	}

	private var stackBody: some View {
		let span = CGFloat(max(1, visibleCount - 1))
		let contentWidth = cardWidth + (configuration.cardPadding * span * 2)

		return ZStack {
			ForEach(Array(items.enumerated()), id: \.element.id) {
				index,
				item in
				if shouldRender(index: index) {
					let itemScale = scale(for: index)
					content(
						item,
						index == topIndex && isSettledOnTopCard,
						itemScale
					)
					.frame(
						width: cardWidth,
						height: cardHeight,
						alignment: .top
					)
					.zIndex(zIndex(for: index))
					.offset(x: xOffset(for: index), y: 0)
					.scaleEffect(itemScale, anchor: .center)
					.rotationEffect(.degrees(rotationDegrees(for: index)))
				}
			}
		}
		.frame(width: contentWidth, height: cardHeight, alignment: .center)
	}

	private var dragGesture: some Gesture {
		DragGesture(minimumDistance: 16)
			.onChanged { value in
				guard !items.isEmpty else { return }
				withAnimation(.interactiveSpring()) {
					let x = (value.translation.width / 300) - previousIndex
					animatedIndex = clampedAnimatedIndex(-x)
					currentIndex = clampedIndex(Int(round(animatedIndex)))
				}
			}
			.onEnded { value in
				guard !items.isEmpty else { return }
				snapToNearestAbsoluteIndex(value.predictedEndTranslation)
				previousIndex = animatedIndex
			}
	}

	private func snapToNearestAbsoluteIndex(_ predictedEndTranslation: CGSize) {
		withAnimation(
			.interpolatingSpring(
				stiffness: configuration.springStiffness,
				damping: configuration.springDamping
			)
		) {
			let translation = predictedEndTranslation.width
			if abs(translation) > configuration.swipeThreshold {
				if translation > 0 {
					goTo(round(previousIndex) - 1)
				} else {
					goTo(round(previousIndex) + 1)
				}
			} else {
				let snapped = clampedAnimatedIndex(round(animatedIndex))
				animatedIndex = snapped
				currentIndex = clampedIndex(Int(snapped))
			}
		}
	}

	private func goTo(_ index: Double) {
		let clamped = clampedAnimatedIndex(index)
		animatedIndex = clamped
		currentIndex = clampedIndex(Int(clamped))
	}

	private func zIndex(for index: Int) -> Double {
		if configuration.swipeMode == .enhanced {
			if (Double(index) + 0.5) < animatedIndex {
				return -Double(items.count - index)
			}
			return Double(items.count - index)
		}
		if index < currentIndex {
			return -Double(items.count - index)
		}
		return Double(items.count - index)
	}

	private func xOffset(for index: Int) -> CGFloat {
		if configuration.swipeMode == .enhanced {
			let topCardProgress = currentPosition(for: index)
			let x =
				((CGFloat(index) - CGFloat(animatedIndex))
					* configuration.cardPadding)
			if topCardProgress > 0, topCardProgress < 0.99,
				index < (items.count - 1)
			{
				return x * swingOutMultiplier(topCardProgress)
			}
			return x
		}

		let indexValue =
			configuration.swipeMode == .normal
			? animatedIndex : Double(currentIndex)
		return
			((CGFloat(index) - CGFloat(indexValue)) * configuration.cardPadding)
	}

	private func scale(for index: Int) -> CGFloat {
		if configuration.swipeMode == .enhanced {
			return 1.0
				- (configuration.scaleFactorPerCard
					* abs(currentPosition(for: index)))
		}

		let indexValue =
			configuration.swipeMode == .normal
			? animatedIndex : Double(currentIndex)
		return 1.0
			- (configuration.scaleFactorPerCard
				* abs(CGFloat(index) - CGFloat(indexValue)))
	}

	private func rotationDegrees(for index: Int) -> Double {
		if index == topIndex {
			return 0
		}

		if configuration.swipeMode == .enhanced {
			return -currentPosition(for: index)
				* configuration.rotationDegreesPerCard
		}

		let indexValue =
			configuration.swipeMode == .normal
			? animatedIndex : Double(currentIndex)
		return -(indexValue - Double(index))
			* configuration.rotationDegreesPerCard
	}

	private func currentPosition(for index: Int) -> Double {
		animatedIndex - Double(index)
	}

	private func swingOutMultiplier(_ progress: Double) -> Double {
		sin(Double.pi * progress) * configuration.swingOutMultiplier
	}

	private var topIndex: Int {
		clampedIndex(Int(round(animatedIndex)))
	}

	private var isSettledOnTopCard: Bool {
		abs(animatedIndex - Double(topIndex)) < 0.01
	}

	private func shouldRender(index: Int) -> Bool {
		guard !items.isEmpty else { return false }
		let minIndex = max(0, topIndex - (visibleCount - 1))
		let maxIndex = min(items.count - 1, topIndex + (visibleCount - 1))
		return index >= minIndex && index <= maxIndex
	}

	private func clampedIndex(_ value: Int) -> Int {
		guard !items.isEmpty else { return 0 }
		return max(0, min(value, items.count - 1))
	}

	private func clampedAnimatedIndex(_ value: Double) -> Double {
		guard !items.isEmpty else { return 0 }
		let maxIndex = Double(items.count - 1)
		return max(0, min(value, maxIndex))
	}
}

func returnRegion(url: String) -> String? {
	switch url {
	case "https://na.uemauth.workspaceone.com":
		return "North America"
	case "https://uat.uemauth.workspaceone.com":
		return "UAT"
	case "https://apac.uemauth.workspaceone.com":
		return "APJ"
	case "https://emea.uemauth.workspaceone.com":
		return "EMEA"
	default:
		return nil
	}
}

private let environmentListDisplaySampleEnvironments: [UemEnvironment] = [
	UemEnvironment(
		friendlyName: "Production",
		uemUrl: "https://prod.awmdm.com",
		clientId: "client-prod",
		clientSecret: "secret-prod",
		oauthRegion: "https://na.uemauth.workspaceone.com",
		orgGroupName: "Prod OG",
		orgGroupId: "1001",
		orgGroupUuid: "1111-2222-3333-4444-5555"
	),
	UemEnvironment(
		friendlyName: "Staging",
		uemUrl: "https://staging.awmdm.com",
		clientId: "client-staging",
		clientSecret: "secret-staging",
		oauthRegion: "https://uat.uemauth.workspaceone.com",
		orgGroupName: "Staging OG",
		orgGroupId: "1002",
		orgGroupUuid: "1111-2222-3333-4444-6666"
	),
]

private struct EnvironmentListDisplaySavedDataPreview: View {
	private let environments: [UemEnvironment]
	private let activeEnvironmentUuid: String?
	private let previewSourceText: String

	init() {
		let preferredDefaults = UserDefaults(suiteName: "com.example.Juice")
		let store = SettingsStore(defaults: preferredDefaults ?? .standard)
		let state = store.load()
		let hasSavedEnvironments = !state.uemEnvironments.isEmpty

		environments =
			hasSavedEnvironments
			? state.uemEnvironments : environmentListDisplaySampleEnvironments
		activeEnvironmentUuid = state.activeEnvironmentUuid
		previewSourceText =
			hasSavedEnvironments
			? "Loaded \(state.uemEnvironments.count) saved environment(s)."
			: "Using sample fallback (no saved environments found)."
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			#if DEBUG
				Text(previewSourceText)
					.font(.caption)
					.foregroundStyle(.secondary)
			#endif

			EnvironmentListDisplay(
				environments: environments,
				activeEnvironmentUuid: activeEnvironmentUuid
			)
		}
		.frame(width: 500, height: 500, alignment: .bottom)
		.background(JuiceGradient())
	}
}

#Preview {
	EnvironmentListDisplay(
		environments: environmentListDisplaySampleEnvironments,
		activeEnvironmentUuid: "1111-2222-3333-4444-6666"
	)
	.frame(width: 500, height: 500, alignment: .bottom)
	.background(JuiceGradient())
}

#Preview("Saved Environments + Branding") {
	EnvironmentListDisplaySavedDataPreview()
}
