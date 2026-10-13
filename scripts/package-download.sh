#!/bin/sh
# Package the signed Apple silicon preview for the static landing page.
set -eu
cd "$(dirname "$0")/.."
APP="build/SolarDial.app"
OUTPUT="website/dist/downloads"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCH=$(lipo -archs "$APP/Contents/MacOS/SolarDialApp")
[ "$ARCH" = arm64 ] || { echo "Expected an Apple silicon build, got $ARCH" >&2; exit 1; }
codesign --verify --deep --strict "$APP"
mkdir -p "$OUTPUT"
ARCHIVE="SolarDial-$VERSION-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/$ARCHIVE"
(cd "$OUTPUT" && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
echo "Packaged $OUTPUT/$ARCHIVE"
