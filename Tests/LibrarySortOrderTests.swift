import XCTest
@testable import Leafmark

final class LibrarySortOrderTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func book(
        id: String,
        title: String,
        author: String? = nil,
        addedOffset: TimeInterval = 0
    ) -> Book {
        Book(
            id: id,
            fileName: "\(id).epub",
            title: title,
            author: author,
            addedAt: base.addingTimeInterval(addedOffset)
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
        XCTAssertEqual(LibrarySortOrder(rawValue: "recentlyAdded"), .recentlyAdded)
        XCTAssertEqual(LibrarySortOrder(rawValue: "title"), .title)
        XCTAssertEqual(LibrarySortOrder(rawValue: "author"), .author)
    }
}
