import AppKit
import ScreenCaptureKit

/// Grabs the real icon of each menu bar item. Only used by Settings, and only if Screen Recording
/// was granted; otherwise Settings falls back to app icons.
@MainActor
enum ItemImageCapture {
    static func images(for items: [MenuBarItem]) async -> [String: NSImage] {
        guard Permissions.hasScreenRecording, !items.isEmpty,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            return [:]
        }
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let windows = content.windows.filter { $0.windowLayer == statusLevel }
        let scale = NSScreen.main?.backingScaleFactor ?? 2

        var images: [String: NSImage] = [:]
        for item in items {
            guard let window = windows.first(where: {
                abs($0.frame.minX - item.frame.minX) < 2 && abs($0.frame.width - item.frame.width) < 2
            }) else { continue }

            let config = SCStreamConfiguration()
            config.width = Int(item.frame.width * scale)
            config.height = Int(item.frame.height * scale)
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true
            let filter = SCContentFilter(desktopIndependentWindow: window)
            if let cgImage = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) {
                images[item.id] = NSImage(cgImage: cgImage, size: item.frame.size)
            }
        }
        return images
    }
}
