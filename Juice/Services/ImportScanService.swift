import Foundation
#if os(macOS)
import AppKit
#endif

enum ImportScanService {
	actor SizeCache {
		private var cache: [String: Int64] = [:]

		func get(_ key: String) -> Int64? {
			cache[key]
		}

		func set(_ key: String, value: Int64) {
			cache[key] = value
		}

		func clear() {
			cache.removeAll()
		}
	}

	private static let sizeCache = SizeCache()

	static func scanFolder(rootURL: URL) async -> [ImportedApplication] {
		await Task.detached(priority: .userInitiated) {
			do {
				try ensureInstallerSubfolders(rootFolder: rootURL)
			} catch {
				// best-effort; continue scanning
			}

			var folders = getAllSubfolders(root: rootURL)
			folders = folders.filter { url in
				let name = url.lastPathComponent.lowercased()
				return name != "output" && name != "cache"
			}

			let rootFiles = (try? FileManager.default.contentsOfDirectory(
				at: rootURL,
				includingPropertiesForKeys: nil,
				options: [.skipsHiddenFiles]
			)) ?? []

			let hasRootInstallers = rootFiles.contains { url in
				let ext = url.pathExtension.lowercased()
				return ext == "pkg" || ext == "dmg" || ext == "zip"
			}
			if folders.isEmpty && hasRootInstallers {
				folders.append(rootURL)
			}

			var seenNamesByDirectory: [String: Set<String>] = [:]
			var results: [ImportedApplication] = []

			for folder in folders {
				let folderPath = folder.path
				var isDir: ObjCBool = false
				guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir), isDir.boolValue else {
					continue
				}

				if isAppBundle(url: folder) {
					let appNameOnly = folder.lastPathComponent
					let dirPath = folder.deletingLastPathComponent().path
					if !isUnique(name: appNameOnly, directoryPath: dirPath, map: &seenNamesByDirectory) {
						continue
					}
					if let imported = await buildImportedApplication(fileURL: folder) {
						results.append(imported)
					}
					continue
				}

				let fileEnumerator = FileManager.default.enumerator(
					at: folder,
					includingPropertiesForKeys: [.isDirectoryKey],
					options: [.skipsHiddenFiles, .skipsPackageDescendants]
				)

				var seenPaths: Set<String> = []

				while let fileURL = fileEnumerator?.nextObject() as? URL {
					let path = fileURL.path
					if !seenPaths.insert(path).inserted {
						continue
					}
					let parentName = fileURL.deletingLastPathComponent().lastPathComponent.lowercased()
					if parentName == "output" || parentName == "cache" {
						continue
					}
					if isValidInstaller(url: fileURL) {
						let fileNameOnly = fileURL.lastPathComponent
						let dirPath = fileURL.deletingLastPathComponent().path
						if !isUnique(name: fileNameOnly, directoryPath: dirPath, map: &seenNamesByDirectory) {
							continue
						}
						if let imported = await buildImportedApplication(fileURL: fileURL) {
							results.append(imported)
						}
					}
				}
			}

			return results.sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
		}.value
	}

	static func applyRecipeMatches(to apps: [ImportedApplication], recipes: [Recipe]) async -> [ImportedApplication] {
		guard !recipes.isEmpty else { return apps }
		if let aliasesURL = Bundle.main.url(forResource: "app_aliases", withExtension: "json") {
			try? await AppNameMatcher.loadAliases(aliasesURL)
		}

		var updated: [ImportedApplication] = []
		updated.reserveCapacity(apps.count)

		for app in apps {
			var mutable = app
			let candidateName = recipeCandidateName(for: app)
			if candidateName.isEmpty {
				updated.append(mutable)
				continue
			}

			let topCandidates = await AppNameMatcher.matchRecipes(candidateName: candidateName, recipes: recipes)

			if let selected = topCandidates.first {
				mutable.matchingRecipeCandidates = topCandidates
				mutable.matchingRecipeId = selected.identifier
				mutable.matchedOn = selected.matchedOn
				mutable.matchedScore = selected.score
				if let macApp = mutable.macApplication {
					macApp.matchingRecipeCandidates = topCandidates
					macApp.matchingRecipeId = selected.identifier
					macApp.matchedOn = selected.matchedOn
					macApp.matchedScore = selected.score
				}
			}

			updated.append(mutable)
		}

		return updated
	}

	private static func recipeCandidateName(for app: ImportedApplication) -> String {
		if let macApp = app.macApplication, let first = macApp.name.first, !first.isEmpty {
			return first
		}
		if let parsed = app.parsedMetadata {
			if let display = parsed.display_name, !display.isEmpty { return display }
			if let name = parsed.name, !name.isEmpty { return name }
		}
		return app.displayTitle
	}

	private static func isValidInstaller(url: URL) -> Bool {
		let ext = url.pathExtension.lowercased()
		return ext == "pkg" || ext == "dmg" || ext == "app"
	}

	private static func isAppBundle(url: URL) -> Bool {
		guard url.pathExtension.lowercased() == "app" else { return false }
		var isDir: ObjCBool = false
		return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
	}

	private static func isUnique(name: String, directoryPath: String, map: inout [String: Set<String>]) -> Bool {
		let key = directoryPath
		if map[key] == nil {
			map[key] = Set<String>()
		}
		if map[key]?.contains(name) == true {
			return false
		}
		map[key]?.insert(name)
		return true
	}

	private static func getAllSubfolders(root: URL) -> [URL] {
		var result: [URL] = []
		collectFoldersRecursive(folder: root, result: &result)
		return result
	}

	private static func collectFoldersRecursive(folder: URL, result: inout [URL]) {
		let subfolders = (try? FileManager.default.contentsOfDirectory(
			at: folder,
			includingPropertiesForKeys: [.isDirectoryKey],
			options: [.skipsHiddenFiles]
		)) ?? []
		for sub in subfolders {
			var isDir: ObjCBool = false
			guard FileManager.default.fileExists(atPath: sub.path, isDirectory: &isDir), isDir.boolValue else { continue }
			let name = sub.lastPathComponent.lowercased()
			if name == "output" || name == "cache" {
				continue
			}
			result.append(sub)
			if isAppBundle(url: sub) { continue }
			collectFoldersRecursive(folder: sub, result: &result)
		}
	}

	private static func buildImportedApplication(fileURL: URL) async -> ImportedApplication? {
		let fileName = fileURL.lastPathComponent
		let fileExtension = "." + fileURL.pathExtension
		let fullFilePath = fileURL.path
		let containingFolder = fileURL.deletingLastPathComponent()

		var hasMetadata = false
		var munkiMetadata: MunkiMetadata? = nil
		var macApplication: CaskApplication? = nil
		var iconPaths: [String] = []
		#if os(macOS)
		var availableIcons: [NSImage] = []
		#endif

		let outputFolder = containingFolder.appendingPathComponent("output", isDirectory: true)
		if FileManager.default.fileExists(atPath: outputFolder.path) {
			var metadata = MunkiMetadata()
			let outputFiles = (try? FileManager.default.contentsOfDirectory(
				at: outputFolder,
				includingPropertiesForKeys: nil,
				options: [.skipsHiddenFiles]
			)) ?? []
			for outputFile in outputFiles {
				let ext = outputFile.pathExtension.lowercased()
				if ["dmg", "pkg", "app"].contains(ext) {
					metadata.installerFile = outputFile.path
				}
				if ext == "plist" {
					metadata.installerPlist = outputFile.path
				}
				if ext == "png" {
					iconPaths.append(outputFile.path)
					metadata.iconFile = outputFile.path
					#if os(macOS)
					if let image = NSImage(contentsOf: outputFile) {
						availableIcons.append(image)
					}
					#endif
				}
			}
			if metadata.installerFile != nil || metadata.installerPlist != nil || metadata.iconFile != nil {
				hasMetadata = true
				munkiMetadata = metadata
			}
		}

		let metadataJSON = containingFolder.appendingPathComponent("metadata.json")
		if FileManager.default.fileExists(atPath: metadataJSON.path) {
			if let decoded = decodeCaskApplication(from: metadataJSON) {
				macApplication = decoded
			}
		}

		#if os(macOS)
		if fileExtension.lowercased() == ".app" {
			let icon = NSWorkspace.shared.icon(forFile: fullFilePath)
			availableIcons.append(icon)
		}
		#endif

		var item = ImportedApplication(
			fileName: fileName,
			fileExtension: fileExtension,
			fullFilePath: fullFilePath,
			hasMetadata: hasMetadata,
			munkiMetadata: munkiMetadata,
			macApplication: macApplication
		)
		item.availableIconPaths = iconPaths
		if let firstIcon = iconPaths.first {
			item.selectedIconPath = firstIcon
			item.selectedIconIndex = 0
		}
		if let plistPath = munkiMetadata?.installerPlist {
			item.parsedMetadata = DownloadUploadService.parseInstallerPlist(plistPath)
		}
		#if os(macOS)
		item.availableIcons = availableIcons
		#endif
		item.cachedFileSizeBytes = await computeFileSizeBytes(forPath: fileURL.path)
		return item
	}

	private static func decodeCaskApplication(from url: URL) -> CaskApplication? {
		guard let data = try? Data(contentsOf: url) else { return nil }
		do {
			let decoder = JSONDecoder()
			return try decoder.decode(CaskApplication.self, from: data)
		} catch {
			return nil
		}
	}

	static func computeFileSizeBytes(forPath path: String) async -> Int64? {
		if let cached = await cachedSize(forPath: path) {
			return cached
		}
		let computed: Int64? = await Task.detached(priority: .utility) {
			let fm = FileManager.default
			var isDir: ObjCBool = false
			guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
			if isDir.boolValue {
				var total: Int64 = 0
				if let enumerator = fm.enumerator(
					at: URL(fileURLWithPath: path),
					includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
					options: [.skipsHiddenFiles]
				) {
					while let next = enumerator.nextObject() as? URL {
						if let values = try? next.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
						   values.isRegularFile == true,
						   let fileSize = values.fileSize {
							total += Int64(fileSize)
						}
					}
				}
				return total
			}
			if let attrs = try? fm.attributesOfItem(atPath: path),
			   let size = attrs[.size] as? NSNumber {
				return size.int64Value
			}
			return nil
		}.value

		if let computed {
			await storeCachedSize(computed, forPath: path)
		}
		return computed
	}

	private static func cachedSize(forPath path: String) async -> Int64? {
		await sizeCache.get(path)
	}

	private static func storeCachedSize(_ size: Int64, forPath path: String) async {
		await sizeCache.set(path, value: size)
	}

	static func clearSizeCache() async {
		await sizeCache.clear()
	}

	private static func ensureInstallerSubfolders(rootFolder: URL) throws {
		let fm = FileManager.default
		let rootPath = rootFolder.path
		guard !rootPath.isEmpty, fm.fileExists(atPath: rootPath) else { return }

		let allDirs = [rootFolder] + (fm.enumerator(at: rootFolder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])?.compactMap { $0 as? URL } ?? [])

		for dir in allDirs {
			var isDir: ObjCBool = false
			guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
			let dirName = dir.lastPathComponent.lowercased()
			if dirName == "output" || dirName == "cache" {
				continue
			}

			let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
			let installerFiles = files.filter { url in
				let ext = url.pathExtension.lowercased()
				return ext == "pkg" || ext == "dmg"
			}
			let appBundles = files.filter { url in
				isAppBundle(url: url)
			}

			let totalItems = installerFiles.count + appBundles.count
			if totalItems <= 1 { continue }

			for file in installerFiles {
				let nameNoExt = file.deletingPathExtension().lastPathComponent
				guard !nameNoExt.isEmpty else { continue }
				var targetDir = dir.appendingPathComponent(nameNoExt, isDirectory: true)

				let currentParent = file.deletingLastPathComponent().path
				if currentParent == targetDir.path { continue }

				if fm.fileExists(atPath: targetDir.path) {
					var suffix = 1
					let base = targetDir
					while fm.fileExists(atPath: targetDir.path) {
						targetDir = URL(fileURLWithPath: base.path + "_\(suffix)")
						suffix += 1
					}
				}
				try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
				var destination = targetDir.appendingPathComponent(file.lastPathComponent)
				if fm.fileExists(atPath: destination.path) {
					var i = 1
					let baseName = file.deletingPathExtension().lastPathComponent
					let ext = file.pathExtension
					repeat {
						destination = targetDir.appendingPathComponent("\(baseName)_\(i).\(ext)")
						i += 1
					} while fm.fileExists(atPath: destination.path)
				}
				try fm.moveItem(at: file, to: destination)
			}

			for appPath in appBundles {
				let appNameNoExt = appPath.deletingPathExtension().lastPathComponent
				guard !appNameNoExt.isEmpty else { continue }
				var targetDir = dir.appendingPathComponent(appNameNoExt, isDirectory: true)

				let parent = appPath.deletingLastPathComponent().path
				if parent == targetDir.path { continue }

				if fm.fileExists(atPath: targetDir.path) {
					var suffix = 1
					let base = targetDir
					while fm.fileExists(atPath: targetDir.path) {
						targetDir = URL(fileURLWithPath: base.path + "_\(suffix)")
						suffix += 1
					}
				}
				try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
				var destination = targetDir.appendingPathComponent(appPath.lastPathComponent)
				if fm.fileExists(atPath: destination.path) {
					var i = 1
					let baseName = appPath.lastPathComponent
					repeat {
						destination = targetDir.appendingPathComponent("\(baseName)_\(i)")
						i += 1
					} while fm.fileExists(atPath: destination.path)
				}
				try fm.moveItem(at: appPath, to: destination)
			}
		}
	}
}
