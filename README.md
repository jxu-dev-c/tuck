# Tuck

**A tiny, native menu bar manager for macOS 26 Tahoe.** It hides the icons you don't need, and one click brings them back.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-blue)

| Collapsed | Expanded |
|---|---|
| ![Menu bar with items tucked away](docs/images/menubar-collapsed.png) | ![Menu bar with hidden items revealed](docs/images/menubar-expanded.png) |

## Features

- **Hide and reveal.** Click the arrow (`‹`) to bring hidden items back into the menu bar. They're the real items, so clicking one opens its own menu as usual. Click `›`, or just wait, to tuck them away again.
- **Choose what's hidden.** Settings lists every item under **Shown** and **Hidden**. Drag a row from one to the other and Tuck moves the real icon for you. You can also ⌘-drag icons past the thin `│` divider.
- **Auto-hide.** Revealed items hide again after a delay you choose (5 s to 1 min, or never). Tuck waits while a menu is open or your pointer is in the menu bar.
- **Launch at login.** One checkbox in Settings.
- **Featherweight.** AppKit only, with no dependencies and no background polling. About 20 MB of memory, 0% CPU when idle, and a 216 KB app bundle.

## Requirements

- macOS 26 Tahoe or later
- To build: Xcode 26 / Swift 6.3 command line tools

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask jxu-dev-c/tap/tuck
```

Upgrade with `brew upgrade --cask tuck`. Every release is signed with the same identity, so macOS keeps your permission grants across upgrades.

Prefer a manual install? Download `Tuck-<version>.zip` from [Releases](https://github.com/jxu-dev-c/tuck/releases), unzip it and move `Tuck.app` to `/Applications`. Tuck is self-signed rather than notarized, so clear the download quarantine before the first launch:

```sh
xattr -dr com.apple.quarantine /Applications/Tuck.app
```

### Build from source

```sh
git clone https://github.com/jxu-dev-c/tuck.git
cd tuck
scripts/build-app.sh          # produces build/Tuck.app
mv build/Tuck.app /Applications/
open /Applications/Tuck.app
```

On first launch, everything except Control Center and the clock is hidden, and Settings opens so you can pick what stays visible.

## Usage

| Action | Result |
|---|---|
| Click `‹` / `›` | Reveal / hide the hidden items |
| ⌥-click the arrow | Open Settings |
| Right-click the arrow | Menu: Show/Hide, Settings…, Quit |
| ⌘-drag an icon left of `│` | Hide it |
| ⌘-drag an icon right of `│` | Show it |

Hidden items stay revealed while Settings is open, so you can watch your changes happen.

## Permissions

| Permission | Needed for | Required? |
|---|---|---|
| **Accessibility** | Listing items in Settings and moving them for you | Only for the Settings list. Hiding and revealing work without it. |
| **Screen Recording** | Showing each item's real icon in Settings (instead of its app icon) | Optional |

Grant either one from the **Permissions** section in Settings.

> **Building from source?** macOS ties these grants to the app's code signature. Ad hoc builds get a new signature every time, so macOS forgets the grants after each rebuild. Run `scripts/make-dev-cert.sh` once to create a stable self-signed "Tuck Dev" identity. `build-app.sh` uses it automatically.

## Known limitations

- **Notched MacBooks:** if you reveal more items than fit beside the notch, macOS drops the extras. Keep fewer items hidden, or use an external display.
- **Control Center and the clock** are pinned by macOS. They can't be moved, so they don't appear in the list.
- **Settings takes about a second to open the list,** because Tuck asks every running app for its menu bar items. It only does this while Settings is open.
- **Only one menu bar.** On multiple displays, Tuck manages the menu bar on the main display.

## How it works

Tuck adds two items of its own to the menu bar: a divider `│` and an arrow `‹`. To hide items, it widens the divider to 10,000 points, which pushes everything to its left off the screen. To reveal them, it shrinks the divider back. Nothing is ever redrawn or proxied, so revealed items behave exactly like normal ones.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the details, including how Settings reads and moves items on macOS 26.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Acknowledgements

Inspired by [Bartender](https://www.macbartender.com), [Hidden Bar](https://github.com/dwarvesf/hidden) and [Ice](https://github.com/jordanbaird/Ice). Tuck is an independent project and isn't affiliated with any of them.

## License

[MIT](LICENSE) © 2026 Jason Xu
