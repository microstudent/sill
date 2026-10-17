#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
source_app="$PWD/build/Sill.app"
destination="$HOME/Applications/Sill.app"
if [[ -e "$destination" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")"
    if [[ "$existing_id" != "local.sill.app" ]]; then
        printf 'Refusing to replace an unrelated app at %s\n' "$destination" >&2
        exit 1
    fi
fi
mkdir -p "$HOME/Applications"
ditto "$source_app" "$destination"
codesign --verify --strict "$destination"
printf '%s\n' "$destination"
