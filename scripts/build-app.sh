#!/usr/bin/env bash
# Builds Tuck in release mode and assembles build/Tuck.app.
# Signs with the "Tuck Dev" identity if present (see make-dev-cert.sh) so macOS keeps
# Accessibility / Screen Recording grants across rebuilds; otherwise signs ad hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Tuck.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Tuck" "$APP/Contents/MacOS/Tuck"
cp Resources/Info.plist "$APP/Contents/Info.plist"
strip -x "$APP/Contents/MacOS/Tuck"

if security find-identity -p codesigning 2>/dev/null | grep -q '"Tuck Dev"'; then
  IDENTITY="Tuck Dev"
else
  IDENTITY="-"
  echo "note: signing ad hoc; permissions will need re-granting after each rebuild (run scripts/make-dev-cert.sh once to avoid this)"
fi
codesign --force --sign "$IDENTITY" --identifier com.jasonxu.tuck "$APP"

echo "Built $APP ($(du -sh "$APP" | cut -f1)), signed with: $IDENTITY"
