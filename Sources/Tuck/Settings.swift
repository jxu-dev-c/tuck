import AppKit
import Carbon
import Foundation

struct Shortcut: Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    var displayString: String {
        var result = ""
        if (modifiers & UInt32(controlKey)) != 0 { result += "⌃" }
        if (modifiers & UInt32(optionKey)) != 0 { result += "⌥" }
        if (modifiers & UInt32(shiftKey)) != 0 { result += "⇧" }
        if (modifiers & UInt32(cmdKey)) != 0 { result += "⌘" }
        result += Self.keyName(for: keyCode)
        return result
    }

    static func from(event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let hasPrimaryModifier = !flags.intersection([.command, .option, .control]).isEmpty
        let isFunctionKey = Self.isFunctionKey(UInt32(event.keyCode))
        guard hasPrimaryModifier || isFunctionKey else { return nil }

        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
    }

    private static func isFunctionKey(_ code: UInt32) -> Bool {
        switch Int(code) {
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
             kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12:
            true
        default:
            false
        }
    }

    private static func keyName(for code: UInt32) -> String {
        switch Int(code) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_ANSI_Minus: "-"
        case kVK_ANSI_Equal: "="
        case kVK_ANSI_LeftBracket: "["
        case kVK_ANSI_RightBracket: "]"
        case kVK_ANSI_Backslash: "\\"
        case kVK_ANSI_Semicolon: ";"
        case kVK_ANSI_Quote: "'"
        case kVK_ANSI_Comma: ","
        case kVK_ANSI_Period: "."
        case kVK_ANSI_Slash: "/"
        case kVK_ANSI_Grave: "`"
        case kVK_Space: "Space"
        case kVK_Return: "↩"
        case kVK_Tab: "⇥"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default: "Key \(code)"
        }
    }
}

/// Thin wrapper over `UserDefaults`. Everything is computed so there's no cached global state.
enum Settings {
    static let toggleShortcutDidChangeNotification = Notification.Name("TuckToggleShortcutDidChange")

    private static var defaults: UserDefaults { .standard }

    private enum Key {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let isCollapsed = "isCollapsed"
        static let autoRehideDelay = "autoRehideDelay"
        static let toggleShortcut = "toggleShortcut"
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

    /// Optional global shortcut to toggle hidden menu bar items.
    static var toggleShortcut: Shortcut? {
        get {
            guard let dict = defaults.dictionary(forKey: Key.toggleShortcut),
                  let keyCode = dict["keyCode"] as? Int,
                  let modifiers = dict["modifiers"] as? Int else { return nil }
            return Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
        }
        set {
            if let newValue {
                defaults.set(["keyCode": Int(newValue.keyCode), "modifiers": Int(newValue.modifiers)], forKey: Key.toggleShortcut)
            } else {
                defaults.removeObject(forKey: Key.toggleShortcut)
            }
            NotificationCenter.default.post(name: toggleShortcutDidChangeNotification, object: nil)
        }
    }
}
