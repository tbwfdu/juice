import SwiftUI

#if os(macOS)
import AppKit
#endif

func resolvedSymbolName(preferred: String, fallback: String) -> String {
	#if os(macOS)
	if NSImage(
		systemSymbolName: preferred,
		accessibilityDescription: nil
	) != nil {
		return preferred
	}
	return fallback
	#else
	return preferred
	#endif
}
