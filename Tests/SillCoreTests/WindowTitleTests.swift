import XCTest
import CoreGraphics
@testable import SillCore

final class WindowTitleTests: XCTestCase {
    func testBrowserSuffixRemovalIsConservative() {
        XCTAssertEqual(WindowTitle.display("Readme — Safari", app: "Safari", bundleID: "com.apple.Safari"), "Readme")
        XCTAssertEqual(WindowTitle.display("Safari — Readme", app: "Safari", bundleID: "com.apple.Safari"), "Safari — Readme")
        XCTAssertEqual(WindowTitle.display("Readme — Safari", app: "Safari", bundleID: "example.editor"), "Readme — Safari")
        XCTAssertEqual(WindowTitle.display("Safari", app: "Safari", bundleID: "com.apple.Safari"), "Safari")
        XCTAssertEqual(WindowTitle.display("Report - Microsoft Edge", app: "Microsoft Edge", bundleID: "com.microsoft.edgemac"), "Report")
    }
    func testFileExtensionsAndOrdinaryProse() {
        XCTAssertTrue(WindowTitle.isFilename("季度总结 2026.PDF"))
        XCTAssertTrue(WindowTitle.isFilename("/project/long folder name/README.md"))
        XCTAssertFalse(WindowTitle.isFilename("Why we use Swift"))
        XCTAssertFalse(WindowTitle.isFilename("Readme.md — Editor"))
    }
    func testWidthBoundsRespectSmallDisplaysAndLongTitles() {
        XCTAssertEqual(WindowTitle.expandedWidth(titleWidth: 0, availableWidth: 1440), 300)
        XCTAssertEqual(WindowTitle.expandedWidth(titleWidth: 280, availableWidth: 1440), 335)
        XCTAssertEqual(WindowTitle.expandedWidth(titleWidth: 4000, availableWidth: 1440), 420)
        XCTAssertEqual(WindowTitle.expandedWidth(titleWidth: 4000, availableWidth: 280), 280)
    }
    func testPreviewRemainsOnNegativeOriginDisplayAtEitherEdge() {
        let screen = CGRect(x: -1920, y: -900, width: 1920, height: 900)
        for edge in SidebarEdge.allCases {
            let row = CGRect(x: edge == .left ? -1920 : -420, y: -890, width: 420, height: 26)
            let result = WindowTitle.previewFrame(row: row, size: CGSize(width: 444, height: 2000), visibleFrame: screen, edge: edge)
            XCTAssertTrue(screen.contains(result))
            if edge == .left { XCTAssertGreaterThan(result.minX, row.maxX) }
            else { XCTAssertLessThan(result.maxX, row.minX) }
        }
    }
}
