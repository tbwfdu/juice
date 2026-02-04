enum ConfirmationActionMode {
	case upload
	case download
	case uploadOnly

	var verb: String {
		switch self {
		case .upload, .uploadOnly: return "upload"
		case .download: return "download"
		}
	}

	var destinationText: String {
		switch self {
		case .upload, .uploadOnly: return "to Workspace ONE."
		case .download: return "to your local device."
		}
	}
}
