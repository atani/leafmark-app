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

    /// A Locator with no progression info (no `locations` key).
    private func locatorWithoutProgression(href: String) throws -> Locator {
        let value = try JSONValue(jsonString: #"{"href":"\#(href)","type":"text/html"}"#)
        return try XCTUnwrap(try? Locator(json: value, warnings: nil))
    }

    /// A Locator identified by a resource-relative position (no progression).
    private func locator(href: String, position: Int) throws -> Locator {
        let value = try JSONValue(jsonString: #"{"href":"\#(href)","type":"text/html","locations":{"position":\#(position)}}"#)
        return try XCTUnwrap(try? Locator(json: value, warnings: nil))
    }

    /// Seeds bookmarks directly (bypassing add's UUID/Date) so tests can
    /// control ids and createdAt, mirroring HighlightStoreTests.seed.
    private func seed(_ bookmarks: [Bookmark]) -> BookmarkStore {
        let data = try! JSONEncoder().encode(bookmarks)
        try! data.write(to: tempURL)
        return BookmarkStore(storeURL: tempURL)
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

    func testBookmarkWithoutAnyPositionInfoIsNotMatched() throws {
        // 位置情報が一切無い場合、同一リソースでも「別ページ」に倒す。
        // そうしないと別位置で bookmark を押した際に既存を消してしまう。
        store.add(bookID: "a", locator: try locatorWithoutProgression(href: "ch1.html"), title: nil)

        XCTAssertFalse(
            store.isBookmarked(bookID: "a", at: try locatorWithoutProgression(href: "ch1.html")),
            "位置情報が無ければ同一ページと断定しない（削除防止）"
        )
    }

    func testBookmarkFallsBackToPositionWhenProgressionMissing() throws {
        store.add(bookID: "a", locator: try locator(href: "ch1.html", position: 5), title: nil)

        XCTAssertTrue(
            store.isBookmarked(bookID: "a", at: try locator(href: "ch1.html", position: 5)),
            "progression が無くても position 一致なら同一ページ"
        )
        XCTAssertFalse(
            store.isBookmarked(bookID: "a", at: try locator(href: "ch1.html", position: 6)),
            "position が違えば別ページ"
        )
    }

    func testBookmarkDoesNotMatchWhenOnlyOneProgressionMissing() throws {
        store.add(bookID: "with", locator: try locator(href: "ch1.html", progression: 0.3), title: nil)
        XCTAssertFalse(
            store.isBookmarked(bookID: "with", at: try locatorWithoutProgression(href: "ch1.html")),
            "保存側に progression があり照会側に無ければ別ページ"
        )

        store.add(bookID: "without", locator: try locatorWithoutProgression(href: "ch1.html"), title: nil)
        XCTAssertFalse(
            store.isBookmarked(bookID: "without", at: try locator(href: "ch1.html", progression: 0.3)),
            "逆向きも別ページ"
        )
    }

    func testIsBookmarkedProbesEpsilonBoundary() throws {
        store.add(bookID: "a", locator: try locator(href: "ch1.html", progression: 0.3), title: nil)

        XCTAssertTrue(
            store.isBookmarked(bookID: "a", at: try locator(href: "ch1.html", progression: 0.3009)),
            "0.0009 差は境界内で同一"
        )
        XCTAssertFalse(
            store.isBookmarked(bookID: "a", at: try locator(href: "ch1.html", progression: 0.3011)),
            "0.0011 差は境界外で別ページ"
        )
    }

    func testBookmarksWithEqualProgressionOrderedByCreatedAt() {
        let json = #"{"href":"c.html","type":"text/html","locations":{"totalProgression":0.4}}"#
        let store = seed([
            Bookmark(id: "late", bookID: "a", locatorJSON: json, title: "late",
                     createdAt: Date(timeIntervalSinceReferenceDate: 100)),
            Bookmark(id: "early", bookID: "a", locatorJSON: json, title: "early",
                     createdAt: Date(timeIntervalSinceReferenceDate: 0)),
        ])
        XCTAssertEqual(store.bookmarks(for: "a").map(\.id), ["early", "late"], "同一進捗は作成時刻の昇順")
    }

    func testRemoveByIdDeletesOnlyThatBookmark() throws {
        let keep = store.add(bookID: "a", locator: try locator(href: "ch1.html", progression: 0.1), title: nil)
        let doomed = store.add(bookID: "a", locator: try locator(href: "ch2.html", progression: 0.5), title: nil)

        store.remove(doomed.id)

        XCTAssertEqual(store.bookmarks(for: "a").map(\.id), [keep.id])
        XCTAssertEqual(BookmarkStore(storeURL: tempURL).bookmarks(for: "a").map(\.id), [keep.id], "削除が永続化される")
    }

    // MARK: - Labels

    func testProgressionLabelClampsOutOfRange() {
        XCTAssertEqual(BookmarkStore.progressionLabel(0.5), "50%")
        // 改竄データ由来の範囲外値でも Int(_:) がトラップせずクランプされる。
        XCTAssertEqual(BookmarkStore.progressionLabel(1e300), "100%")
        XCTAssertEqual(BookmarkStore.progressionLabel(.infinity), "100%")
        XCTAssertEqual(BookmarkStore.progressionLabel(-5), "0%")
        XCTAssertEqual(BookmarkStore.progressionLabel(.nan), "0%", "NaN でもトラップしない")
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
