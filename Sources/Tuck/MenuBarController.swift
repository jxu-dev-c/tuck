import AppKit

/// Owns Tuck's two status items and the hide/show behavior.
///
/// Layout, left to right: `[hidden items…] [│ divider] [‹ arrow] [shown items…]`.
/// Collapsing widens the divider to `collapsedLength`, which pushes everything to its left off-screen.
@MainActor
final class MenuBarController {
    private static let arrowName = "TuckArrow"
    private static let dividerName = "TuckDivider"
    private static let collapsedLength: CGFloat = 10_000

    private let arrow: NSStatusItem
    private let divider: NSStatusItem
    private var rehideTimer: Timer?
    /// While > 0 (e.g. Settings is open) the section stays expanded and auto-rehide is suspended.
    private var holdCount = 0
    private var hasShownGuardAlert = false

    private(set) var isCollapsed = false
    var onOpenSettings: (() -> Void)?

    /// Places the arrow at the far right (just left of the system items) with the divider beside it,
    /// so everything else starts out hidden.
    static func seedInitialPositions() {
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: "NSStatusItem Preferred Position \(arrowName)")
        defaults.set(1, forKey: "NSStatusItem Preferred Position \(dividerName)")
        defaults.set(true, forKey: "NSStatusItem Visible \(arrowName)")
        defaults.set(true, forKey: "NSStatusItem Visible \(dividerName)")
    }

    init() {
        let bar = NSStatusBar.system
        divider = bar.statusItem(withLength: NSStatusItem.variableLength)
        divider.autosaveName = Self.dividerName
        arrow = bar.statusItem(withLength: NSStatusItem.variableLength)
        arrow.autosaveName = Self.arrowName

        if let button = divider.button {
            button.image = Self.dividerImage
            button.appearsDisabled = true
            button.setAccessibilityLabel("Tuck divider")
            button.toolTip = "⌘-drag items left of this divider to hide them"
        }
        if let button = arrow.button {
            button.target = self
            button.action = #selector(arrowClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateArrowImage()
    }

    func restoreSavedState() {
        guard Settings.isCollapsed else { return }
        // Status item windows get their final frames shortly after launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.collapse()
        }
    }

    // MARK: Frames (CoreGraphics global coordinates, top-left origin; same space as AX)

    var dividerFrame: CGRect? { Self.cgFrame(of: divider) }
    var arrowFrame: CGRect? { Self.cgFrame(of: arrow) }

    private static func cgFrame(of item: NSStatusItem) -> CGRect? {
        guard let frame = item.button?.window?.frame,
              let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    // MARK: Expand / collapse

    func toggle() {
        if isCollapsed { expand(autoRehide: true) } else { collapse() }
    }

    func expand(autoRehide: Bool) {
        if isCollapsed {
            divider.length = NSStatusItem.variableLength
            divider.button?.image = Self.dividerImage
            isCollapsed = false
            Settings.isCollapsed = false
            updateArrowImage()
        }
        if autoRehide { scheduleRehide() }
    }

    func collapse() {
        cancelRehide()
        guard holdCount == 0, !isCollapsed else { return }
        guard dividerIsLeftOfArrow() else {
            showGuardAlert()
            return
        }
        divider.button?.image = nil
        divider.length = Self.collapsedLength
        isCollapsed = true
        Settings.isCollapsed = true
        updateArrowImage()
    }

    /// Keeps items revealed until a matching `endHold()`.
    func beginHold() {
        holdCount += 1
        cancelRehide()
        expand(autoRehide: false)
    }

    func endHold() {
        holdCount = max(0, holdCount - 1)
        if holdCount == 0 { collapse() }
    }

    private func dividerIsLeftOfArrow() -> Bool {
        guard let d = divider.button?.window?.frame, let a = arrow.button?.window?.frame else { return false }
        return d.maxX <= a.minX + 1
    }

    private func showGuardAlert() {
        guard !hasShownGuardAlert else { return }
        hasShownGuardAlert = true
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Move the divider left of the arrow"
        alert.informativeText = "Hold ⌘ and drag the thin │ divider so it sits to the left of Tuck's arrow. Items to the left of the divider are the ones that get hidden."
        alert.runModal()
    }

    // MARK: Auto-rehide (one-shot timer; nothing runs while idle)

    private func scheduleRehide(after delay: TimeInterval = Settings.autoRehideDelay) {
        cancelRehide()
        guard delay > 0, holdCount == 0 else { return }
        rehideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.rehideTimerFired() }
        }
        rehideTimer?.tolerance = 0.5
    }

    private func cancelRehide() {
        rehideTimer?.invalidate()
        rehideTimer = nil
    }

    private func rehideTimerFired() {
        rehideTimer = nil
        if shouldDeferRehide() {
            scheduleRehide(after: 2)
        } else {
            collapse()
        }
    }

    /// Don't yank items away while the user is in the menu bar or a menu is open.
    private func shouldDeferRehide() -> Bool {
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            let barHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
            if mouse.y >= screen.frame.maxY - barHeight { return true }
        }
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLevel }
    }

    // MARK: Arrow

    @objc private func arrowClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showArrowMenu()
        } else if event.modifierFlags.contains(.option) {
            onOpenSettings?()
        } else {
            toggle()
        }
    }

    private func showArrowMenu() {
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: isCollapsed ? "Show Hidden Items" : "Hide Items", action: #selector(menuToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(menuSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Tuck", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        arrow.menu = menu
        arrow.button?.performClick(nil)
        arrow.menu = nil
    }

    @objc private func menuToggle() { toggle() }
    @objc private func menuSettings() { onOpenSettings?() }

    private func updateArrowImage() {
        let name = isCollapsed ? "chevron.left" : "chevron.right"
        let label = isCollapsed ? "Show hidden menu bar items" : "Hide menu bar items"
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)?.withSymbolConfiguration(config)
        image?.isTemplate = true
        arrow.button?.image = image
        arrow.button?.toolTip = "\(label) (⌥-click for Settings)"
    }

    private static let dividerImage: NSImage = {
        let image = NSImage(size: NSSize(width: 7, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 2.75, y: 1, width: 1.5, height: 14), xRadius: 0.75, yRadius: 0.75).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
