import XCTest
@testable import Leafmark

final class AnnotationSyncMergeTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func at(_ offset: TimeInterval) -> Date {
        base.addingTimeInterval(offset)
    }

    private func highlight(
        id: String,
        note: String? = nil,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) -> SyncedHighlight {
        SyncedHighlight(
            id: id,
            locatorJSON: "{}",
            colorRaw: "yellow",
            note: note,
            createdAt: base,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            text: "text"
        )
    }

    private func bookmark(id: String, updatedAt: Date, deletedAt: Date? = nil) -> SyncedBookmark {
        SyncedBookmark(
            id: id,
            locatorJSON: "{}",
            title: nil,
            createdAt: base,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }

    private func doc(
        highlights: [SyncedHighlight] = [],
        bookmarks: [SyncedBookmark] = [],
        position: AnnotationSyncPosition? = nil
    ) -> AnnotationSyncDocument {
        AnnotationSyncDocument(highlights: highlights, bookmarks: bookmarks, position: position)
    }

    // MARK: - Union

    func testUnionAcrossSources() {
        let a = doc(highlights: [highlight(id: "h1", updatedAt: at(0))])
        let b = doc(highlights: [highlight(id: "h2", updatedAt: at(0))])

        let merged = AnnotationSyncMerge.merge([a, b], now: at(10))

        XCTAssertEqual(merged.highlights.map(\.id), ["h1", "h2"], "両ソースのレコードを和集合にする")
    }

    func testUnionMergesBookmarksToo() {
        let a = doc(bookmarks: [bookmark(id: "b1", updatedAt: at(0))])
        let b = doc(bookmarks: [bookmark(id: "b2", updatedAt: at(0))])

        let merged = AnnotationSyncMerge.merge([a, b], now: at(10))

        XCTAssertEqual(merged.bookmarks.map(\.id), ["b1", "b2"], "ブックマークも和集合")
    }

    // MARK: - Last-writer-wins

    func testNewerEditWinsRegardlessOfOrder() {
        let older = doc(highlights: [highlight(id: "h1", note: "old", updatedAt: at(0))])
        let newer = doc(highlights: [highlight(id: "h1", note: "new", updatedAt: at(100))])

        let ab = AnnotationSyncMerge.merge([older, newer], now: at(200))
        let ba = AnnotationSyncMerge.merge([newer, older], now: at(200))

        XCTAssertEqual(ab.highlights.first?.note, "new", "新しい編集が勝つ")
        XCTAssertEqual(ba.highlights.first?.note, "new", "順序を入れ替えても同じ（可換）")
    }

    // MARK: - Tombstones

    func testDeletionWinsOverOlderEdit() {
        let edit = doc(highlights: [highlight(id: "h1", note: "edit", updatedAt: at(0))])
        let delete = doc(highlights: [highlight(id: "h1", updatedAt: at(100), deletedAt: at(100))])

        let merged = AnnotationSyncMerge.merge([edit, delete], now: at(200))

        XCTAssertNotNil(merged.highlights.first?.deletedAt, "古い編集より新しい削除が勝つ")
    }

    func testDeletionLosesToNewerEdit() {
        let delete = doc(highlights: [highlight(id: "h1", updatedAt: at(0), deletedAt: at(0))])
        let edit = doc(highlights: [highlight(id: "h1", note: "revived", updatedAt: at(100))])

        let merged = AnnotationSyncMerge.merge([delete, edit], now: at(200))

        XCTAssertNil(merged.highlights.first?.deletedAt, "古い削除より新しい編集が勝つ")
        XCTAssertEqual(merged.highlights.first?.note, "revived")
    }

    func testEqualTimestampPrefersDeletion() {
        let edit = doc(highlights: [highlight(id: "h1", note: "edit", updatedAt: at(50))])
        let delete = doc(highlights: [highlight(id: "h1", updatedAt: at(50), deletedAt: at(50))])

        let ab = AnnotationSyncMerge.merge([edit, delete], now: at(200))
        let ba = AnnotationSyncMerge.merge([delete, edit], now: at(200))

        XCTAssertNotNil(ab.highlights.first?.deletedAt, "同時刻なら削除を優先（順序不問）")
        XCTAssertNotNil(ba.highlights.first?.deletedAt, "逆順でも削除を優先")
    }

    // MARK: - Tombstone pruning

    func testOldTombstoneIsPruned() {
        let now = at(0)
        let expired = now.addingTimeInterval(-(AnnotationSyncMerge.tombstoneRetention + 1))
        let merged = AnnotationSyncMerge.merge(
            [doc(highlights: [highlight(id: "h1", updatedAt: expired, deletedAt: expired)])],
            now: now
        )

        XCTAssertTrue(merged.highlights.isEmpty, "保持期間を過ぎた墓標は除去する")
    }

    func testRecentTombstoneIsKept() {
        let now = at(0)
        let recent = now.addingTimeInterval(-(AnnotationSyncMerge.tombstoneRetention - 1))
        let merged = AnnotationSyncMerge.merge(
            [doc(highlights: [highlight(id: "h1", updatedAt: recent, deletedAt: recent)])],
            now: now
        )

        XCTAssertEqual(merged.highlights.count, 1, "保持期間内の墓標は残す（削除を伝播できるように）")
        XCTAssertNotNil(merged.highlights.first?.deletedAt)
    }

    // MARK: - Position

    func testPositionLastWriterWins() {
        let a = doc(position: AnnotationSyncPosition(locatorJSON: "A", progression: 0.1, updatedAt: at(0)))
        let b = doc(position: AnnotationSyncPosition(locatorJSON: "B", progression: 0.9, updatedAt: at(100)))

        XCTAssertEqual(AnnotationSyncMerge.merge([a, b], now: at(200)).position?.locatorJSON, "B")
        XCTAssertEqual(AnnotationSyncMerge.merge([b, a], now: at(200)).position?.locatorJSON, "B", "順序不問")
    }

    func testPositionNilHandling() {
        let some = doc(position: AnnotationSyncPosition(locatorJSON: "A", progression: nil, updatedAt: at(0)))
        let none = doc(position: nil)

        XCTAssertEqual(AnnotationSyncMerge.merge([some, none], now: at(10)).position?.locatorJSON, "A", "片方 nil なら非 nil が勝つ")
        XCTAssertNil(AnnotationSyncMerge.merge([none, none], now: at(10)).position, "両方 nil なら nil")
    }

    // MARK: - Empty / degenerate inputs

    func testEmptyInputYieldsEmptyDocument() {
        let merged = AnnotationSyncMerge.merge([], now: at(0))

        XCTAssertTrue(merged.highlights.isEmpty)
        XCTAssertTrue(merged.bookmarks.isEmpty)
        XCTAssertNil(merged.position)
        XCTAssertEqual(merged.schemaVersion, annotationSyncSchemaVersion)
    }

    func testMergingWithEmptyDocumentIsIdentity() {
        let content = doc(
            highlights: [highlight(id: "h1", updatedAt: at(0))],
            position: AnnotationSyncPosition(locatorJSON: "A", progression: 0.5, updatedAt: at(0))
        )

        let merged = AnnotationSyncMerge.merge([doc(), content], now: at(10))

        XCTAssertEqual(merged.highlights.map(\.id), ["h1"], "空ドキュメントとの merge は恒等")
        XCTAssertEqual(merged.position?.locatorJSON, "A")
    }

    // MARK: - Idempotency

    func testMergeIsIdempotent() {
        let a = doc(
            highlights: [highlight(id: "h1", updatedAt: at(0)), highlight(id: "h2", updatedAt: at(50), deletedAt: at(50))],
            bookmarks: [bookmark(id: "b1", updatedAt: at(0))],
            position: AnnotationSyncPosition(locatorJSON: "A", progression: 0.2, updatedAt: at(0))
        )

        let once = AnnotationSyncMerge.merge([a], now: at(100))
        let twice = AnnotationSyncMerge.merge([once, once], now: at(100))

        XCTAssertEqual(once, twice, "同じ入力の再 merge は結果を変えない（冪等）")
    }
}
