#!/bin/bash
# Installs Levels from the latest GitHub release:
#   curl -fsSL https://raw.githubusercontent.com/rafaelisdev/levels/main/install.sh | bash
set -euo pipefail

REPO="${LEVELS_REPO:-rafaelisdev/levels}"
URL="https://github.com/$REPO/releases/latest/download"
DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Levels…"
curl -fsSL "$URL/Levels.zip" -o "$TMP/Levels.zip"
curl -fsSL "$URL/Levels.zip.sha256" -o "$TMP/Levels.zip.sha256"

expected="$(cut -d' ' -f1 "$TMP/Levels.zip.sha256")"
actual="$(shasum -a 256 "$TMP/Levels.zip" | cut -d' ' -f1)"
if [ "$expected" != "$actual" ]; then
  echo "The download is damaged: checksum mismatch." >&2
  exit 1
fi

# The app used to be called VolumeMixer; remove the old copy so two don't run at once.
for old in "/Applications/VolumeMixer.app" "$HOME/Applications/VolumeMixer.app"; do
  if [ -d "$old" ]; then
    pkill -x VolumeMixer 2>/dev/null || true
    rm -rf "$old"
    echo "Removed the old version: $old"
  fi
done

pkill -x Levels 2>/dev/null || true
rm -rf "$DEST/Levels.app"
ditto -x -k "$TMP/Levels.zip" "$DEST"
# Downloaded with curl, so there is normally no quarantine flag; clear it just in case.
xattr -dr com.apple.quarantine "$DEST/Levels.app" 2>/dev/null || true
open "$DEST/Levels.app"
echo "Done: Levels is in the menu bar ($DEST/Levels.app)."
