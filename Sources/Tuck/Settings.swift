import Foundation

/// Thin wrapper over `UserDefaults`. Everything is computed so there's no cached global state.
enum Settings {
    private static var defaults: UserDefaults { .standard }

    private enum Key {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let isCollapsed = "isCollapsed"
        static let autoRehideDelay = "autoRehideDelay"
    }

    static var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Key.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Key.hasLaunchedBefore) }
    }

    /// Whether the hidden section was collapsed when the app last ran.
    static var isCollapsed: Bool {
        get { defaults.object(forKey: Key.isCollapsed) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.isCollapsed) }
    }

    /// Seconds before revealed items hide again. `0` means never.
    static var autoRehideDelay: TimeInterval {
        get { defaults.object(forKey: Key.autoRehideDelay) as? TimeInterval ?? 10 }
        set { defaults.set(newValue, forKey: Key.autoRehideDelay) }
    }
}
