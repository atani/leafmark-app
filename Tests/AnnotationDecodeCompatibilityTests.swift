import XCTest
@testable import Leafmark

/// Catalogs written before annotation sync existed must keep decoding, with the
/// new fields defaulting to nil (ADR-0002's additive-migration strategy).
final class AnnotationDecodeCompatibilityTests: XCTestCase {
    func testBookWithoutSyncFieldsDecodes() throws {
        let json = """
        {"id":"book-1","fileName":"book-1.epub","title":"Frankenstein","addedAt":0}
        """
        let book = try JSONDecoder().decode(Book.self, from: Data(json.utf8))

        XCTAssertEqual(book.id, "book-1")
        XCTAssertEqual(book.title, "Frankenstein")
        XCTAssertNil(book.contentKey, "旧カタログには contentKey が無く nil で復号される")
        XCTAssertNil(book.positionUpdatedAt, "旧カタログには positionUpdatedAt が無く nil で復号される")
    }

    func testHighlightWithoutSyncFieldsDecodes() throws {
        let json = """
        {"id":"h1","bookID":"book-1","locatorJSON":"{}","colorRaw":"yellow","createdAt":100,"text":"quote"}
        """
        let highlight = try JSONDecoder().decode(Highlight.self, from: Data(json.utf8))

        XCTAssertNil(highlight.updatedAt, "旧ハイライトに updatedAt は無い")
        XCTAssertNil(highlight.deletedAt, "旧ハイライトに deletedAt は無い")
        XCTAssertEqual(
            highlight.effectiveUpdatedAt,
            Date(timeIntervalSinceReferenceDate: 100),
            "updatedAt が無ければ createdAt にフォールバックする"
        )
    }

    func testBookmarkWithoutSyncFieldsDecodes() throws {
        let json = """
        {"id":"b1","bookID":"book-1","locatorJSON":"{}","createdAt":200}
        """
        let bookmark = try JSONDecoder().decode(Bookmark.self, from: Data(json.utf8))

        XCTAssertNil(bookmark.updatedAt)
        XCTAssertNil(bookmark.deletedAt)
        XCTAssertEqual(bookmark.effectiveUpdatedAt, Date(timeIntervalSinceReferenceDate: 200))
    }
}
