import XCTest
import ReadiumNavigator
import ReadiumShared
@testable import Inkwell

@MainActor
final class FontStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fontstore-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    /// Writes a dummy file with the given name into a scratch inbox and
    /// returns its URL. The bytes are not a real font, so family-name and
    /// trait extraction fall back — which makes tests deterministic
    /// without bundling font fixtures.
    private func makeFile(named name: String, contents: String = "not-a-real-font") throws -> URL {
        let inbox = tempDir.appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let url = inbox.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    // MARK: - Import

    func testImportCopiesFileAndFallsBackToFileName() throws {
        let store = FontStore(directory: tempDir)
        let source = try makeFile(named: "Literata.ttf")

        let font = store.importFont(from: source)

        let imported = try XCTUnwrap(font)
        XCTAssertEqual(imported.familyName, "Literata", "壊れたフォントはファイル名にフォールバック")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: store.fileURL(for: imported).path),
            "フォントファイルがストアにコピーされる"
        )
        XCTAssertEqual(store.fonts.count, 1)
    }

    func testImportRejectsUnsupportedExtension() throws {
        let store = FontStore(directory: tempDir)
        let source = try makeFile(named: "Literata.zip")

        XCTAssertNil(store.importFont(from: source))
        XCTAssertTrue(store.fonts.isEmpty)
    }

    func testImportRejectsOversizedFile() throws {
        let store = FontStore(directory: tempDir)
        let inbox = tempDir.appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let url = inbox.appendingPathComponent("Huge.ttf")
        let oversized = Data(count: FontStore.maxFontFileSize + 1)
        try oversized.write(to: url)

        XCTAssertNil(store.importFont(from: url))
        XCTAssertTrue(store.fonts.isEmpty)
    }

    func testImportDeduplicatesIdenticalFile() throws {
        let store = FontStore(directory: tempDir)
        let source = try makeFile(named: "Alpha.ttf")

        let first = try XCTUnwrap(store.importFont(from: source))
        let second = try XCTUnwrap(store.importFont(from: source))

        XCTAssertEqual(first.id, second.id, "同一内容の再インポートは既存エントリを返す")
        XCTAssertEqual(store.fonts.count, 1)
    }

    func testImportKeepsDistinctFilesOfSameFamily() throws {
        let store = FontStore(directory: tempDir)
        // 同名ファミリー（ファイル名フォールバック）だが中身が違う =
        // regular/bold のような正当な別 face は両方残る。
        let regular = try makeFile(named: "Alpha.ttf", contents: "regular-bytes")
        let inbox = tempDir.appendingPathComponent("inbox", isDirectory: true)
        let boldURL = inbox.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: boldURL, withIntermediateDirectories: true)
        let bold = boldURL.appendingPathComponent("Alpha.ttf")
        try Data("bold-bytes".utf8).write(to: bold)

        store.importFont(from: regular)
        store.importFont(from: bold)

        XCTAssertEqual(store.fonts.count, 2)
        XCTAssertEqual(Set(store.fonts.map(\.familyName)), ["Alpha"])
    }

    // MARK: - Persistence

    func testCatalogPersistsAcrossInstances() throws {
        let store = FontStore(directory: tempDir)
        store.importFont(from: try makeFile(named: "Alpha.ttf"))
        store.importFont(from: try makeFile(named: "Beta.otf"))

        let reloaded = FontStore(directory: tempDir)
        XCTAssertEqual(reloaded.fonts.map(\.familyName).sorted(), ["Alpha", "Beta"])
    }

    func testRemoveDeletesFileAndPersists() throws {
        let store = FontStore(directory: tempDir)
        let font = try XCTUnwrap(store.importFont(from: try makeFile(named: "Alpha.ttf")))
        let fileURL = store.fileURL(for: font)

        store.remove(font)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(store.fonts.isEmpty)
        XCTAssertTrue(FontStore(directory: tempDir).fonts.isEmpty, "削除が永続化される")
    }

    func testLoadDropsEntriesWithMissingFiles() throws {
        let store = FontStore(directory: tempDir)
        let font = try XCTUnwrap(store.importFont(from: try makeFile(named: "Alpha.ttf")))
        // 部分的なリストア等でファイルだけ消えた状況を再現する。
        try FileManager.default.removeItem(at: store.fileURL(for: font))

        XCTAssertTrue(FontStore(directory: tempDir).fonts.isEmpty)
    }

    // MARK: - Sanitization

    func testSanitizedFamilyNameStripsUnsafeCharacters() {
        XCTAssertEqual(
            FontStore.sanitizedFamilyName(#"Bad"</style><script>Name"#),
            "BadstylescriptName",
            "CSS/HTML を壊す文字はすべて除去される"
        )
        XCTAssertEqual(FontStore.sanitizedFamilyName("游明朝 Medium"), "游明朝 Medium", "CJK は保持")
        XCTAssertEqual(FontStore.sanitizedFamilyName("Iowan Old Style"), "Iowan Old Style")
        XCTAssertNil(FontStore.sanitizedFamilyName("\"\\<>/"), "安全な文字が残らなければ nil")
    }

    // MARK: - Declarations

    /// Applies every declaration to an empty document and returns the
    /// resulting HTML, for content-level assertions.
    private func injectAll(
        _ declarations: [AnyHTMLFontFamilyDeclaration],
        into html: String = "<html><head></head><body></body></html>"
    ) throws -> String {
        var result = html
        for declaration in declarations {
            result = try declaration.inject(in: result) { _ in
                throw URLError(.badURL) // data URI 実装は servingFile を呼ばない
            }
        }
        return result
    }

    func testDeclarationsOnlyCoverRequestedFamily() throws {
        let store = FontStore(directory: tempDir)
        store.importFont(from: try makeFile(named: "Alpha.ttf", contents: "alpha-bytes"))
        store.importFont(from: try makeFile(named: "Beta.otf", contents: "beta-bytes"))

        XCTAssertEqual(store.fontFamilyDeclarations(for: "Alpha").count, 1)
        XCTAssertTrue(store.fontFamilyDeclarations(for: nil).isEmpty, "未選択なら埋め込まない")
        XCTAssertTrue(store.fontFamilyDeclarations(for: "Gamma").isEmpty)

        let html = try injectAll(store.fontFamilyDeclarations(for: "Alpha"))
        XCTAssertTrue(html.contains("data:font/ttf;base64,\(Data("alpha-bytes".utf8).base64EncodedString())"))
        XCTAssertFalse(html.contains("Beta"), "選択外ファミリーのバイト列は埋め込まれない")
    }

    func testDeclarationIncludesAllFacesOfFamily() throws {
        let store = FontStore(directory: tempDir)
        store.importFont(from: try makeFile(named: "Alpha.ttf", contents: "regular-bytes"))
        let inbox = tempDir.appendingPathComponent("inbox/sub", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let bold = inbox.appendingPathComponent("Alpha.otf")
        try Data("bold-bytes".utf8).write(to: bold)
        store.importFont(from: bold)

        let html = try injectAll(store.fontFamilyDeclarations(for: "Alpha"))
        XCTAssertEqual(html.components(separatedBy: "@font-face").count - 1, 2, "face ごとに @font-face が出る")
        XCTAssertTrue(html.contains("data:font/ttf;base64,"))
        XCTAssertTrue(html.contains("data:font/otf;base64,"))
    }

    // MARK: - DataURIFontFamilyDeclaration.inject

    func testInjectEmbedsFontFaceBeforeHeadClose() throws {
        let declaration = DataURIFontFamilyDeclaration(
            fontFamily: .init(rawValue: "Alpha"),
            faces: [.init(base64: "QUJD", format: "font/otf", cssWeight: 700, italic: true)]
        )
        let html = try declaration.inject(in: "<html><head><title>t</title></head><body>x</body></html>") { _ in
            throw URLError(.badURL)
        }

        XCTAssertTrue(html.contains(#"@font-face { font-family: "Alpha"; src: url("data:font/otf;base64,QUJD"); font-weight: 700; font-style: italic; }"#))
        let styleIndex = try XCTUnwrap(html.range(of: "<style")).lowerBound
        let headIndex = try XCTUnwrap(html.range(of: "</head>")).lowerBound
        XCTAssertLessThan(styleIndex, headIndex, "</head> の直前に挿入される")
    }

    func testInjectHandlesUppercaseHeadAndMissingHead() throws {
        let declaration = DataURIFontFamilyDeclaration(
            fontFamily: .init(rawValue: "Alpha"),
            faces: [.init(base64: "QUJD", format: "font/ttf", cssWeight: nil, italic: nil)]
        )

        let upper = try declaration.inject(in: "<HTML><HEAD></HEAD><BODY></BODY></HTML>") { _ in throw URLError(.badURL) }
        XCTAssertTrue(upper.contains("@font-face"), "大文字 </HEAD> でも挿入される")

        let headless = "<html><body>plain</body></html>"
        XCTAssertEqual(
            try declaration.inject(in: headless) { _ in throw URLError(.badURL) },
            headless,
            "</head> が無ければ原文のまま"
        )
    }

    func testInjectEscapesQuotesInFamilyName() throws {
        // import 時に除去されるが、直接構築への防御も固定する。
        let declaration = DataURIFontFamilyDeclaration(
            fontFamily: .init(rawValue: #"Fam"ily"#),
            faces: [.init(base64: "QUJD", format: "font/ttf", cssWeight: nil, italic: nil)]
        )
        let html = try declaration.inject(in: "<html><head></head><body></body></html>") { _ in
            throw URLError(.badURL)
        }
        XCTAssertTrue(html.contains(#"font-family: "Fam\"ily";"#), "引用符はエスケープされ CSS が壊れない")
    }
}
