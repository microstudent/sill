# Compatibility and validation

**English** · [简体中文](parity.zh-CN.md)

This is a feature comparison with Contexts 3.9.0, based on the original app's settings, user-supplied reference screenshots, and [official release notes](https://contexts.co/whats-new/). Sill is an independent implementation and does not aim to claim complete feature parity.

## Feature status

| Feature | Status | Notes |
| --- | --- | --- |
| Window icons and titles | Implemented | Active-window highlighting |
| Four resting modes and hover expansion | Implemented | Hidden mode retains a 3 pt activation edge |
| Left/right and top/center/bottom placement | Implemented | Uses the visible display frame |
| Sidebar and text sizing | Implemented | Automatic width 300–420 pt; manual width 180–600 pt; text 11–20 pt |
| Liquid Glass / Clear Glass / Classic Frosted | Implemented | Native glass on macOS 26+; frosted fallback on older systems |
| All/primary/no displays | Implemented | Rebuilds on display changes; hardware combinations need testing |
| Five window scopes | Implemented | Visibility is inferred using public APIs |
| Automatic window clearance | Implemented | Off by default; a separate default-off switch enables the 60-second pause after manual resizing |
| Temporary and horizontal-scroll hiding | Implemented | Physical gesture validation pending |
| Space grouping | Partial | Visible / other and hidden / full screen; no desktop numbers |
| Single group or grouping by app | Implemented | No manual group ordering |
| Drag-and-drop grouping and reserved slots | Not implemented | Requires persistent window matching and drag support |
| Running apps without windows | Implemented | Activates the app without forcing a new window |
| App and title exclusions | Implemented | Bundle IDs and a global title regular expression |
| English / Simplified Chinese / system language | Implemented | Immediate switching |
| Light / dark / system theme | Implemented | System materials |
| Search | Implemented | English, Chinese, full pinyin, initials, and mixed tokens |
| Search learning and typo tolerance | Not implemented | Token substring matching |
| Hold-Fn / modifier search | Not implemented | No arbitrary keyboard monitoring |
| Command–Tab replacement | Not implemented | Existing system shortcuts remain available |
| Number shortcuts | Partial | Optional positions 1–9; no two-digit positions |
| Close / minimize / hide from search | Implemented | Command–W / M / H |
| Dock badges | Not implemented | No reliable public cross-app API |
| Global trackpad-edge gestures | Not implemented | No private multitouch APIs |
| Launch at login | Implemented | Installation and system approval need interactive validation |
| Original licensing and update service | Not applicable | Independent project |

## Validation record

The development machine runs macOS 27.0.1 on Apple Silicon. The deployment target is macOS 14, which is not a claim of complete coverage of older systems or Intel hardware.

- [x] Native app launch and Chinese settings layout.
- [x] Immediate English switching across settings, menus, and titles.
- [x] Real window titles and icons loaded after granting Accessibility access.
- [x] Switching to a Finder window from the sidebar.
- [x] Minimizing and restoring a Finder window, with corresponding regrouping.
- [x] Searching for “应用” and switching to Finder with Return.
- [x] Physical Control–Option–Space shortcut confirmed by the user.
- [x] 22 unit tests covering geometry, search, pinyin, initials, mixed tokens, ü/v input, conservative title formatting, width limits, preview placement, stable application clustering, and input-method-safe keyboard routing.
- [x] Installed app: expanded and collapsed lists have identical height and aligned icon rows with the same windows.
- [x] Installed app: two Edge windows are adjacent within the current-desktop group; visibility sections remain separate.
- [x] Installed app: 420 pt adaptive expansion and a wrapping full-title preview for a truncated editor title (also confirmed by a user screenshot).
- [x] Settings open / close / reopen changes the app's activation policy to regular / accessory / regular, while the sidebar remains running.
- [x] Minimal About page checked in the installed app.
- [x] Search no-result guidance and resetting scroll position when changing Settings pages.
- [x] Install script rejects replacement while Sill is running; ZIP extraction retains executable permission and a valid signature.
- [ ] Live Chinese input-method candidate selection and permission revocation during an active scan (keyboard policy has regression tests).
- [ ] Accurate switching among multiple windows of the same app.
- [ ] Window-close and application-exit cleanup.
- [ ] Full coverage of resting modes, long-list scrolling, and nonactivating hover.
- [x] Installed Sill: `yycx` finds the Finder “应用程序” window; Return switches to it.
- [ ] Full arrow-key, Tab, and Escape navigation paths.
- [ ] Multi-monitor hardware, unplugging displays, resolutions, and Dock placement.
- [ ] Full screen, other Spaces, and Stage Manager.
- [ ] Automatic clearance, optional manual-adjustment pause, and conditional restoration.
- [ ] Login items, revoking access, and reauthorization.
- [x] Native Liquid Glass and Classic Frosted rendering with real windows on macOS 27.0.1; material changes keep the window list visible.
- [ ] Clear Glass visual checks and older-system material fallback.

The window-switching and Chinese-search checks above were performed on the development app before it was renamed to Sill. Accessibility authorization and real-window listing were subsequently verified in the installed Sill app, including after the Liquid Glass update. Real-window pinyin-initial search and Return activation were subsequently verified in the installed Sill app.

Local check output lives in the ignored `logs/` directory. Unchecked items are not represented as verified behavior. CI builds and tests do not replace interactive validation.
