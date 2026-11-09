#!/usr/bin/env bash
# Exercise real AppKit controllers in a temporary release app. Quit Tuck first.
# Usage: SIGN_IDENTITY="Tuck Release" scripts/profile-memory.sh [source-dir] [output-dir]
# The temporary app shares Tuck's preferences/permissions and restores collapse state on success.
set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE_DIR="${1:-Sources/Tuck}"
OUTPUT_DIR="${2:-build/memory-profile/current}"
if pgrep -x Tuck >/dev/null; then
  echo "Quit Tuck before profiling so its status items do not interfere with the test." >&2
  exit 1
fi
APP="$OUTPUT_DIR/Tuck.app"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
SOURCES=()
for source in "$SOURCE_DIR"/*.swift; do
  [[ "$(basename "$source")" == main.swift ]] || SOURCES+=("$source")
done
swiftc -O -swift-version 6 -warnings-as-errors -module-name Tuck \
  "${SOURCES[@]}" scripts/memory-profile/main.swift -o "$APP/Contents/MacOS/Tuck"
codesign --force --sign "${SIGN_IDENTITY:--}" --identifier com.jasonxu.tuck "$APP"
"$APP/Contents/MacOS/Tuck" --cancellation > "$OUTPUT_DIR/profile.log" 2>&1
echo "Profile complete: $OUTPUT_DIR/profile.log"
