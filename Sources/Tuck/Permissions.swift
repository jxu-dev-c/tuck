import AppKit
import ApplicationServices

enum Permissions {
    /// Needed to read menu bar items (AX) and to move them (synthesized ⌘-drags).
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Optional; only used to show the real item icons in Settings.
    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }

    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            openPrivacyPane("Privacy_Accessibility")
        }
    }

    static func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() {
            openPrivacyPane("Privacy_ScreenCapture")
        }
    }

    private static func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
