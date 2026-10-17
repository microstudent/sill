import XCTest
@testable import SillCore

final class SearchKeyboardTests: XCTestCase {
    func testCompositionKeepsCandidateKeysAndCommandsInInputMethod() {
        for code: UInt16 in [36, 76, 53, 125, 126, 48] {
            XCTAssertNil(SearchKeyboard.command(keyCode: code, characters: nil, modifiers: [], hasMarkedText: true))
        }
        XCTAssertNil(SearchKeyboard.command(keyCode: 13, characters: "w", modifiers: [.command], hasMarkedText: true))
    }
    func testTextEditingModifiersAreNotWindowCommands() {
        XCTAssertNil(SearchKeyboard.command(keyCode: 125, characters: nil, modifiers: [.shift], hasMarkedText: false))
        XCTAssertNil(SearchKeyboard.command(keyCode: 126, characters: nil, modifiers: [.option], hasMarkedText: false))
        XCTAssertNil(SearchKeyboard.command(keyCode: 13, characters: "w", modifiers: [.command, .shift], hasMarkedText: false))
        XCTAssertNil(SearchKeyboard.command(keyCode: 0, characters: "a", modifiers: [.command], hasMarkedText: false))
    }
    func testNavigationAndWindowActionsAfterComposition() {
        XCTAssertEqual(SearchKeyboard.command(keyCode: 48, characters: nil, modifiers: [.shift], hasMarkedText: false), .move(-1))
        XCTAssertEqual(SearchKeyboard.command(keyCode: 125, characters: nil, modifiers: [], hasMarkedText: false), .move(1))
        XCTAssertEqual(SearchKeyboard.command(keyCode: 76, characters: nil, modifiers: [], hasMarkedText: false), .activate)
        XCTAssertEqual(SearchKeyboard.command(keyCode: 53, characters: nil, modifiers: [], hasMarkedText: false), .dismiss)
        XCTAssertEqual(SearchKeyboard.command(keyCode: 13, characters: "w", modifiers: [.command], hasMarkedText: false), .close)
    }
}
