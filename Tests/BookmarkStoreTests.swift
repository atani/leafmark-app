import XCTest
import ReadiumShared
@testable import Inkwell

@MainActor
final class BookmarkStoreTests: XCTestCase {
    private var tempURL: URL!
    private var store: BookmarkStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bookmarks-\(UUID().uuidString).json")
        store = BookmarkStore(storeURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    /// Builds a Locator in a given resource at a given progression.
    private func locator(href: String, progression: Double, title: String? = nil) throws -> Locator {
        var json = #"{"href":"\#(href)","type":"text/html","locations":{"totalProgression":\#(progression)}"#
        if let title {
            json += #","title":"\#(title)""#
        }
        json += "}"
        let value = try JSONValue(jsonString: json)
        return try XCTUnwrap(try? Locator(json: value, warnings: nil))
    }

    func testAddAndPersist() throws {
        store.add(bookID: "a", locator: try locator(href: "ch1.html", progression: 0.1), title: "Chapter 1")

        XCTAssertEqual(store.bookmarks(for: "a").count, 1)
        let reloaded = BookmarkStore(storeURL: tempURL)
        XCTAssertEqual(reloaded.bookmarks(for: "a").first?.title, "Chapter 1", "永続化される")
    }

    func testBookmarksSortedByProgression() throws {
        store.add(bookID: "a", locator: try locator(href: "ch2.html", progression: 0.8), title: "late")
        store.add(bookID: "a", locator: try locator(href: "ch1.html", progression: 0.2), title: "early")
        store.add(bookID: "b", locator: try locator(href: "x.html", progression: 0.5), title: "other")

        XCTAssertEqual(store.bookmarks(for: "a").map(\.title), ["early", "late"], "読書位置順")
        XCTAssertEqual(store.bookmarks(for: "b").count, 1, "別の本は混ざらない")
    }

    func testToggleAddsThenRemovesSamePage() throws {
        let loc = try locator(href: "ch1.html", progression: 0.3)

        XCTAssertTrue(store.toggle(bookID: "a", locator: loc, title: nil), "初回はブックマーク追加")
        XCTAssertTrue(store.isBookmarked(bookID: "a", at: loc))

        XCTAssertFalse(store.toggle(bookID: "a", locator: loc, title: nil), "同じページで再トグルは解除")
        XCTAssertFalse(store.isBookmarked(bookID: "a", at: loc))
        XCTAssertTrue(store.bookmarks(for: "a").isEmpty)
    }

    func testIsBookmarkedMatchesNearbyProgressionOnly() throws {
        store.add(bookID: "a", locator: try locator(href: "ch1.html", progression: 0.3), title: nil)

        // わずかな差（< epsilon）は同一ページ扱い。
        XCTAssertTrue(store.isBookmarked(bookID: "a", at: try locator(href: "ch1.html", progression: 0.3000005)))
        // 明確に離れた位置は別ページ。
        XCTAssertFalse(store.isBookmarked(bookID: "a", at: try locator(href: "ch1.html", progression: 0.5)))
        // 別リソースは別ページ。
        XCTAssertFalse(store.isBookmarked(bookID: "a", at: try locator(href: "ch2.html", progression: 0.3)))
    }

    func testRemoveAllForBook() throws {
        store.add(bookID: "a", locator: try locator(href: "ch1.html", progression: 0.1), title: nil)
        store.add(bookID: "a", locator: try locator(href: "ch2.html", progression: 0.5), title: nil)
        store.add(bookID: "b", locator: try locator(href: "x.html", progression: 0.2), title: nil)

        store.removeAll(for: "a")

        XCTAssertTrue(store.bookmarks(for: "a").isEmpty)
        XCTAssertEqual(store.bookmarks(for: "b").count, 1, "他の本は残る")
        XCTAssertEqual(BookmarkStore(storeURL: tempURL).bookmarks(for: "b").count, 1, "削除が永続化される")
    }
}
