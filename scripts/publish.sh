#!/bin/bash
# Publishes the version from Resources/Info.plist:
#   1. GitHub release vX.Y in OWNER/volumemixer with VolumeMixer.zip (+ .sha256)
#   2. Casks/volumemixer.rb in OWNER/homebrew-tap pointing at that release
# Needs `gh` logged in. OWNER defaults to rafaelisdev.
set -euo pipefail
cd "$(dirname "$0")/.."

OWNER="${OWNER:-rafaelisdev}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

./build.sh release
SHA=$(cut -d' ' -f1 build/VolumeMixer.zip.sha256)

git push origin HEAD
gh release create "v$VERSION" build/VolumeMixer.zip build/VolumeMixer.zip.sha256 \
  --repo "$OWNER/volumemixer" --title "Микшер $VERSION" \
  --notes "Установка: \`brew install $OWNER/tap/volumemixer\` или \`curl -fsSL https://raw.githubusercontent.com/$OWNER/volumemixer/main/install.sh | bash\`"

TAP="$(mktemp -d)"
trap 'rm -rf "$TAP"' EXIT
gh repo clone "$OWNER/homebrew-tap" "$TAP" -- --quiet
mkdir -p "$TAP/Casks"
sed -e "s/__OWNER__/$OWNER/g" -e "s/__VERSION__/$VERSION/g" -e "s/__SHA256__/$SHA/g" \
  packaging/volumemixer.rb > "$TAP/Casks/volumemixer.rb"
git -C "$TAP" add Casks/volumemixer.rb
# Same author as this repo (its local git config), not the global identity.
git -C "$TAP" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
  commit -m "volumemixer $VERSION" --quiet
git -C "$TAP" push --quiet
echo "Published v$VERSION. Install: brew install $OWNER/tap/volumemixer"
