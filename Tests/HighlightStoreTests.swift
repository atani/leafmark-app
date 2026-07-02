import XCTest
import ReadiumShared
@testable import Inkwell

@MainActor
final class HighlightStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("highlights-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    /// Builds a Highlight whose locator carries a totalProgression so the
    /// store can sort and render the "— at N%" line.
    private func highlight(
        id: String,
        bookID: String,
        text: String,
        note: String? = nil,
        progression: Double
    ) -> Highlight {
        let locatorJSON = """
        {"href":"chapter.html","type":"text/html","locations":{"totalProgression":\(progression)}}
        """
        return Highlight(
            id: id,
            bookID: bookID,
            locatorJSON: locatorJSON,
            colorRaw: "yellow",
            note: note,
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            text: text
        )
    }

    private func seed(_ highlights: [Highlight]) -> HighlightStore {
        let data = try! JSONEncoder().encode(highlights)
        try! data.write(to: tempURL)
        return HighlightStore(storeURL: tempURL)
    }

    func testHighlightsForBookSortedByProgression() {
        let store = seed([
            highlight(id: "2", bookID: "book-a", text: "second", progression: 0.8),
            highlight(id: "1", bookID: "book-a", text: "first", progression: 0.2),
            highlight(id: "x", bookID: "book-b", text: "other", progression: 0.5),
        ])

        let result = store.highlights(for: "book-a")
        XCTAssertEqual(result.map(\.id), ["1", "2"], "読書位置順に並ぶ")
        XCTAssertTrue(store.highlights(for: "book-b").map(\.id) == ["x"], "別の本は混ざらない")
    }

    func testExportMarkdownContainsTitleAuthorQuotesAndNotes() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "an important line", note: "my note", progression: 0.25),
            highlight(id: "2", bookID: "book-a", text: "another line", progression: 0.5),
        ])
        let book = Book(
            id: "book-a",
            fileName: "book-a.epub",
            title: "Test Book",
            author: "Jane Doe",
            addedAt: Date()
        )

        let md = store.exportMarkdown(for: book)

        XCTAssertTrue(md.hasPrefix("# Test Book"), "見出しに書名")
        XCTAssertTrue(md.contains("by Jane Doe"), "著者名")
        XCTAssertTrue(md.contains("> an important line"), "ハイライトは引用ブロック")
        XCTAssertTrue(md.contains("my note"), "ノートを含む")
        XCTAssertTrue(md.contains("— at 25%"), "進捗パーセント")
        XCTAssertTrue(md.contains("> another line"))
        // 並び順: 25% の引用が 50% より前に出る
        let firstIndex = md.range(of: "an important line")!.lowerBound
        let secondIndex = md.range(of: "another line")!.lowerBound
        XCTAssertLessThan(firstIndex, secondIndex)
    }

    func testExportMarkdownOmitsAuthorLineWhenNil() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "line", progression: 0.1),
        ])
        let book = Book(id: "book-a", fileName: "b.epub", title: "No Author", author: nil, addedAt: Date())

        let md = store.exportMarkdown(for: book)
        XCTAssertTrue(md.hasPrefix("# No Author"))
        XCTAssertFalse(md.contains("by "), "著者 nil なら by 行を出さない")
    }

    func testMultilineHighlightBecomesMultilineQuote() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "line one\nline two", progression: 0.3),
        ])
        let book = Book(id: "book-a", fileName: "b.epub", title: "T", author: nil, addedAt: Date())

        let md = store.exportMarkdown(for: book)
        XCTAssertTrue(md.contains("> line one\n> line two"), "改行ごとに引用記号を付ける")
    }

    func testRemoveAllForBookRemovesOnlyThatBook() {
        let store = seed([
            highlight(id: "a1", bookID: "book-a", text: "one", progression: 0.1),
            highlight(id: "a2", bookID: "book-a", text: "two", progression: 0.2),
            highlight(id: "b1", bookID: "book-b", text: "keep", progression: 0.3),
        ])

        store.removeAll(for: "book-a")

        XCTAssertTrue(store.highlights(for: "book-a").isEmpty, "対象の本のハイライトは全削除")
        XCTAssertEqual(store.highlights(for: "book-b").map(\.id), ["b1"], "他の本は残る")

        let reloaded = HighlightStore(storeURL: tempURL)
        XCTAssertTrue(reloaded.highlights(for: "book-a").isEmpty, "削除が永続化される")
        XCTAssertEqual(reloaded.highlights(for: "book-b").count, 1)
    }

    func testAddAndRemoveMutateInMemoryAndPersist() throws {
        let store = HighlightStore(storeURL: tempURL)
        let json = """
        {"href":"chapter.html","type":"text/html","text":{"highlight":"captured text"},"locations":{"totalProgression":0.3}}
        """
        let value = try JSONValue(jsonString: json)
        let locator = try XCTUnwrap(try? Locator(json: value, warnings: nil))
        let added = store.add(bookID: "book-a", locator: locator, color: .green, note: "n")
        XCTAssertEqual(store.highlights(for: "book-a").count, 1)
        XCTAssertEqual(added.text, "captured text", "ハイライト本文を locator から取り込む")

        let reloaded = HighlightStore(storeURL: tempURL)
        XCTAssertEqual(reloaded.highlights(for: "book-a").count, 1, "永続化される")

        store.remove(added.id)
        XCTAssertEqual(store.highlights(for: "book-a").count, 0)
    }
}
