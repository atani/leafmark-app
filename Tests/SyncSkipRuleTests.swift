import XCTest
@testable import Leafmark

/// Pins the rules that let a sync reconcile pass skip work when nothing
/// changed: `LibraryStore.shouldApplySyncedPosition` and
/// `Array.replacingRecords(of:with:now:)`. The stores' publish/write skip
/// itself is covered in HighlightStoreTests / BookmarkStoreTests.
final class SyncSkipRuleTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func book(locatorJSON: String? = #"{"href":"a"}"#, progression: Double? = 0.4, updatedAt: Date?) -> Book {
        Book(
            id: "book",
            fileName: "book.epub",
            title: "T",
            addedAt: base,
            progression: progression,
            locatorJSON: locatorJSON,
            positionUpdatedAt: updatedAt
        )
    }

    private func position(locatorJSON: String = #"{"href":"a"}"#, progression: Double? = 0.4, updatedAt: Date) -> AnnotationSyncPosition {
        AnnotationSyncPosition(locatorJSON: locatorJSON, progression: progression, updatedAt: updatedAt)
    }

    // MARK: - shouldApplySyncedPosition

    func testNewerPositionIsApplied() {
        let remote = position(locatorJSON: #"{"href":"b"}"#, progression: 0.6, updatedAt: base.addingTimeInterval(60))
        XCTAssertTrue(LibraryStore.shouldApplySyncedPosition(remote, to: book(updatedAt: base)))
    }

    func testIdenticalPositionIsSkipped() {
        XCTAssertFalse(
            LibraryStore.shouldApplySyncedPosition(position(updatedAt: base), to: book(updatedAt: base)),
            "3 項目とも一致すれば適用しない"
        )
    }

    func testOlderPositionIsSkipped() {
        let stale = position(locatorJSON: #"{"href":"b"}"#, updatedAt: base.addingTimeInterval(-60))
        XCTAssertFalse(LibraryStore.shouldApplySyncedPosition(stale, to: book(updatedAt: base)), "古い位置は適用しない")
    }

    func testSameTimestampWithDifferentLocatorIsApplied() {
        let remote = position(locatorJSON: #"{"href":"b"}"#, updatedAt: base)
        XCTAssertTrue(
            LibraryStore.shouldApplySyncedPosition(remote, to: book(updatedAt: base)),
            "同時刻でも位置が違えば従来どおり適用する"
        )
    }

    func testMissingBookIsSkipped() {
        XCTAssertFalse(LibraryStore.shouldApplySyncedPosition(position(updatedAt: base), to: nil))
    }

    // MARK: - replacingRecords

    private func highlight(_ id: String, book: String, deletedAt: Date? = nil) -> Highlight {
        Highlight(
            id: id,
            bookID: book,
            locatorJSON: "{}",
            colorRaw: "yellow",
            createdAt: base,
            updatedAt: deletedAt ?? base,
            deletedAt: deletedAt,
            text: id
        )
    }

    func testUnchangedBookYieldsNil() {
        let records = [highlight("a1", book: "a"), highlight("a2", book: "a"), highlight("b1", book: "b")]
        let incoming = [records[1], records[0]]

        XCTAssertNil(records.replacingRecords(of: "a", with: incoming, now: base), "順序だけ違う同じレコードは変化なし")
    }

    func testExpiredTombstoneOfAnotherBookIsStillPruned() throws {
        let expiredAt = base.addingTimeInterval(-AnnotationSyncMerge.tombstoneRetention - 1)
        let records = [highlight("a1", book: "a"), highlight("b-old", book: "b", deletedAt: expiredAt)]

        let replaced = try XCTUnwrap(
            records.replacingRecords(of: "a", with: [records[0]], now: base),
            "他の本に期限切れの墓標があれば置き換えを行う"
        )
        XCTAssertEqual(replaced.map(\.id), ["a1"], "他の本の期限切れ墓標も刈り取られる")
    }

    func testExpiredTombstoneOfTheSameBookIsPruned() throws {
        let expiredAt = base.addingTimeInterval(-AnnotationSyncMerge.tombstoneRetention - 1)
        let records = [highlight("a1", book: "a"), highlight("a-old", book: "a", deletedAt: expiredAt)]

        let replaced = try XCTUnwrap(records.replacingRecords(of: "a", with: records, now: base))
        XCTAssertEqual(replaced.map(\.id), ["a1"])
    }

    func testChangedRecordReplacesOnlyThatBook() throws {
        let records = [highlight("b1", book: "b"), highlight("a1", book: "a")]
        var edited = records[1]
        edited.note = "edited"

        let replaced = try XCTUnwrap(records.replacingRecords(of: "a", with: [edited], now: base))
        XCTAssertEqual(replaced, [records[0], edited], "他の本のレコードは順序ごと残る")
    }
}
