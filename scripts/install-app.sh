#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
require_stopped() {
    if pgrep -x Sill >/dev/null; then
        printf 'Quit Sill before installing a new build.\n' >&2
        exit 1
    fi
}
require_stopped
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
require_stopped
mkdir -p "$HOME/Applications"
ditto "$source_app" "$destination"
codesign --verify --strict "$destination"
printf '%s\n' "$destination"
