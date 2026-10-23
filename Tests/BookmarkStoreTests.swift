import Combine
import XCTest
import ReadiumShared
@testable import Leafmark

@MainActor
final class BookmarkStoreTests: XCTestCase {
    private var tempURL: URL!
    private var store: BookmarkStore!

    override func setUp() {
        super.setUp()
        tempURL = makeTemporaryURL("bookmarks")
        store = BookmarkStore(storeURL: tempURL)
    }

    /// Builds a Locator in a given resource at a given progression.
    private func locator(href: String, progression: Double) throws -> Locator {
        try makeLocator(json: locatorJSON(href: href, progression: progression))
    }

    /// A Locator with no progression info (no `locations` key).
    private func locatorWithoutProgression(href: String) throws -> Locator {
        try makeLocator(json: #"{"href":"\#(href)","type":"text/html"}"#)
    }

    /// A Locator identified by a resource-relative position (no progression).
    private func locator(href: String, position: Int) throws -> Locator {
        try makeLocator(json: #"{"href":"\#(href)","type":"text/html","locations":{"position":\#(position)}}"#)
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
        let json = locatorJSON(href: "c.html", progression: 0.4)
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

    // MARK: - Sync apply

    func testApplyMergedWithUnchangedRecordsSkipsPublishAndWrite() throws {
        let loc = try locator(href: "ch1.html", progression: 0.3)
        store.add(bookID: "a", locator: loc, title: "kept")
        store.add(bookID: "b", locator: try locator(href: "x.html", progression: 0.5), title: "other")
        let records = store.syncedRecords(for: "a")
        let sentinel = Data("sentinel".utf8)
        try sentinel.write(to: tempURL)
        var publishes = 0
        let subscription = store.$bookmarks.dropFirst().sink { _ in publishes += 1 }
        defer { subscription.cancel() }

        store.applyMerged(records, bookID: "a")

        XCTAssertEqual(publishes, 0, "変化が無ければ publish しない")
        XCTAssertEqual(try Data(contentsOf: tempURL), sentinel, "変化が無ければファイルを書き直さない")
        XCTAssertTrue(store.isBookmarked(bookID: "a", at: loc), "在席判定は維持される")
        XCTAssertEqual(store.bookmarks(for: "b").count, 1)
    }

    func testApplyMergedWithRemoteDeletionPublishesAndPersists() throws {
        let loc = try locator(href: "ch1.html", progression: 0.3)
        store.add(bookID: "a", locator: loc, title: nil)
        var record = try XCTUnwrap(store.syncedRecords(for: "a").first)
        record.deletedAt = Date()
        record.updatedAt = Date()
        var publishes = 0
        let subscription = store.$bookmarks.dropFirst().sink { _ in publishes += 1 }
        defer { subscription.cancel() }

        store.applyMerged([record], bookID: "a")

        XCTAssertEqual(publishes, 1)
        XCTAssertFalse(store.isBookmarked(bookID: "a", at: loc), "他端末の削除が反映される")
        XCTAssertFalse(BookmarkStore(storeURL: tempURL).isBookmarked(bookID: "a", at: loc), "削除は永続化される")
    }
}
