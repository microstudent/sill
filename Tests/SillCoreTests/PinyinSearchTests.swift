import XCTest
@testable import SillCore

final class PinyinSearchTests: XCTestCase {
    func testAppFullPinyinAndInitials() {
        let document = WindowSearch.Document(title: "聊天", app: "微信")
        for query in ["weixin", "wx", "WEIXIN", "wei xin", "wei'xin", "ｗｘ"] {
            XCTAssertNotNil(WindowSearch.score(query: query, document: document), query)
        }
    }
    func testChineseTitleFullPinyinAndInitials() {
        let document = WindowSearch.Document(title: "应用程序", app: "访达")
        for query in ["yingyongchengxu", "yycx", "chengxu", "cx", "fangda", "fd"] {
            XCTAssertNotNil(WindowSearch.score(query: query, document: document), query)
        }
    }
    func testMixedChineseEnglishPinyinTokens() {
        let document = WindowSearch.Document(title: "项目设置 — Workspace Notes", app: "代码编辑器")
        for query in ["xmsz workspace", "项目 sz", "daima notes", "dmbjq 设置"] {
            XCTAssertNotNil(WindowSearch.score(query: query, document: document), query)
        }
        XCTAssertNil(WindowSearch.score(query: "xmsz missing", document: document))
    }
    func testDirectMatchRanksAbovePinyinAndInitials() {
        let literal = WindowSearch.score(query: "wx", title: "", app: "wx")!
        let initials = WindowSearch.score(query: "wx", title: "", app: "微信")!
        XCTAssertGreaterThan(literal, initials)
        let full = WindowSearch.score(query: "weixin", title: "", app: "微信")!
        XCTAssertGreaterThan(full, initials)
    }
    func testAsciiTitlesDoNotProduceChineseAcronymMatches() {
        XCTAssertNil(WindowSearch.score(query: "vsc", title: "", app: "Visual Studio Code"))
        XCTAssertNil(WindowSearch.score(query: "unknown", title: "应用程序", app: "访达"))
    }
    func testUmlautInputAndPunctuation() {
        for query in ["lvse", "luse", "lüse", "ls"] {
            XCTAssertNotNil(WindowSearch.score(query: query, title: "绿色", app: "Notes"), query)
        }
        XCTAssertNotNil(WindowSearch.score(query: "xi'an", title: "西安", app: "地图"))
    }
}
