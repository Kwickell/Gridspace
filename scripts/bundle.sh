#!/bin/bash
# Builds build/Gridspace.app. Signs with the first Apple Development identity so the
# Accessibility grant survives rebuilds; set SIGN_IDENTITY=- for an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app=build/Gridspace.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Gridspace "$app/Contents/MacOS/Gridspace"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

# Marketing version from VERSION, build number from the commit count so every build is unique and increasing.
version="$(tr -d '[:space:]' < VERSION)"
build="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" -c "Set :CFBundleVersion $build" "$app/Contents/Info.plist"

identity="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
codesign --force --sign "${identity:--}" "$app"
echo "Built $app $version ($build), signed with ${identity:--}"
