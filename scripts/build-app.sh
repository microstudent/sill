#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
deployment_target="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist)"
if [[ "${sdk_version%%.*}" -lt 26 ]]; then
    printf 'Sill requires the macOS 26 SDK or later. Select Xcode 26+ with xcode-select.\n' >&2
    exit 1
fi
# Some SwiftPM build engines record the deployment target as the linked SDK.
# AppKit uses the linked SDK to select modern appearance behavior, so preserve
# macOS 14 compatibility while explicitly recording the SDK we actually build with.
swift build -c "$configuration" --sdk "$sdk_path" \
    -Xlinker -platform_version -Xlinker macos \
    -Xlinker "$deployment_target" -Xlinker "$sdk_version"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
if ! xcrun vtool -show-build "$bin_dir/Sill" | awk -v expected="$sdk_version" '
    $1 == "sdk" { found = 1; if ($2 != expected) mismatch = 1 }
    END { exit (!found || mismatch) }
'; then
    printf 'The executable does not record the selected macOS SDK (%s).\n' "$sdk_version" >&2
    exit 1
fi
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
