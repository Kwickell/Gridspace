#!/bin/bash
# Builds build/Gridspace.app. Signs with the first Apple Development identity so the
# Accessibility grant survives rebuilds; set SIGN_IDENTITY=- for an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app=build/Gridspace.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/Gridspace "$app/Contents/MacOS/Gridspace"
cp Resources/Info.plist "$app/Contents/Info.plist"

identity="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
codesign --force --sign "${identity:--}" "$app"
echo "Built $app (signed with ${identity:--})"
