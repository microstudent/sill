import XCTest
import CoreGraphics
@testable import SillCore

final class SillCoreTests: XCTestCase {
    func testRightSidebarOnNegativeOriginDisplay() {
        let screen = CGRect(x: -1920, y: 24, width: 1920, height: 1056)
        let frame = SidebarGeometry.frame(in: screen, edge: .right, width: 320, height: 500)
        XCTAssertEqual(frame.maxX, 0)
        XCTAssertEqual(frame.midY, screen.midY)
    }
    func testTallListClampedToVisibleFrame() {
        let frame = SidebarGeometry.frame(in: CGRect(x: 0, y: 0, width: 1440, height: 900), edge: .left, width: 44, height: 2000)
        XCTAssertEqual(frame.minY, 8)
        XCTAssertEqual(frame.maxY, 892)
    }
    func testCoordinateConversionAcrossVerticalDisplaysIsInvolution() {
        let rect = CGRect(x: -1600, y: 1200, width: 800, height: 600)
        let ax = SidebarGeometry.accessibilityRect(rect, primaryHeight: 1080)
        XCTAssertEqual(ax.origin.y, -720)
        XCTAssertEqual(SidebarGeometry.accessibilityRect(ax, primaryHeight: 1080), rect)
    }
    func testAvoidancePreservesOppositeEdgeAndRejectsTooSmallWindow() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let result = SidebarGeometry.avoidingStrip(window: screen, visibleFrame: screen, edge: .left, width: 44)!
        XCTAssertEqual(result.minX, 52)
        XCTAssertEqual(result.maxX, 1440)
        XCTAssertNil(SidebarGeometry.avoidingStrip(window: CGRect(x: 0, y: 0, width: 330, height: 400), visibleFrame: screen, edge: .left, width: 44))
        XCTAssertNil(SidebarGeometry.avoidingStrip(window: CGRect(x: 2000, y: 0, width: 800, height: 600), visibleFrame: screen, edge: .right, width: 44))
    }
    func testSearchHandlesChineseMultiTokenAndAccents() {
        XCTAssertNotNil(WindowSearch.score(query: "代码 设置", title: "设置 — 代码项目", app: "Code"))
        XCTAssertNotNil(WindowSearch.score(query: "cafe", title: "Café", app: "Notes"))
        XCTAssertNil(WindowSearch.score(query: "missing", title: "Settings", app: "Code"))
        XCTAssertEqual(WindowSearch.score(query: " ", title: "", app: ""), 0)
    }
}
