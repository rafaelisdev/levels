#!/bin/bash
# Publishes the version from Resources/Info.plist:
#   1. GitHub release vX.Y in OWNER/levels with Levels.zip (+ .sha256) and update.json,
#      which installed copies read to update themselves (zip signed, see sign_update.swift)
#   2. Casks/levels.rb in OWNER/homebrew-tap pointing at that release
# Needs `gh` logged in and the update signing key (LEVELS_UPDATE_KEY, default below).
# OWNER defaults to rafaelisdev.
set -euo pipefail
cd "$(dirname "$0")/.."

OWNER="${OWNER:-rafaelisdev}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" Resources/Info.plist)
KEY="${LEVELS_UPDATE_KEY:-$HOME/.config/levels/update-signing-key}"
PUBLIC_KEY=$(sed -n 's/.*static let publicKey = "\(.*\)".*/\1/p' Sources/Levels/Updater.swift)
[ -f "$KEY" ] || { echo "No update signing key at $KEY" >&2; exit 1; }

./build.sh release
SHA=$(cut -d' ' -f1 build/Levels.zip.sha256)
SIGNATURE=$(swift scripts/sign_update.swift sign "$KEY" build/Levels.zip "$PUBLIC_KEY")
cat > build/update.json <<JSON
{
  "version": "$VERSION",
  "url": "https://github.com/$OWNER/levels/releases/download/v$VERSION/Levels.zip",
  "signature": "$SIGNATURE",
  "minimumSystemVersion": "$MIN_OS"
}
JSON

# Releases ship from main (install.sh is served from there): fast-forward it to HEAD.
git push origin HEAD:main
NOTES="Install: \`brew install $OWNER/tap/levels\` or \`curl -fsSL https://raw.githubusercontent.com/$OWNER/levels/main/install.sh | bash\`"
# Optional release notes above the install line: RELEASE_NOTES=path/to/notes.md
[ -n "${RELEASE_NOTES:-}" ] && NOTES="$(cat "$RELEASE_NOTES")"$'\n\n'"$NOTES"
gh release create "v$VERSION" build/Levels.zip build/Levels.zip.sha256 build/update.json \
  --repo "$OWNER/levels" --target "$(git rev-parse HEAD)" --title "Levels $VERSION" --notes "$NOTES"

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
