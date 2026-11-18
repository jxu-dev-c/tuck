import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let hotKeySignature: OSType = 0x5455_434B // 'TUCK'
    private var menuBar: MenuBarController!
    /// Created on demand and released when the window closes, so idle memory stays minimal.
    private var settings: SettingsWindowController?
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let firstLaunch = !Settings.hasLaunchedBefore
        if firstLaunch {
            MenuBarController.seedInitialPositions()
        }

        menuBar = MenuBarController()
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        setupHotKeySupport()

        if firstLaunch {
            Settings.hasLaunchedBefore = true
            openSettings()
        } else {
            menuBar.restoreSavedState()
        }
    }

    private func setupHotKeySupport() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated {
                    delegate.menuBar.toggle()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutSettingChanged),
            name: Settings.toggleShortcutDidChangeNotification,
            object: nil
        )
        updateHotKey()
    }

    @objc private func shortcutSettingChanged() {
        updateHotKey()
    }

    func updateHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        guard let shortcut = Settings.toggleShortcut else { return }
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: 1)
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
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
