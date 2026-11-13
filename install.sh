#!/bin/bash
# Installs VolumeMixer (Микшер) from the latest GitHub release:
#   curl -fsSL https://raw.githubusercontent.com/rafaelisdev/volumemixer/main/install.sh | bash
set -euo pipefail

REPO="${VOLUMEMIXER_REPO:-rafaelisdev/volumemixer}"
URL="https://github.com/$REPO/releases/latest/download"
DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Скачиваю Микшер…"
curl -fsSL "$URL/VolumeMixer.zip" -o "$TMP/VolumeMixer.zip"
curl -fsSL "$URL/VolumeMixer.zip.sha256" -o "$TMP/VolumeMixer.zip.sha256"

expected="$(cut -d' ' -f1 "$TMP/VolumeMixer.zip.sha256")"
actual="$(shasum -a 256 "$TMP/VolumeMixer.zip" | cut -d' ' -f1)"
if [ "$expected" != "$actual" ]; then
  echo "Архив повреждён: контрольная сумма не совпала." >&2
  exit 1
fi

pkill -x VolumeMixer 2>/dev/null || true
rm -rf "$DEST/VolumeMixer.app"
ditto -x -k "$TMP/VolumeMixer.zip" "$DEST"
# Downloaded with curl, so there is normally no quarantine flag; clear it just in case.
xattr -dr com.apple.quarantine "$DEST/VolumeMixer.app" 2>/dev/null || true
open "$DEST/VolumeMixer.app"
echo "Готово: Микшер в строке меню ($DEST/VolumeMixer.app)."
