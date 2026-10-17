#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app="$PWD/build/Sill.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Sill" "$app/Contents/MacOS/Sill"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/build/AppIcon.iconset"
iconutil -c icns "$PWD/build/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
# Prefer an existing Apple Development identity so Accessibility authorization
# remains tied to the developer + bundle ID, rather than each build's cdhash.
identity="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
    identity="$(security find-identity -v -p codesigning | sed -n 's/.*) \([A-F0-9]*\) "Apple Development:.*$/\1/p' | head -n 1)"
fi
identity="${identity:--}"
codesign --force --options runtime --timestamp=none --sign "$identity" "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
