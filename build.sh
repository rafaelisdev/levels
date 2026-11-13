#!/bin/bash
# ./build.sh            build build/Levels.app (universal: Apple Silicon + Intel, macOS 11+)
# ./build.sh install    + copy to /Applications and start it
# ./build.sh release    + build/Levels.zip and .sha256 for GitHub Releases / Homebrew
#
# Signing: ad-hoc by default. With SIGN_IDENTITY="Developer ID Application: …" the app
# is signed with the hardened runtime, ready for notarization (see README).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Levels.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/Levels"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Levels"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] || swift scripts/make_icon.swift Resources/AppIcon.icns
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp \
    --entitlements Resources/Levels.entitlements --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
echo "Built $APP ($VERSION, $(lipo -archs "$APP/Contents/MacOS/Levels"))"

case "${1:-}" in
  install)
    pkill -x Levels 2>/dev/null || true
    rm -rf /Applications/Levels.app
    cp -R "$APP" /Applications/
    open /Applications/Levels.app
    echo "Installed to /Applications/Levels.app"
    ;;
  release)
    ZIP="build/Levels.zip"
    rm -f "$ZIP" "$ZIP.sha256"
    ditto -c -k --keepParent "$APP" "$ZIP"
    (cd build && shasum -a 256 Levels.zip > Levels.zip.sha256)
    echo "Release: $ZIP ($VERSION)"
    echo "sha256:  $(cut -d' ' -f1 "$ZIP.sha256")"
    ;;
esac
