# Architecture

Tuck is a single Swift package with one executable target and no dependencies. It runs as an accessory app (`LSUIElement`), so it has no Dock icon. Everything is AppKit; there's no SwiftUI or Combine, which keeps memory low.

## Source map

| File | Responsibility |
|---|---|
| `main.swift` | Bootstraps `NSApplication` with the `.accessory` policy |
| `AppDelegate.swift` | Seeds positions on first launch; creates and frees the Settings window |
| `MenuBarController.swift` | The arrow and divider status items, collapse/expand, auto-hide, arrow menu |
| `MenuBarItem.swift` | A value snapshot of one menu bar item (id, owner, title, frame) |
| `MenuBarItemScanner.swift` | Lists every menu bar item through Accessibility |
| `ItemMover.swift` | Moves an item with a synthetic ⌘-drag |
| `ItemImageCapture.swift` | Optional real-icon thumbnails via ScreenCaptureKit |
| `SettingsWindowController.swift` | Settings window: Shown/Hidden table with drag and drop, preferences, permissions |
| `Settings.swift` | `UserDefaults` wrapper |
| `Permissions.swift` | Accessibility and Screen Recording checks and requests |

## Hiding: the divider trick

```
[hidden items…]  │  ‹  [shown items…]  [Control Center] [clock]
                 ^  ^
           divider  arrow
```

- **Collapse:** set `divider.length = 10_000`. macOS lays status items out from the right, so a 10,000-point item pushes everything to its left off the screen.
- **Expand:** set `divider.length = NSStatusItem.variableLength`.

Revealed items are the apps' own status items, so clicks, menus and popovers work as they normally would. No events are forwarded.

**Guard:** before collapsing, Tuck checks that the divider is still left of the arrow. A user can ⌘-drag them past each other, and collapsing in that state would push the arrow off the screen too. If the order is wrong, Tuck refuses and shows a one-time alert.

**Persistence:** both items have an `autosaveName`, so macOS remembers where they sit. On first launch, Tuck seeds the `NSStatusItem Preferred Position <name>` defaults so the arrow (0) and divider (1) start out next to the system items.

## Auto-hide

Expanding schedules a single one-shot `Timer`. When it fires, Tuck runs one cheap check:

- If the pointer is in the menu bar strip, it reschedules for 2 s.
- If a window is open at `kCGPopUpMenuWindowLevel` (meaning a menu is showing), it reschedules for 2 s.
- Otherwise, it collapses.

No timer exists while collapsed or while Settings is open.

## Reading items (Settings)

On macOS 26, the window server reports every status item window as owned by Control Center, so window ownership can't identify items. Instead, `MenuBarItemScanner` does the following:

1. Snapshots `NSWorkspace.runningApplications` on the main actor.
2. Off the main thread, using `DispatchQueue.concurrentPerform`, reads each app's `AXExtrasMenuBar` children: position, size, identifier, and title/description/help. It uses a 0.25 s messaging timeout per app so a hung app can't stall the scan.
3. Drops zero-size placeholders and de-duplicates items reported by more than one process.
4. Marks Control Center's own icon and the clock as fixed.

An item's section comes from its position: items whose `midX` is left of the divider's `midX` are **Hidden**. That holds whether the bar is collapsed or expanded. Item IDs are `bundleID|AXIdentifier-or-title|occurrence`.

All coordinates use CoreGraphics global space (top-left origin), the same space Accessibility uses. Status item window frames are converted from Cocoa's bottom-left origin.

## Moving items

`ItemMover` replays what a person would do: ⌘ + mouse-down on the item, a few `leftMouseDragged` steps, then mouse-up. Afterwards it puts the cursor back where it was.

- To place an item **left of** a target, it drops at the target's `minX + 1`. To place it **right of** a target, it drops at `maxX - 1`. macOS swaps items when the cursor crosses an item's midpoint, so this works whichever direction the drag comes from.
- **Hidden** with no siblings means "left of the divider". **Shown** with no siblings means "right of the arrow".
- Settings keeps the bar expanded during a move. Afterwards it rescans to confirm the item landed in the right section, and retries once with fresh frames if it didn't.

## Staying light

- No repeating timers, observers or polling. At idle the process sleeps in the run loop.
- The Settings window, scan results and icon cache are created on demand and released when the window closes.
- ScreenCaptureKit is only touched if Screen Recording was already granted.
- Release builds use `-O`, `-dead_strip` and `strip -x`.
