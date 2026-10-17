import XCTest
@testable import SillCore

final class GlobalShortcutTests: XCTestCase {
    func testLegacyAndMalformedSettingsKeepWorkingDefaults() {
        XCTAssertEqual(ShortcutConfiguration.restored(from: nil), .defaults)
        XCTAssertEqual(ShortcutConfiguration.restored(from: Data("broken".utf8)), .defaults)
        XCTAssertTrue(ShortcutConfiguration.defaults.isValid)
        XCTAssertEqual(ShortcutConfiguration.defaults.search.display, "⌃⌥Space")
    }
    func testTypingAndModifierOnlyKeysCannotBecomeGlobalShortcuts() {
        for modifiers: ShortcutModifiers in [[], .shift, ShortcutModifiers(rawValue: 17)] {
            XCTAssertFalse(GlobalShortcut(keyCode: 0, modifiers: modifiers, keyLabel: "A").isValid)
        }
        for key: UInt32 in [53, 54, 55, 56, 63, 127] {
            XCTAssertFalse(GlobalShortcut(keyCode: key, modifiers: .command, keyLabel: "Key").isValid)
        }
        XCTAssertTrue(GlobalShortcut(keyCode: 0, modifiers: [.command, .shift], keyLabel: "A").isValid)
    }
    func testAllNineNumberBindingsAreCheckedForCollision() {
        for key in ShortcutConfiguration.numberKeyCodes {
            var config = ShortcutConfiguration.defaults
            config.search.keyCode = key
            XCTAssertTrue(config.hasCollision)
            XCTAssertFalse(config.isValid)
            config.search.modifiers = [.command, .shift]
            XCTAssertTrue(config.isValid)
        }
    }
    func testCustomBindingsSurvivePersistence() throws {
        let custom = ShortcutConfiguration(search: GlobalShortcut(keyCode: 40, modifiers: [.command, .shift], keyLabel: "K"), numberModifiers: [.control, .command])
        XCTAssertEqual(ShortcutConfiguration.restored(from: try JSONEncoder().encode(custom)), custom)
        XCTAssertEqual(custom.search.display, "⇧⌘K")
    }
    func testInvalidStoredConfigurationFallsBackSafely() throws {
        var config = ShortcutConfiguration.defaults
        config.numberModifiers = .shift
        XCTAssertEqual(ShortcutConfiguration.restored(from: try JSONEncoder().encode(config)), .defaults)
    }
}
