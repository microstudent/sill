# Development

## Requirements

- macOS 14 or later to run the app.
- Xcode 26 or later, with the macOS 26+ SDK and Swift 6.2+ toolchain, to build it. Your build machine must support that Xcode version.
- No third-party package dependencies.

Check the active toolchain with `swift --version` and `xcode-select -p`. The package currently uses Swift 5 language mode with a Swift 6 toolchain; migration to strict Swift 6 concurrency checking is not complete.

## Repository layout

```text
Sources/
  Sill/                 AppKit app, SwiftUI settings, Accessibility integration
  SillCore/             Window geometry and search logic
Tests/SillCoreTests/    XCTest coverage for geometry and search
Resources/             App bundle metadata
scripts/               Build, install, and icon generation
docs/                  Compatibility notes and README artwork
.github/               CI and contribution templates
```

`WindowService` serializes Accessibility queries and actions on a background queue. It combines debounced AX events with a three-second fallback refresh and keeps AX element identity for windows. UI work runs on the main thread.

`WindowList` filters and groups windows and renders nonactivating sidebar panels. `SidebarStates` manages compact group headers and empty states. `WindowAvoidance` tracks automatic adjustments and avoids restoring over later user changes.

`SearchController` handles search and registered system shortcuts. `SillCore.WindowSearch` caches offline transliteration by app name and title; literal matches rank ahead of pinyin and initials. `SettingsController` and `Preferences` provide persistence and immediate language switching.

`SidebarSurface` embeds the toolbar and window list in `NSGlassEffectView.contentView` on macOS 26+. It swaps between regular glass, clear glass, and `NSVisualEffectView` without recreating the panel. Older systems use the frosted surface. Glass rendering and accessibility adjustments are handled by AppKit.

## Build and test

```sh
swift test
./scripts/build-app.sh
open build/Sill.app
```

The build script creates `build/Sill.app`, including generated icons and bundle metadata. Use this app bundle for manual testing; `swift run` alone does not package the application resources.

To package a debug build:

```sh
CONFIGURATION=debug ./scripts/build-app.sh
```

To build and install into `~/Applications/Sill.app`:

```sh
./scripts/install-app.sh
```

Quit Sill before replacing an installed build. Build output, logs, and local IDE state are ignored by Git. Keep source assets, tests, shared configuration, and any future `Package.resolved` lockfile under version control.

## Signing and Accessibility

By default the build script chooses an available Apple Development identity. Without one, it uses ad-hoc signing. Override the identity explicitly if needed:

```sh
# Ad-hoc signing, used by CI; no personal certificate required.
CODE_SIGN_IDENTITY=- ./scripts/build-app.sh

# Use an identity already installed in your local keychain.
CODE_SIGN_IDENTITY="Your code signing identity" ./scripts/build-app.sh
```

The current build command disables signing timestamps and does not perform notarization. Producing a public distribution requires a separate Developer ID signing and notarization workflow; these scripts do not provide one.

Keep the app path and signing identity stable for interactive development. Rebuilding with ad-hoc signing or changing identity can invalidate Accessibility authorization. Remove and re-add the installed application in System Settings if needed. Login-item behavior also needs to be checked with the installed, signed app.

## Validation scope

GitHub Actions runs unit tests and packages an ad-hoc-signed app on a macOS runner. It does not launch the app, grant permissions, or exercise interactive UI flows.

Use the [manual checklist](parity.md) for changes involving real windows, Spaces, multiple displays, or permissions. Record only checks that were actually performed, including the OS and relevant setup.

## Artwork

`docs/assets/sill-hero.png` is an AI-generated README illustration, not a product screenshot. Both README translations reference this local asset. The app icon is generated separately by `scripts/make-icon.swift`.

## References

- [Contexts](https://contexts.co/) — product inspiration.
- [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview).
- [AXObserverCreate](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate).
- [NSWindow.CollectionBehavior.canJoinAllApplications](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications).
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).
