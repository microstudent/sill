import XCTest
@testable import SillCore

final class WindowOrderingTests: XCTestCase {
    private struct Item: Equatable {
        let id: Int
        let app: String
    }
    func testInterleavedWindowsBecomeAdjacentWithoutReorderingApps() {
        let items = [Item(id: 1, app: "browser"), Item(id: 2, app: "editor"), Item(id: 3, app: "chat"), Item(id: 4, app: "browser"), Item(id: 5, app: "editor")]
        let result = WindowOrdering.adjacentByApplication(items, applicationID: \.app)
        XCTAssertEqual(result.map(\.id), [1, 4, 2, 5, 3])
        XCTAssertEqual(WindowOrdering.adjacentByApplication(result, applicationID: \.app), result)
    }
    func testNewWindowJoinsItsAppWithoutMovingOtherApps() {
        let items = [Item(id: 1, app: "browser"), Item(id: 2, app: "editor"), Item(id: 3, app: "chat")]
        let result = WindowOrdering.adjacentByApplication(items + [Item(id: 4, app: "editor")], applicationID: \.app)
        XCTAssertEqual(result.map(\.id), [1, 2, 4, 3])
    }
    func testVisibilityPartitionKeepsAppWindowsTogetherWithinEachSection() {
        let items = [Item(id: 1, app: "browser"), Item(id: 2, app: "editor"), Item(id: 3, app: "browser"), Item(id: 4, app: "editor"), Item(id: 5, app: "browser")]
        let ordered = WindowOrdering.adjacentByApplication(items, applicationID: \.app)
        let hidden = Set([3, 4])
        XCTAssertEqual(ordered.filter { !hidden.contains($0.id) }.map(\.id), [1, 5, 2])
        XCTAssertEqual(ordered.filter { hidden.contains($0.id) }.map(\.id), [3, 4])
    }
    func testEmptyList() {
        XCTAssertTrue(WindowOrdering.adjacentByApplication([Item](), applicationID: \.app).isEmpty)
    }
}
