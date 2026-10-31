import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    /// Created on demand and released when the window closes, so idle memory stays minimal.
    private var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let firstLaunch = !Settings.hasLaunchedBefore
        if firstLaunch {
            MenuBarController.seedInitialPositions()
        }

        menuBar = MenuBarController()
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }

        if firstLaunch {
            Settings.hasLaunchedBefore = true
            openSettings()
        } else {
            menuBar.restoreSavedState()
        }
    }

    private func openSettings() {
        if settings == nil {
            settings = SettingsWindowController(menuBar: menuBar) { [weak self] in
                // Defer so the controller isn't freed inside its own delegate callback.
                DispatchQueue.main.async { self?.settings = nil }
            }
        }
        settings?.show()
    }
}
