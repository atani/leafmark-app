import XCTest
@testable import Leafmark

final class LibrarySortOrderTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func book(
        id: String,
        title: String,
        author: String? = nil,
        addedOffset: TimeInterval = 0,
        lastOpenedOffset: TimeInterval? = nil
    ) -> Book {
        Book(
            id: id,
            fileName: "\(id).epub",
            title: title,
            author: author,
            addedAt: base.addingTimeInterval(addedOffset),
            lastOpenedAt: lastOpenedOffset.map { base.addingTimeInterval($0) }
        )
    }

    func testRecentlyOpenedSortsByLastOpenedThenFallsBackToAddedAt() {
        let books = [
            book(id: "opened-old", title: "Opened Old", addedOffset: 1, lastOpenedOffset: 1),
            book(id: "opened-new", title: "Opened New", addedOffset: 2, lastOpenedOffset: 3),
            book(id: "never-opened-new", title: "Never Opened New", addedOffset: 5),
            book(id: "never-opened-old", title: "Never Opened Old", addedOffset: 4),
        ]

        XCTAssertEqual(
            LibrarySortOrder.recentlyOpened.sorted(books).map(\.id),
            ["opened-new", "opened-old", "never-opened-new", "never-opened-old"]
        )
    }

    func testRecentlyOpenedTieBreaksOnTitleWhenLastOpenedAtMatches() {
        let books = [
            book(id: "z", title: "Zeno", lastOpenedOffset: 1),
            book(id: "a", title: "Apple", lastOpenedOffset: 1),
        ]

        XCTAssertEqual(
            LibrarySortOrder.recentlyOpened.sorted(books).map(\.id),
            ["a", "z"]
        )
    }

    func testRecentlyAddedSortsNewestFirst() {
        let books = [
            book(id: "old", title: "Old", addedOffset: 1),
            book(id: "new", title: "New", addedOffset: 3),
            book(id: "middle", title: "Middle", addedOffset: 2),
        ]

        XCTAssertEqual(
            LibrarySortOrder.recentlyAdded.sorted(books).map(\.id),
            ["new", "middle", "old"]
        )
    }

    func testTitleSortTieBreaksOnNewerAddedAtThenOnId() {
        let newerFirst = [
            book(id: "b", title: "Same Title", addedOffset: 2),
            book(id: "a", title: "Same Title", addedOffset: 1),
        ]
        XCTAssertEqual(
            LibrarySortOrder.title.sorted(newerFirst).map(\.id),
            ["b", "a"],
            "同じタイトルなら addedAt が新しい方が先に来る"
        )

        let sameAddedAt = [
            book(id: "z", title: "Same Title", addedOffset: 1),
            book(id: "a", title: "Same Title", addedOffset: 1),
        ]
        XCTAssertEqual(
            LibrarySortOrder.title.sorted(sameAddedAt).map(\.id),
            ["a", "z"],
            "タイトルと addedAt がともに同じなら id 昇順で安定する"
        )
        XCTAssertEqual(
            LibrarySortOrder.title.sorted(sameAddedAt.reversed()).map(\.id),
            ["a", "z"],
            "入力順を反転しても id 昇順の結果は変わらない"
        )
    }

    func testRecentlyAddedFallsBackToTitleWhenAddedAtMatches() {
        let books = [
            book(id: "z", title: "Zeno", addedOffset: 1),
            book(id: "a", title: "Apple", addedOffset: 1),
        ]

        XCTAssertEqual(
            LibrarySortOrder.recentlyAdded.sorted(books).map(\.id),
            ["a", "z"]
        )
    }

    func testTitleSortIsCaseInsensitive() {
        let books = [
            book(id: "z", title: "Zeno"),
            book(id: "a", title: "apple"),
            book(id: "m", title: "Meditations"),
        ]

        XCTAssertEqual(
            LibrarySortOrder.title.sorted(books).map(\.id),
            ["a", "m", "z"]
        )
    }

    func testAuthorSortPlacesMissingAuthorsLastAndUsesTitleAsTieBreaker() {
        let books = [
            book(id: "unknown", title: "Anonymous", author: nil),
            book(id: "austen-z", title: "Sense", author: "Jane Austen"),
            book(id: "austen-a", title: "Emma", author: "jane austen"),
            book(id: "woolf", title: "Orlando", author: "Virginia Woolf"),
            book(id: "blank", title: "Blank", author: "   "),
        ]

        XCTAssertEqual(
            LibrarySortOrder.author.sorted(books).map(\.id),
            ["austen-a", "austen-z", "woolf", "unknown", "blank"]
        )
    }

    func testRawValuesRemainStableForAppStorage() {
        XCTAssertEqual(LibrarySortOrder(rawValue: "recentlyOpened"), .recentlyOpened)
        XCTAssertEqual(LibrarySortOrder(rawValue: "recentlyAdded"), .recentlyAdded)
        XCTAssertEqual(LibrarySortOrder(rawValue: "title"), .title)
        XCTAssertEqual(LibrarySortOrder(rawValue: "author"), .author)
    }

    func testUnknownRawValueDecodesToNil() {
        XCTAssertNil(LibrarySortOrder(rawValue: "bogus"))
    }

    func testAllCasesCoverKnownRawValuesInMenuOrder() {
        XCTAssertEqual(
            LibrarySortOrder.allCases.map(\.rawValue),
            ["recentlyOpened", "recentlyAdded", "title", "author"]
        )
    }
}
