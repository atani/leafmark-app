import XCTest
@testable import Leafmark

/// Restore-hint derivation and sidecar decode compatibility. Both are exercised
/// as pure logic so no iCloud container or filesystem state is required.
final class CatalogMissingBooksTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func record(
        id: String,
        title: String = "Book",
        author: String? = nil,
        deletedAt: Date? = nil
    ) -> CatalogRecord {
        CatalogRecord(id: id, title: title, author: author, updatedAt: base, deletedAt: deletedAt)
    }

    // MARK: - Derivation

    func testRemoteOnlyBookIsIncluded() {
        let catalog = [record(id: "k-remote", title: "Meditations", author: "Marcus Aurelius")]

        let missing = LibraryStore.missingBooks(from: catalog, localContentKeys: [])

        XCTAssertEqual(missing.map(\.contentKey), ["k-remote"], "ローカルに無い本は復元候補に含める")
        XCTAssertEqual(missing.first?.title, "Meditations")
        XCTAssertEqual(missing.first?.author, "Marcus Aurelius")
    }

    func testLocallyPresentBookIsExcluded() {
        let catalog = [record(id: "k-local")]

        let missing = LibraryStore.missingBooks(from: catalog, localContentKeys: ["k-local"])

        XCTAssertTrue(missing.isEmpty, "ローカルに存在する本は候補から除外する")
    }

    func testTombstonedBookIsExcluded() {
        let catalog = [record(id: "k-deleted", deletedAt: base)]

        let missing = LibraryStore.missingBooks(from: catalog, localContentKeys: [])

        XCTAssertTrue(missing.isEmpty, "墓標付き(意図的に削除)の本は候補から除外する")
    }

    func testMixedCatalogSortsByTitle() {
        let catalog = [
            record(id: "k1", title: "Zeno"),
            record(id: "k2", title: "Aristotle"),
            record(id: "k3", title: "present"),
            record(id: "k4", title: "Deleted", deletedAt: base),
        ]

        let missing = LibraryStore.missingBooks(from: catalog, localContentKeys: ["k3"])

        XCTAssertEqual(missing.map(\.title), ["Aristotle", "Zeno"], "候補はタイトル昇順、ローカル本と墓標は除外")
    }

    func testEmptyCatalogYieldsNoMissingBooks() {
        XCTAssertTrue(
            LibraryStore.missingBooks(from: [], localContentKeys: ["k1"]).isEmpty,
            "空カタログ(未同期・ファイル欠損)なら候補は空"
        )
    }

    // MARK: - Sidecar decode compatibility

    func testEmptyCatalogDocumentDecodes() throws {
        let json = """
        {"schemaVersion":1,"books":[]}
        """
        let catalog = try JSONDecoder().decode(LibraryCatalog.self, from: Data(json.utf8))

        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertTrue(catalog.books.isEmpty)
    }

    func testRecordWithoutOptionalFieldsDecodes() throws {
        // author と deletedAt を持たないレコードも復号できる（additive migration）。
        let json = """
        {"schemaVersion":1,"books":[{"id":"k1","title":"Frankenstein","updatedAt":0}]}
        """
        let catalog = try JSONDecoder().decode(LibraryCatalog.self, from: Data(json.utf8))

        XCTAssertEqual(catalog.books.first?.id, "k1")
        XCTAssertNil(catalog.books.first?.author, "author が無ければ nil で復号")
        XCTAssertNil(catalog.books.first?.deletedAt, "deletedAt が無ければ nil で復号")
    }

    func testMissingOrEmptySidecarDecodesToNil() {
        // 欠損ファイルは Data(contentsOf:) が nil を返し、空/破損データは decode が
        // 失敗する。どちらも store 側の try? で握られ、既定の空カタログに落ちる。
        XCTAssertNil(try? JSONDecoder().decode(LibraryCatalog.self, from: Data()), "空データは復号できない(既定へフォールバック)")
        XCTAssertNil(try? JSONDecoder().decode(LibraryCatalog.self, from: Data("not json".utf8)), "破損データは復号できない")
    }
}
