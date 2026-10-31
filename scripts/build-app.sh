#!/usr/bin/env bash
# Builds Tuck in release mode and assembles build/Tuck.app.
# Signs with the "Tuck Dev" identity if present (see make-dev-cert.sh) so macOS keeps
# Accessibility / Screen Recording grants across rebuilds; otherwise signs ad hoc.
#
# Optional environment (used by the release workflow):
#   VERSION=1.2.3          stamp the bundle version (defaults to Resources/Info.plist)
#   SIGN_IDENTITY="Name"   sign with this identity; fails if it isn't in the keychain
#   UNIVERSAL=1            build for arm64 and x86_64
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_ARGS=(-c release)
if [[ "${UNIVERSAL:-}" == 1 ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

swift build "${BUILD_ARGS[@]}"

APP="build/Tuck.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/Tuck" "$APP/Contents/MacOS/Tuck"
cp Resources/Info.plist "$APP/Contents/Info.plist"
strip -x "$APP/Contents/MacOS/Tuck"

if [[ -n "${VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
fi

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  IDENTITY="$SIGN_IDENTITY"
  if ! security find-identity -p codesigning 2>/dev/null | grep -q "\"$IDENTITY\""; then
    echo "error: signing identity \"$IDENTITY\" not found" >&2
    exit 1
  fi
elif security find-identity -p codesigning 2>/dev/null | grep -q '"Tuck Dev"'; then
  IDENTITY="Tuck Dev"
else
  IDENTITY="-"
  echo "note: signing ad hoc; permissions will need re-granting after each rebuild (run scripts/make-dev-cert.sh once to avoid this)"
fi
codesign --force --sign "$IDENTITY" --identifier com.jasonxu.tuck "$APP"
codesign --verify --strict "$APP"

echo "Built $APP ($(du -sh "$APP" | cut -f1)), signed with: $IDENTITY"
