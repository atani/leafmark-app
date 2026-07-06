import XCTest
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
    /// returns its URL. The bytes are not a real font, so family-name
    /// extraction falls back to the file name — which makes tests
    /// deterministic without bundling font fixtures.
    private func makeFile(named name: String) throws -> URL {
        let inbox = tempDir.appendingPathComponent("inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let url = inbox.appendingPathComponent(name)
        try Data("not-a-real-font".utf8).write(to: url)
        return url
    }

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

    func testDeclarationsGroupFacesByFamily() throws {
        let store = FontStore(directory: tempDir)
        // 同じファミリー名の 2 ファイル（regular/bold 相当）は 1 宣言にまとまる。
        let first = try XCTUnwrap(store.importFont(from: try makeFile(named: "Alpha.ttf")))
        try FileManager.default.copyItem(
            at: store.fileURL(for: first),
            to: tempDir.appendingPathComponent("inbox/Alpha.otf")
        )
        store.importFont(from: tempDir.appendingPathComponent("inbox/Alpha.otf"))
        store.importFont(from: try makeFile(named: "Beta.ttf"))

        XCTAssertEqual(store.fonts.count, 3)
        XCTAssertEqual(store.fontFamilyDeclarations.count, 2, "同一ファミリーは 1 宣言に統合")
    }
}
