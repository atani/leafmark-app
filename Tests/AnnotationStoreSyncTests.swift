import XCTest
import ReadiumShared
@testable import Leafmark

/// Verifies the store hooks the sync engine relies on: single deletions leave a
/// propagating tombstone, whole-book deletion does not, and merged documents
/// round-trip back into the stores.
@MainActor
final class AnnotationStoreSyncTests: XCTestCase {
    private var highlightURL: URL!
    private var bookmarkURL: URL!

    override func setUp() {
        super.setUp()
        highlightURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("h-sync-\(UUID().uuidString).json")
        bookmarkURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("b-sync-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: highlightURL)
        try? FileManager.default.removeItem(at: bookmarkURL)
        super.tearDown()
    }

    private func locator(href: String = "ch1.html", progression: Double = 0.3) throws -> Locator {
        let json = #"{"href":"\#(href)","type":"text/html","locations":{"totalProgression":\#(progression)}}"#
        return try XCTUnwrap(try? Locator(json: try JSONValue(jsonString: json), warnings: nil))
    }

    // MARK: - Highlights

    func testRemoveLeavesTombstoneInSyncedRecords() throws {
        let store = HighlightStore(storeURL: highlightURL)
        let added = store.add(bookID: "book-a", locator: try locator(), color: .yellow)

        store.remove(added.id)

        XCTAssertTrue(store.highlights(for: "book-a").isEmpty, "削除後は表示から消える")
        let synced = store.syncedRecords(for: "book-a")
        XCTAssertEqual(synced.count, 1, "同期レコードには墓標が残る")
        XCTAssertNotNil(synced.first?.deletedAt, "墓標として deletedAt が付く")
    }

    func testRemoveAllLeavesNoTombstone() throws {
        let store = HighlightStore(storeURL: highlightURL)
        store.add(bookID: "book-a", locator: try locator(), color: .yellow)

        store.removeAll(for: "book-a")

        XCTAssertTrue(store.syncedRecords(for: "book-a").isEmpty, "本ごと削除は墓標を残さない（他端末の注釈を消さない）")
    }

    func testApplyMergedRoundTripsAndIsolatesOtherBooks() throws {
        let store = HighlightStore(storeURL: highlightURL)
        let keep = store.add(bookID: "book-b", locator: try locator(), color: .green)

        let active = SyncedHighlight(
            id: "remote-1", locatorJSON: "{}", colorRaw: "blue", note: "from B",
            createdAt: Date(), updatedAt: Date(), deletedAt: nil, text: "remote"
        )
        let tombstone = SyncedHighlight(
            id: "remote-2", locatorJSON: "{}", colorRaw: "pink", note: nil,
            createdAt: Date(), updatedAt: Date(), deletedAt: Date(), text: "gone"
        )
        store.applyMerged([active, tombstone], bookID: "book-a")

        XCTAssertEqual(store.highlights(for: "book-a").map(\.id), ["remote-1"], "アクティブなレコードのみ表示")
        XCTAssertEqual(Set(store.syncedRecords(for: "book-a").map(\.id)), ["remote-1", "remote-2"], "墓標込みで同期")
        XCTAssertEqual(store.highlights(for: "book-b").map(\.id), [keep.id], "他の本のレコードは影響を受けない")
    }

    // MARK: - Bookmarks

    func testBookmarkRemoveLeavesTombstoneAndClearsPresence() throws {
        let store = BookmarkStore(storeURL: bookmarkURL)
        let loc = try locator()
        let added = store.add(bookID: "book-a", locator: loc, title: nil)

        store.remove(added.id)

        XCTAssertFalse(store.isBookmarked(bookID: "book-a", at: loc), "削除後はブックマーク無し")
        let synced = store.syncedRecords(for: "book-a")
        XCTAssertEqual(synced.count, 1)
        XCTAssertNotNil(synced.first?.deletedAt, "墓標が残る")
    }

    func testBookmarkApplyMergedRebuildsPresence() throws {
        let store = BookmarkStore(storeURL: bookmarkURL)
        let loc = try locator(href: "ch2.html", progression: 0.5)
        let record = SyncedBookmark(
            id: "remote-1",
            locatorJSON: (try? loc.jsonString()) ?? "{}",
            title: "Chapter 2",
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil
        )

        store.applyMerged([record], bookID: "book-a")

        XCTAssertEqual(store.bookmarks(for: "book-a").map(\.id), ["remote-1"])
        XCTAssertTrue(store.isBookmarked(bookID: "book-a", at: loc), "適用後は locator キャッシュも再構築され在席判定できる")
    }
}
