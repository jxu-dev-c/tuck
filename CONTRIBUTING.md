# Contributing

Thanks for helping out! Tuck aims to stay small, so please keep that in mind when proposing features.

## Setup

```sh
scripts/make-dev-cert.sh   # once: a stable signing identity, so macOS keeps permission grants across rebuilds
scripts/build-app.sh       # builds build/Tuck.app
pkill -x Tuck; open build/Tuck.app
```

For a quick compile check, `swift build` is enough. The app has to run as a bundle (`build-app.sh`) for status items and permissions to behave correctly.

To reset Tuck to its first-launch state:

```sh
pkill -x Tuck; defaults delete com.jasonxu.tuck
```

## Guidelines

- **Stay light.** No new dependencies, no SwiftUI or Combine, and no repeating timers or polling. Do work on demand and release it afterwards. Check with `footprint Tuck` and `top -pid $(pgrep -x Tuck)`; idle CPU should read 0.0%.
- **Zero warnings.** The package builds in Swift 6 language mode with strict concurrency.
- **Match the existing style:** AppKit built in code, `@MainActor` UI types, and short comments that explain *why*.
- **Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** before changing the collapse, scan or move logic.

## Pull requests

1. Keep each PR focused on one change.
2. Describe how you tested it. For example: reveal and hide, clicking a revealed item, moving an item in Settings, relaunching. Include your macOS version and whether your MacBook has a notch.
3. Include a screenshot for UI changes.

## Reporting bugs

Please include your macOS version, your display setup, and the items involved (app name plus the Settings row text). If moving an item failed, say what Settings displayed under the list.
