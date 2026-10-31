import CoreGraphics

/// A snapshot of one menu bar item, read through Accessibility.
struct MenuBarItem: Sendable, Hashable {
    let id: String
    let pid: pid_t
    let appName: String
    let bundleID: String?
    let title: String
    /// CoreGraphics global coordinates (top-left origin of the primary display).
    let frame: CGRect
    /// Items macOS won't let you move (Control Center, clock).
    let isFixed: Bool

    var displayName: String {
        title == appName ? appName : "\(title) — \(appName)"
    }
}
