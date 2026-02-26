import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AppLogsWindowView: View {
	@ObservedObject private var store = AppLogStore.shared
	@State private var autoScroll = true
	@State private var levelFilter: LevelFilter = .all
	@State private var selectedCategory: String = "All"
	@State private var searchText = ""
	@State private var exportMessage: String?

	private enum LevelFilter: String, CaseIterable, Identifiable {
		case all = "All"
		case infoAndUp = "Info+"
		case warningAndUp = "Warnings+"
		case errorsOnly = "Errors"

		var id: String { rawValue }

		func allows(_ level: AppLogLevel) -> Bool {
			switch self {
			case .all:
				return true
			case .infoAndUp:
				return level.severity >= AppLogLevel.info.severity
			case .warningAndUp:
				return level.severity >= AppLogLevel.warning.severity
			case .errorsOnly:
				return level == .error
			}
		}
	}

	private var categories: [String] {
		let values = Set(store.entries.map(\.category)).sorted()
		return ["All"] + values
	}

	private var filteredEntries: [AppLogEntry] {
		store.entries.filter { entry in
			guard levelFilter.allows(entry.level) else { return false }
			guard selectedCategory == "All" || entry.category == selectedCategory else {
				return false
			}
			let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !needle.isEmpty else { return true }
			let haystack = [
				entry.category,
				entry.event ?? "",
				entry.message
			]
				.joined(separator: " ")
				.lowercased()
			return haystack.contains(needle.lowercased())
		}
	}

	private var warningCount: Int {
		filteredEntries.filter { $0.level == .warning }.count
	}

	private var errorCount: Int {
		filteredEntries.filter { $0.level == .error }.count
	}

	private var lastUpdateText: String {
		guard let timestamp = filteredEntries.last?.timestamp else { return "n/a" }
		return timestampString(for: timestamp)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 10) {
				Text("Juice Logs")
					.font(.title3.weight(.semibold))

				Spacer()

				Picker("Verbosity", selection: $store.verbosity) {
					ForEach(AppLogVerbosity.allCases) { verbosity in
						Text(verbosity.title).tag(verbosity)
					}
				}
				.pickerStyle(.segmented)
				.frame(width: 350)
				.juiceHelp(HelpText.Logs.verbosity)
			}

			Text("Logging verbosity and persisted log behavior are configured here. Logs are persisted with rotation in Application Support.")
				.font(.system(size: 11, weight: .regular))
				.foregroundStyle(.secondary)

			HStack(spacing: 8) {
				summaryChip("Warnings: \(warningCount)", color: .orange)
				summaryChip("Errors: \(errorCount)", color: .red)
				summaryChip("Last Update: \(lastUpdateText)", color: .secondary)
			}

			HStack(spacing: 10) {
				Picker("Level", selection: $levelFilter) {
					ForEach(LevelFilter.allCases) { filter in
						Text(filter.rawValue).tag(filter)
					}
				}
				.frame(width: 140)
				.juiceHelp(HelpText.Logs.levelFilter)

				Picker("Category", selection: $selectedCategory) {
					ForEach(categories, id: \.self) { category in
						Text(category).tag(category)
					}
				}
				.frame(width: 220)
				.juiceHelp(HelpText.Logs.categoryFilter)

				TextField("Search logs", text: $searchText)
					.textFieldStyle(.roundedBorder)
					.juiceHelp(HelpText.Logs.search)

				Toggle("Auto-scroll", isOn: $autoScroll)
					.toggleStyle(.switch)
					.controlSize(.small)
					.juiceHelp(HelpText.Logs.autoScroll)

				Button("Export") {
					do {
						let outputURL = try store.exportLogsSnapshot()
						#if os(macOS)
						NSWorkspace.shared.activateFileViewerSelecting([outputURL])
						#endif
						exportMessage = "Exported logs to \(outputURL.path)"
					} catch {
						exportMessage = "Failed to export logs: \(error.localizedDescription)"
					}
				}
				.nativeActionButtonStyle(.secondary, controlSize: .small)
				.juiceHelp(HelpText.Logs.export)

				Button("Clear") {
					store.clear()
				}
				.nativeActionButtonStyle(.secondary, controlSize: .small)
				.juiceHelp(HelpText.Logs.clearVisible)
			}

			Divider()

			if filteredEntries.isEmpty {
				ContentUnavailableView(
					"No Logs Yet",
					systemImage: "text.alignleft",
					description: Text("Log entries from Juice will appear here.")
				)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				ScrollViewReader { proxy in
					ScrollView {
						LazyVStack(alignment: .leading, spacing: 6) {
							ForEach(filteredEntries) { entry in
								logRow(entry)
									.id(entry.id)
							}
						}
						.padding(.vertical, 4)
					}
					.onChange(of: filteredEntries.count) { _, _ in
						guard autoScroll, let last = filteredEntries.last else { return }
						withAnimation(.easeOut(duration: 0.2)) {
							proxy.scrollTo(last.id, anchor: .bottom)
						}
					}
				}
			}
		}
		.padding(14)
		.frame(minWidth: 860, minHeight: 520)
		.background {
			let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
			if #available(macOS 26.0, iOS 26.0, *) {
				ZStack {
					shape.fill(Color.white.opacity(0.15))
					GlassEffectContainer {
						shape.fill(Color.clear).glassEffect(.regular, in: shape)
					}
				}
			} else {
				shape.fill(.ultraThinMaterial)
			}
		}
		.alert(
			"Logs",
			isPresented: Binding(
				get: { exportMessage != nil },
				set: { newValue in
					if !newValue {
						exportMessage = nil
					}
				}
			),
			presenting: exportMessage
		) { _ in
			Button("OK") {
				exportMessage = nil
			}
		} message: { message in
			Text(message)
		}
	}

	@ViewBuilder
	private func summaryChip(_ text: String, color: Color) -> some View {
		Text(text)
			.font(.system(size: 11, weight: .semibold))
			.foregroundStyle(color)
			.padding(.horizontal, 10)
			.padding(.vertical, 6)
			.background(
				Capsule(style: .continuous)
					.fill(Color.white.opacity(0.06))
			)
	}

	private func logRow(_ entry: AppLogEntry) -> some View {
		HStack(alignment: .top, spacing: 8) {
			Text(timestampString(for: entry.timestamp))
				.font(.system(size: 10, weight: .medium, design: .monospaced))
				.foregroundStyle(.secondary)
				.frame(width: 90, alignment: .leading)

			Text(entry.level.rawValue.uppercased())
				.font(.system(size: 10, weight: .semibold, design: .monospaced))
				.foregroundStyle(levelColor(entry.level))
				.frame(width: 66, alignment: .leading)

			Text("[\(entry.category)]")
				.font(.system(size: 10, weight: .semibold, design: .monospaced))
				.foregroundStyle(.secondary)
				.frame(width: 160, alignment: .leading)

			if let event = entry.event, !event.isEmpty {
				Text(event)
					.font(.system(size: 10, weight: .semibold, design: .monospaced))
					.foregroundStyle(.secondary)
					.frame(width: 160, alignment: .leading)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(entry.message)
					.font(.system(size: 11, weight: .regular, design: .monospaced))
					.frame(maxWidth: .infinity, alignment: .leading)
				if !entry.metadata.isEmpty {
					Text(
						entry.metadata
							.sorted { $0.key < $1.key }
							.map { "\($0.key)=\($0.value)" }
							.joined(separator: " ")
					)
					.font(.system(size: 10, weight: .regular, design: .monospaced))
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 5)
		.background(
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.fill(Color.white.opacity(0.04))
		)
	}

	private func levelColor(_ level: AppLogLevel) -> Color {
		switch level {
		case .debug:
			return .secondary
		case .info:
			return .blue
		case .warning:
			return .orange
		case .error:
			return .red
		}
	}

	private func timestampString(for date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm:ss"
		return formatter.string(from: date)
	}
}
