#!/bin/bash
# ./build.sh            build build/VolumeMixer.app (universal: Apple Silicon + Intel, macOS 11+)
# ./build.sh install    + copy to /Applications and start it
# ./build.sh release    + build/VolumeMixer.zip and .sha256 for GitHub Releases / Homebrew
#
# Signing: ad-hoc by default. With SIGN_IDENTITY="Developer ID Application: …" the app
# is signed with the hardened runtime, ready for notarization (see README).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/VolumeMixer.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/VolumeMixer"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VolumeMixer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] || swift scripts/make_icon.swift Resources/AppIcon.icns
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp \
    --entitlements Resources/VolumeMixer.entitlements --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
echo "Built $APP ($VERSION, $(lipo -archs "$APP/Contents/MacOS/VolumeMixer"))"

case "${1:-}" in
  install)
    pkill -x VolumeMixer 2>/dev/null || true
    rm -rf /Applications/VolumeMixer.app
    cp -R "$APP" /Applications/
    open /Applications/VolumeMixer.app
    echo "Installed to /Applications/VolumeMixer.app"
    ;;
  release)
    ZIP="build/VolumeMixer.zip"
    rm -f "$ZIP" "$ZIP.sha256"
    ditto -c -k --keepParent "$APP" "$ZIP"
    (cd build && shasum -a 256 VolumeMixer.zip > VolumeMixer.zip.sha256)
    echo "Release: $ZIP ($VERSION)"
    echo "sha256:  $(cut -d' ' -f1 "$ZIP.sha256")"
    ;;
esac
