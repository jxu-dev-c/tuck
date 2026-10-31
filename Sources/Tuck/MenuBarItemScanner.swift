import AppKit
import ApplicationServices

/// Lists menu bar items by walking each app's `AXExtrasMenuBar`.
///
/// On macOS 26 every status item window is owned by Control Center in the window list, so window
/// ownership can't identify items; Accessibility still reports them per app. Only runs on demand.
enum MenuBarItemScanner {
    private struct AppInfo: Sendable {
        let pid: pid_t
        let name: String
        let bundleID: String?
    }

    /// Returns all items sorted left to right.
    @MainActor
    static func scan() async -> [MenuBarItem] {
        guard Permissions.hasAccessibility else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> AppInfo? in
            guard app.processIdentifier > 0, app.processIdentifier != me else { return nil }
            let name = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            return AppInfo(pid: app.processIdentifier, name: name, bundleID: app.bundleIdentifier)
        }
        return await Task.detached(priority: .userInitiated) { collect(apps) }.value
    }

    private static func collect(_ apps: [AppInfo]) -> [MenuBarItem] {
        let results = ResultBox()
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            results.append(items(for: apps[index]))
        }
        return deduplicated(results.items).sorted { $0.frame.minX < $1.frame.minX }
    }

    private static func items(for app: AppInfo) -> [MenuBarItem] {
        let appElement = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(appElement, 0.25)
        guard let bar: AXUIElement = attribute(appElement, "AXExtrasMenuBar"),
              let children: [AXUIElement] = attribute(bar, kAXChildrenAttribute) else { return [] }

        var seenKeys: [String: Int] = [:]
        return children.compactMap { child in
            guard let frame = frame(of: child), frame.width > 0, frame.height > 0 else { return nil }
            let identifier: String? = attribute(child, kAXIdentifierAttribute)
            let title = [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute]
                .lazy
                .compactMap { attribute(child, $0) as String? }
                .first { !$0.isEmpty } ?? app.name

            let key = identifier.flatMap { $0.isEmpty ? nil : $0 } ?? title
            let occurrence = seenKeys[key, default: 0]
            seenKeys[key] = occurrence + 1

            return MenuBarItem(
                id: "\(app.bundleID ?? app.name)|\(key)|\(occurrence)",
                pid: app.pid,
                appName: app.name,
                bundleID: app.bundleID,
                title: title,
                frame: frame,
                isFixed: isFixed(bundleID: app.bundleID, key: key)
            )
        }
    }

    private static func isFixed(bundleID: String?, key: String) -> Bool {
        guard bundleID == "com.apple.controlcenter" else { return false }
        let key = key.lowercased()
        return key.contains("controlcenter") || key.contains("control center") || key.contains("clock")
    }

    /// The same physical item can be reported by more than one process; keep one per position,
    /// preferring the owning app over Control Center.
    private static func deduplicated(_ items: [MenuBarItem]) -> [MenuBarItem] {
        var byPosition: [Int: MenuBarItem] = [:]
        for item in items {
            let slot = Int(item.frame.minX.rounded())
            if let existing = byPosition[slot], existing.bundleID != "com.apple.controlcenter" { continue }
            byPosition[slot] = item
        }
        return Array(byPosition.values)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = attribute(element, kAXPositionAttribute),
              let sizeValue: AXValue = attribute(element, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}

private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [MenuBarItem] = []

    func append(_ newItems: [MenuBarItem]) {
        guard !newItems.isEmpty else { return }
        lock.withLock { storage += newItems }
    }

    var items: [MenuBarItem] { lock.withLock { storage } }
}
