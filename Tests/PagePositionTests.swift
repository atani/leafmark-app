import XCTest
import ReadiumShared
@testable import Leafmark

final class PagePositionTests: XCTestCase {
    /// Builds a synthetic position locator. `position` mirrors the 1-based
    /// index Readium's positions service assigns; `totalProgression` lets the
    /// fallback path resolve the current page without a position.
    private func locator(
        _ href: String,
        position: Int? = nil,
        totalProgression: Double? = nil
    ) -> Locator {
        var parts: [String] = []
        if let position { parts.append("\"position\":\(position)") }
        if let totalProgression { parts.append("\"totalProgression\":\(totalProgression)") }
        let locations = "{\(parts.joined(separator: ","))}"
        let json = "{\"href\":\"\(href)\",\"type\":\"text/html\",\"locations\":\(locations)}"
        let value = try! JSONValue(jsonString: json)
        return try! Locator(json: value, warnings: nil)!
    }

    /// Three chapters of 3 / 2 / 4 pages, numbered globally 1...9.
    private func sampleBook() -> [Locator] {
        var positions: [Locator] = []
        let chapters = [("c1.html", 3), ("c2.html", 2), ("c3.html", 4)]
        var page = 1
        let total = 9
        for (href, count) in chapters {
            for _ in 0 ..< count {
                positions.append(
                    locator(href, position: page, totalProgression: Double(page - 1) / Double(total))
                )
                page += 1
            }
        }
        return positions
    }

    // MARK: - Footer / total pages

    func testFooterReportsCurrentAndTotalPages() {
        let positions = sampleBook()
        // 5th global page (2nd page of chapter 2).
        let info = PagePositionInfo(positions: positions, current: positions[4])
        XCTAssertEqual(info?.currentPage, 5, "5番目の位置は通しで5ページ目になる")
        XCTAssertEqual(info?.totalPages, 9, "総ページ数は全位置数と一致する")
        XCTAssertEqual(info?.footerText, "Page 5 of 9")
    }

    // MARK: - Pages left in chapter

    func testPagesLeftAtChapterStart() {
        let positions = sampleBook()
        // First page of chapter 3 (4 pages): 3 pages remain.
        let info = PagePositionInfo(positions: positions, current: positions[5])
        XCTAssertEqual(info?.pagesLeftInChapter, 3, "4ページ章の先頭では残り3ページ")
        XCTAssertEqual(info?.chapterHeaderText, "3 pages left in this chapter")
    }

    func testPagesLeftMidChapterIsSingular() {
        let positions = sampleBook()
        // Third page of chapter 3 (index 7): one page remains.
        let info = PagePositionInfo(positions: positions, current: positions[7])
        XCTAssertEqual(info?.pagesLeftInChapter, 1, "章の末尾手前は残り1ページ")
        XCTAssertEqual(info?.chapterHeaderText, "1 page left in this chapter")
    }

    func testLastPageOfChapterHasNoneLeft() {
        let positions = sampleBook()
        // Last page of chapter 3 (index 8, also last of book).
        let info = PagePositionInfo(positions: positions, current: positions[8])
        XCTAssertEqual(info?.pagesLeftInChapter, 0, "章の最終ページは残り0")
        XCTAssertEqual(info?.chapterHeaderText, "Last page of this chapter")
    }

    func testFirstPageOfBook() {
        let positions = sampleBook()
        let info = PagePositionInfo(positions: positions, current: positions[0])
        XCTAssertEqual(info?.currentPage, 1, "先頭は1ページ目")
        XCTAssertEqual(info?.pagesLeftInChapter, 2, "3ページ章の先頭では残り2ページ")
        XCTAssertEqual(info?.footerText, "Page 1 of 9")
    }

    func testSinglePageChapterHasNoneLeft() {
        // A chapter with exactly one position: nothing remains after it.
        let positions = [
            locator("c1.html", position: 1, totalProgression: 0.0),
            locator("c2.html", position: 2, totalProgression: 0.5),
            locator("c3.html", position: 3, totalProgression: 0.75),
        ]
        let info = PagePositionInfo(positions: positions, current: positions[1])
        XCTAssertEqual(info?.pagesLeftInChapter, 0, "1ページ章は残り0")
        XCTAssertEqual(info?.chapterHeaderText, "Last page of this chapter")
    }

    // MARK: - Degenerate inputs

    func testEmptyPositionsYieldsNil() {
        XCTAssertNil(
            PagePositionInfo(positions: [], current: locator("c1.html", position: 1)),
            "位置情報が無ければ表示しない"
        )
    }

    func testNilCurrentYieldsNil() {
        XCTAssertNil(
            PagePositionInfo(positions: sampleBook(), current: nil),
            "現在位置が無ければ表示しない"
        )
    }

    // MARK: - Fallback by progression

    func testFallsBackToNearestProgressionWhenPositionMissing() {
        let positions = sampleBook()
        // Current locator lacks `position`; its progression sits closest to
        // the 4th global page (first page of chapter 2, index 3 at 0.333).
        let current = locator("c2.html", totalProgression: 0.34)
        let info = PagePositionInfo(positions: positions, current: current)
        XCTAssertEqual(info?.currentPage, 4, "position 無しでも進捗から4ページ目に解決する")
        XCTAssertEqual(info?.pagesLeftInChapter, 1, "chapter 2 の先頭なので残り1ページ")
    }

    func testNilWhenNeitherPositionNorProgressionAvailable() {
        let positions = sampleBook()
        let current = locator("c2.html")
        XCTAssertNil(
            PagePositionInfo(positions: positions, current: current),
            "position も progression も無ければ解決できない"
        )
    }
}
