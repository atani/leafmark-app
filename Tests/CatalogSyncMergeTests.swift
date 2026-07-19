import XCTest
@testable import Leafmark

/// The library catalog merge reuses `AnnotationSyncMerge.mergeRecords`, so these
/// tests pin the catalog-specific semantics (union, LWW, tombstone
/// wins/loses/revive-on-reimport, pruning) on `CatalogSyncMerge` directly.
final class CatalogSyncMergeTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func at(_ offset: TimeInterval) -> Date {
        base.addingTimeInterval(offset)
    }

    private func record(
        id: String,
        title: String = "Frankenstein",
        author: String? = nil,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) -> CatalogRecord {
        CatalogRecord(id: id, title: title, author: author, updatedAt: updatedAt, deletedAt: deletedAt)
    }

    private func catalog(_ records: [CatalogRecord]) -> LibraryCatalog {
        LibraryCatalog(books: records)
    }

    // MARK: - Union

    func testUnionAcrossDevices() {
        let a = catalog([record(id: "k1", updatedAt: at(0))])
        let b = catalog([record(id: "k2", updatedAt: at(0))])

        let merged = CatalogSyncMerge.merge([a, b], now: at(10))

        XCTAssertEqual(merged.books.map(\.id), ["k1", "k2"], "両端末のレコードを和集合にする")
    }

    // MARK: - Last-writer-wins

    func testNewerMetadataWinsRegardlessOfOrder() {
        let older = catalog([record(id: "k1", title: "old", updatedAt: at(0))])
        let newer = catalog([record(id: "k1", title: "new", updatedAt: at(100))])

        let ab = CatalogSyncMerge.merge([older, newer], now: at(200))
        let ba = CatalogSyncMerge.merge([newer, older], now: at(200))

        XCTAssertEqual(ab.books.first?.title, "new", "新しいメタデータが勝つ")
        XCTAssertEqual(ba.books.first?.title, "new", "順序を入れ替えても同じ（可換）")
    }

    // MARK: - Tombstones

    func testDeletionWinsOverOlderRecord() {
        let alive = catalog([record(id: "k1", updatedAt: at(0))])
        let deleted = catalog([record(id: "k1", updatedAt: at(100), deletedAt: at(100))])

        let merged = CatalogSyncMerge.merge([alive, deleted], now: at(200))

        XCTAssertNotNil(merged.books.first?.deletedAt, "古いレコードより新しい削除が勝つ")
    }

    func testDeletionLosesToNewerRecord() {
        let deleted = catalog([record(id: "k1", updatedAt: at(0), deletedAt: at(0))])
        let alive = catalog([record(id: "k1", title: "revived", updatedAt: at(100))])

        let merged = CatalogSyncMerge.merge([deleted, alive], now: at(200))

        XCTAssertNil(merged.books.first?.deletedAt, "古い削除より新しいレコードが勝つ")
        XCTAssertEqual(merged.books.first?.title, "revived")
    }

    /// The core "re-import restores the book" behaviour: a re-import writes a
    /// record whose `updatedAt` is later than the tombstone, clearing it.
    func testTombstoneRevivesOnReimport() {
        let tombstoned = catalog([record(id: "k1", updatedAt: at(0), deletedAt: at(0))])
        let reimported = catalog([record(id: "k1", title: "back", updatedAt: at(100))])

        let ab = CatalogSyncMerge.merge([tombstoned, reimported], now: at(200))
        let ba = CatalogSyncMerge.merge([reimported, tombstoned], now: at(200))

        XCTAssertNil(ab.books.first?.deletedAt, "再取り込み(updatedAt > deletedAt)で墓標が解除される")
        XCTAssertEqual(ab.books.first?.title, "back")
        XCTAssertNil(ba.books.first?.deletedAt, "順序不問で復活する")
    }

    // MARK: - Pruning

    func testOldTombstoneIsPruned() {
        let now = at(0)
        let expired = now.addingTimeInterval(-(AnnotationSyncMerge.tombstoneRetention + 1))
        let merged = CatalogSyncMerge.merge(
            [catalog([record(id: "k1", updatedAt: expired, deletedAt: expired)])],
            now: now
        )

        XCTAssertTrue(merged.books.isEmpty, "保持期間を過ぎた墓標は除去する")
    }

    func testRecentTombstoneIsKept() {
        let now = at(0)
        let recent = now.addingTimeInterval(-(AnnotationSyncMerge.tombstoneRetention - 1))
        let merged = CatalogSyncMerge.merge(
            [catalog([record(id: "k1", updatedAt: recent, deletedAt: recent)])],
            now: now
        )

        XCTAssertEqual(merged.books.count, 1, "保持期間内の墓標は残す（削除を伝播できるように）")
        XCTAssertNotNil(merged.books.first?.deletedAt)
    }

    // MARK: - Degenerate inputs

    func testEmptyInputYieldsEmptyCatalog() {
        let merged = CatalogSyncMerge.merge([], now: at(0))

        XCTAssertTrue(merged.books.isEmpty)
        XCTAssertEqual(merged.schemaVersion, librarySyncSchemaVersion)
    }

    func testMergeIsIdempotent() {
        let a = catalog([
            record(id: "k1", updatedAt: at(0)),
            record(id: "k2", updatedAt: at(50), deletedAt: at(50)),
        ])

        let once = CatalogSyncMerge.merge([a], now: at(100))
        let twice = CatalogSyncMerge.merge([once, once], now: at(100))

        XCTAssertEqual(once, twice, "同じ入力の再 merge は結果を変えない（冪等）")
    }
}
