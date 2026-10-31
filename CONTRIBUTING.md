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

CI runs on every PR. It builds with warnings treated as errors, assembles a universal app bundle, and lints the scripts and workflows with `shellcheck` and `actionlint`. Both checks must pass before merging.

1. Keep each PR focused on one change.
2. Describe how you tested it. For example: reveal and hide, clicking a revealed item, moving an item in Settings, relaunching. Include your macOS version and whether your MacBook has a notch.
3. Include a screenshot for UI changes.

## Reporting bugs

Please include your macOS version, your display setup, and the items involved (app name plus the Settings row text). If moving an item failed, say what Settings displayed under the list.

## Releasing (maintainers)

Tag a commit on `main` and push the tag:

```sh
git tag v0.2.0 && git push origin v0.2.0
```

The [release workflow](.github/workflows/release.yml) then:

1. stamps the version from the tag into `Info.plist`,
2. builds a universal `Tuck.app` and signs it with the "Tuck Release" identity,
3. publishes a GitHub Release with `Tuck-<version>.zip` and generated notes,
4. writes `Casks/tuck.rb` to [jxu-dev-c/homebrew-tap](https://github.com/jxu-dev-c/homebrew-tap) (rendered by `scripts/render-cask.sh`).

To re-run a release, start the workflow manually from the Actions tab and give it the existing tag.

It needs these repository secrets:

| Secret | What it is |
|---|---|
| `SIGNING_CERT_P12` | base64 `.p12` of the self-signed "Tuck Release" identity |
| `SIGNING_CERT_PASSWORD` | the `.p12` export password |
| `HOMEBREW_TAP_TOKEN` | fine-grained PAT with Contents: read and write on `jxu-dev-c/homebrew-tap` |

The "Tuck Release" identity is backed up in the maintainer's login keychain. Keep it: macOS ties permission grants to the signing certificate, so a new one would make every user re-grant Accessibility and Screen Recording once.
