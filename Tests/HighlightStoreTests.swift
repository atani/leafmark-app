import XCTest
import ReadiumShared
@testable import Leafmark

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
        color: String = "yellow",
        progression: Double
    ) -> Highlight {
        let locatorJSON = """
        {"href":"chapter.html","type":"text/html","locations":{"totalProgression":\(progression)}}
        """
        return Highlight(
            id: id,
            bookID: bookID,
            locatorJSON: locatorJSON,
            colorRaw: color,
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

        XCTAssertTrue(md.hasPrefix("---\n"), "先頭は YAML front matter")
        XCTAssertTrue(md.contains("\n# Test Book\n"), "見出しに書名")
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
        XCTAssertTrue(md.contains("\n# No Author\n"))
        XCTAssertFalse(md.contains("by "), "著者 nil なら by 行を出さない")
        XCTAssertFalse(md.contains("author:"), "著者 nil なら front matter にも author を出さない")
    }

    func testMultilineHighlightBecomesMultilineQuote() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "line one\nline two", progression: 0.3),
        ])
        let book = Book(id: "book-a", fileName: "b.epub", title: "T", author: nil, addedAt: Date())

        let md = store.exportMarkdown(for: book)
        XCTAssertTrue(md.contains("> line one\n> line two"), "改行ごとに引用記号を付ける")
    }

    func testExportFileNameUsesBookTitleAuthorAndMarkdownExtension() {
        let book = Book(
            id: "book-a",
            fileName: "b.epub",
            title: #"A/B: "Test" Book"#,
            author: "Jane Doe",
            addedAt: Date()
        )

        XCTAssertEqual(HighlightStore.exportFileName(for: book), "A B Test Book - Jane Doe.md")
    }

    func testExportFileNameFallsBackWhenTitleAndAuthorAreBlank() {
        let book = Book(
            id: "book-a",
            fileName: "b.epub",
            title: " / ",
            author: nil,
            addedAt: Date()
        )

        XCTAssertEqual(HighlightStore.exportFileName(for: book), "Highlights.md")
    }

    // MARK: - Front matter and layouts (1.19)

    func testExportMarkdownStartsWithFrontMatter() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "line", progression: 0.1),
        ])
        let book = Book(id: "book-a", fileName: "b.epub", title: "Test Book", author: "Jane Doe", addedAt: Date())
        // 2026-10-16T15:30:00Z は東京では 10-17、UTC では 10-16
        let exportedAt = Date(timeIntervalSince1970: 1_792_164_600)

        let tokyo = store.exportMarkdown(for: book, exportedAt: exportedAt, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        XCTAssertTrue(tokyo.hasPrefix("""
        ---
        title: "Test Book"
        author: "Jane Doe"
        source: Leafmark
        exported: 2026-10-17
        ---

        # Test Book
        by Jane Doe
        """), tokyo)

        let utc = store.exportMarkdown(for: book, exportedAt: exportedAt, timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertTrue(utc.contains("exported: 2026-10-16\n"), "日付は端末のタイムゾーンで決まる")
    }

    func testFrontMatterEscapesQuotesBackslashesAndNewlines() {
        let book = Book(
            id: "book-a",
            fileName: "b.epub",
            title: #"A/B: "Test" Book \ Vol.1"#,
            author: "Line\nBreak",
            addedAt: Date()
        )

        let lines = HighlightStore.frontMatter(for: book, exportedAt: Date(), timeZone: .current)

        XCTAssertEqual(lines[1], #"title: "A/B: \"Test\" Book \\ Vol.1""#)
        XCTAssertEqual(lines[2], #"author: "Line\nBreak""#)
    }

    func testHeadingAndAuthorLineCollapseLineBreaksToASpace() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "line", progression: 0.1),
        ])
        let book = Book(id: "book-a", fileName: "b.epub", title: "Part\r\nOne\rTwo\nThree", author: "Jane\nDoe", addedAt: Date())

        let md = store.exportMarkdown(for: book)

        XCTAssertTrue(md.contains("\n# Part One Two Three\nby Jane Doe\n"), md)
        XCTAssertTrue(md.contains(#"title: "Part\r\nOne\rTwo\nThree""#), "front matter は従来どおりエスケープする")
    }

    func testYAMLQuotedEscapesControlCharactersAndKeepsUnicode() {
        XCTAssertEqual(HighlightStore.yamlQuoted("yes"), #""yes""#, "暗黙の型変換を避けるため常に引用符で囲む")
        XCTAssertEqual(HighlightStore.yamlQuoted("a\tb\u{07}"), #""a\tb\u0007""#)
        XCTAssertEqual(HighlightStore.yamlQuoted("吾輩は猫である 👩‍👩‍👧"), "\"吾輩は猫である 👩‍👩‍👧\"", "日本語と絵文字はそのまま残す")
    }

    func testByColorLayoutGroupsUnderColorHeadingsInReadingOrder() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "green late", color: "green", progression: 0.9),
            highlight(id: "2", bookID: "book-a", text: "yellow mid", color: "yellow", progression: 0.5),
            highlight(id: "3", bookID: "book-a", text: "green early", color: "green", progression: 0.1),
            highlight(id: "4", bookID: "book-a", text: "unknown color", color: "purple", progression: 0.7),
        ])
        let book = Book(id: "book-a", fileName: "b.epub", title: "T", author: nil, addedAt: Date())

        let md = store.exportMarkdown(for: book, layout: .byColor)

        XCTAssertTrue(md.contains("## Yellow\n"))
        XCTAssertTrue(md.contains("## Green\n"))
        XCTAssertFalse(md.contains("## Blue"), "ハイライトの無い色は見出しを出さない")
        XCTAssertFalse(md.contains("## Pink"))
        func position(_ text: String) -> String.Index { md.range(of: text)!.lowerBound }
        // 見出しは色定義の順（Yellow → Green）、各色の中は読書位置順
        XCTAssertLessThan(position("## Yellow"), position("yellow mid"))
        XCTAssertLessThan(position("yellow mid"), position("unknown color"), "未知の色は Yellow 扱い")
        XCTAssertLessThan(position("unknown color"), position("## Green"))
        XCTAssertLessThan(position("## Green"), position("green early"))
        XCTAssertLessThan(position("green early"), position("green late"))
    }

    func testReadingOrderLayoutHasNoColorHeadings() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "green", color: "green", progression: 0.2),
            highlight(id: "2", bookID: "book-a", text: "pink", color: "pink", progression: 0.1),
        ])
        let book = Book(id: "book-a", fileName: "b.epub", title: "T", author: nil, addedAt: Date())

        let md = store.exportMarkdown(for: book, layout: .readingOrder)

        XCTAssertFalse(md.contains("## "), "読んだ順では色見出しを出さない")
        XCTAssertLessThan(md.range(of: "> pink")!.lowerBound, md.range(of: "> green")!.lowerBound)
    }

    func testExportFileUsesMarkdownExtensionAndLayout() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "q", color: "blue", progression: 0.2),
        ])
        let book = Book(id: "book-a", fileName: "b.epub", title: "T", author: "A", addedAt: Date())

        let export = store.exportFile(for: book, layout: .byColor)

        XCTAssertEqual(export.fileName, "T - A.md")
        XCTAssertTrue(export.text.contains("## Blue"))
    }

    func testExportFilesSkipsBooksWithoutHighlightsAndDedupesNames() {
        let store = seed([
            highlight(id: "1", bookID: "book-a", text: "a", progression: 0.1),
            highlight(id: "2", bookID: "book-b", text: "b", progression: 0.1),
            highlight(id: "3", bookID: "book-c", text: "c", progression: 0.1),
        ])
        store.remove("3")
        let books = [
            Book(id: "book-a", fileName: "a.epub", title: "Same", author: "Author", addedAt: Date()),
            Book(id: "book-b", fileName: "b.epub", title: "Same", author: "Author", addedAt: Date()),
            Book(id: "book-c", fileName: "c.epub", title: "Deleted Only", author: nil, addedAt: Date()),
            Book(id: "book-d", fileName: "d.epub", title: "Never Highlighted", author: nil, addedAt: Date()),
        ]

        let exports = store.exportFiles(for: books)

        XCTAssertEqual(exports.map(\.fileName), ["Same - Author.md", "Same - Author (2).md"], "削除済みのみ・未ハイライトの本は出さない")
        XCTAssertTrue(exports[1].text.contains("> b"))
    }

    func testUniqueFileNameIsCaseInsensitiveAndCountsUp() {
        let used: Set<String> = ["book.md", "book (2).md"]
        XCTAssertEqual(HighlightStore.uniqueFileName("Book.md", avoiding: used), "Book (3).md")
        XCTAssertEqual(HighlightStore.uniqueFileName("Other.md", avoiding: used), "Other.md")
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
