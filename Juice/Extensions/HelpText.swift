import Foundation

// All app tooltip/help strings live here.
enum HelpText {
	enum Actions {
		static let collapse = "Collapse"
		static let removeFromQueue = "Remove this app from the queue"
		static let viewDetails = "View details"
		static let addToQueue = "Add to queue"
		static let moreActions = "More actions"
		static let keepRunning = "Keep app running in the menu bar when the window is closed"
	}

	enum Updates {
		static let query =
			"Run a fresh query against Workspace ONE UEM to find available updates"
		static let clear =
			"Clear the current results"
		static let addSelected = "Add selected updatable apps to the queue"
		static let showAll = "Show all matched apps, including those without updates"
		static let selectAll = "Select all apps that currently have updates"
	}

	enum Import {
		static let selectAll = "Select all discovered apps"
		static let addSelected = "Add selected discovered apps to the queue"
		static let scan =
			"Scan the selected folder and for compatible applications and installers"
		static let clear = "Clear discovered apps from this view"
		static let toggleActions = "Show or hide scan actions"
	}

	enum Settings {
		static let darkMode = "Use dark mode"
		static let validateConfig =
			"Validate current device configuration"
		static let updateDatabase =
			"Refresh local app metadata from source"
		static let showLogs = "Open the logs window"
		static let openAdvanced = "Open advanced configuration options"
		static let resetConfiguration = "Reset app configuration to defaults"
		static let loggingVerbosity = "Control how much detail is captured in app logs"

		static func clientSecretToggle(isRevealed: Bool) -> String {
			isRevealed ? "Hide Client Secret" : "Reveal Client Secret"
		}
	}

	enum Queue {
		static let clearResults = "Clear queue results in this panel"
		static let pinPanel = "Pin or unpin this panel"
	}

	enum Inspector {
		static let togglePanel = "Show or hide side panel"

		static func pin(isPinned: Bool) -> String {
			isPinned ? "Unpin Panel" : "Pin Panel"
		}
	}

	enum Logs {
		static let autoScroll = "Automatically follow new log entries"
		static let clearVisible = "Clear log output in this window"
		static let levelFilter = "Filter logs by severity level"
		static let categoryFilter = "Filter logs by log category"
		static let search = "Filter logs by matching category, event, or message text"
		static let verbosity = "Choose how much detail Juice records in the logs"
		static let export = "Export currently captured logs to a file"
	}

	enum DownloadQueue {
		static let cancelMetadataEdits =
			"Cancel metadata changes and return to the queue"
		static let continueAfterEdits = "Save metadata changes and continue"
	}

	enum Pills {
		static let recipe = "A matching recipe was found for this app"
		static let hasUpdate =
			"A newer version is available for this application"
		static let laterVersionAdded =
			"This application has a newer version available, but a later version of this app is already present in Workspace ONE UEM"
		static let upToDate =
			"The highest Workspace ONE UEM version for this app matches the current catalog version"
		static let noMatches = "No matching app was found in the Juice database"
		static let inactive = "This app is not active in Workspace ONE UEM"
		static let installs =
			"Number of devices with this app installed in Workspace ONE UEM"
		static let assigned = "Number of devices assigned this app in Workspace ONE UEM"
		static let smartGroups =
			"Number of smart groups targeting this app"
		static let metadata = "Metadata was already available and was parsed from the installer directory"
		static let catalog = "This app matched an entry in the Juice catalog"
		static let filesystem =
			"This app was discovered from the filesystem but was not found in the Juice database"
		static let token = "Juice database token used to identify this app"
		static let fileType =
			"Installer file type"
	}
}
