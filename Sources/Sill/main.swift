import AppKit

Preferences.migrateLegacyDefaultsIfNeeded()
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
