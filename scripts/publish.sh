#!/bin/bash
# Publishes the version from Resources/Info.plist:
#   1. GitHub release vX.Y in OWNER/levels with Levels.zip (+ .sha256)
#   2. Casks/levels.rb in OWNER/homebrew-tap pointing at that release
# Needs `gh` logged in. OWNER defaults to rafaelisdev.
set -euo pipefail
cd "$(dirname "$0")/.."

OWNER="${OWNER:-rafaelisdev}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

./build.sh release
SHA=$(cut -d' ' -f1 build/Levels.zip.sha256)

git push origin HEAD
gh release create "v$VERSION" build/Levels.zip build/Levels.zip.sha256 \
  --repo "$OWNER/levels" --title "Микшер $VERSION" \
  --notes "Установка: \`brew install $OWNER/tap/levels\` или \`curl -fsSL https://raw.githubusercontent.com/$OWNER/levels/main/install.sh | bash\`"

TAP="$(mktemp -d)"
trap 'rm -rf "$TAP"' EXIT
gh repo clone "$OWNER/homebrew-tap" "$TAP" -- --quiet
mkdir -p "$TAP/Casks"
sed -e "s/__OWNER__/$OWNER/g" -e "s/__VERSION__/$VERSION/g" -e "s/__SHA256__/$SHA/g" \
  packaging/levels.rb > "$TAP/Casks/levels.rb"
git -C "$TAP" add Casks/levels.rb
# Same author as this repo (its local git config), not the global identity.
git -C "$TAP" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
  commit -m "levels $VERSION" --quiet
git -C "$TAP" push --quiet
echo "Published v$VERSION. Install: brew install $OWNER/tap/levels"
