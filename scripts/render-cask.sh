#!/usr/bin/env bash
# Print the Homebrew cask for a release; CI writes it to jxu-dev-c/homebrew-tap as Casks/tuck.rb.
#
#   scripts/render-cask.sh VERSION SHA256
set -euo pipefail

VERSION="${1:?usage: render-cask.sh VERSION SHA256}"
SHA256="${2:?usage: render-cask.sh VERSION SHA256}"

cat <<EOF
cask "tuck" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/jxu-dev-c/tuck/releases/download/v#{version}/Tuck-#{version}.zip"
  name "Tuck"
  desc "Menu bar manager that hides icons until you need them"
  homepage "https://github.com/jxu-dev-c/tuck"

  depends_on macos: :tahoe

  app "Tuck.app"

  # signed with a self-signed identity, not notarized
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Tuck.app"],
                          writable_paths: ["Tuck.app"], writable_base: :appdir
  end

  uninstall quit: "com.jasonxu.tuck"

  zap trash: "~/Library/Preferences/com.jasonxu.tuck.plist"
end
EOF
