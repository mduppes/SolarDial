#!/bin/sh
# Builds a release binary and wraps it in an ad-hoc signed menu-bar app at build/Flux.app.
set -eu
cd "$(dirname "$0")/.."

APP_NAME="Flux"
BUNDLE_ID="com.mduppes.flux"
VERSION="0.1.0"
APP="build/$APP_NAME.app"

swift build -c release --product FluxApp
BIN="$(swift build -c release --show-bin-path)/FluxApp"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FluxApp"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FluxApp</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Flux switches macOS between Light and Dark Mode at sunrise and sunset, if you turn that on.</string>
    <key>NSLocationUsageDescription</key>
    <string>Flux uses your approximate location to work out local sunrise and sunset times. It never leaves your Mac.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Flux uses your approximate location to work out local sunrise and sunset times. It never leaves your Mac.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
