#!/bin/bash
# Debug-only copy of build/Levels.app for the acoustic sync measurement: its own bundle
# id and a microphone usage string, so the real Levels never asks for the microphone.
#   ./build.sh && scripts/make_measure_app.sh
#   open build/LevelsMeasure.app --stdout /tmp/measure.log --args --sync-measure
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=build/Levels.app
DST=build/LevelsMeasure.app
rm -rf "$DST"
cp -R "$SRC" "$DST"
PLIST="$DST/Contents/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleIdentifier io.github.rafaelisdev.levels.measure" \
  -c "Set :CFBundleName Levels Measure" \
  -c "Set :CFBundleDisplayName Levels Measure" \
  -c "Add :NSMicrophoneUsageDescription string Levels Measure listens to short test clicks to see when each speaker really plays. Nothing is saved or sent." \
  "$PLIST"
codesign --force --sign - "$DST"
echo "Built $DST"
