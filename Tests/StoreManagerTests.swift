import XCTest
@testable import Leafmark

@MainActor
final class StoreManagerTests: XCTestCase {
    func testCanceledExportPreservesAllowanceAndSuccessfulExportPersistsIt() {
        let key = "store.freeExportUsed"
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        let store = StoreManager()
        XCTAssertFalse(store.completeExport(success: false))
        XCTAssertFalse(store.hasUsedFreeExport)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
        XCTAssertTrue(store.completeExport(success: true))
        XCTAssertTrue(store.hasUsedFreeExport)
        XCTAssertTrue(StoreManager().hasUsedFreeExport)
    }

    func testPreparedExportPreservesTextAndFilenameAndCleansUp() throws {
        let export = HighlightExport(text: "# Book\n\n> Quote\n\nNote: 日本語", fileName: "Book - Author.txt")
        let file = try PreparedHighlightExport(export: export)
        defer { file.cleanup() }
        XCTAssertEqual(file.url.lastPathComponent, export.fileName)
        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), export.text)
        file.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.url.path))
    }

    func testFreeTierAllowsUpToTheLimit() {
        XCTAssertTrue(StoreManager.canAddHighlight(isPro: false, currentCount: 0))
        XCTAssertTrue(StoreManager.canAddHighlight(isPro: false, currentCount: 2))
    }

    func testFreeTierBlocksAtTheLimit() {
        XCTAssertFalse(
            StoreManager.canAddHighlight(isPro: false, currentCount: StoreManager.freeHighlightLimit),
            "無料枠は上限に達したら追加不可"
        )
        XCTAssertFalse(StoreManager.canAddHighlight(isPro: false, currentCount: 99))
    }

    func testProHasNoLimit() {
        XCTAssertTrue(StoreManager.canAddHighlight(isPro: true, currentCount: 0))
        XCTAssertTrue(StoreManager.canAddHighlight(isPro: true, currentCount: 9999))
    }

    func testDefaultStateIsNotPro() {
        let store = StoreManager()
        XCTAssertFalse(store.isPro, "購入前は Pro ではない")
    }

    func testFreeTierGetsOneExport() {
        XCTAssertTrue(
            StoreManager.canExport(isPro: false, hasUsedFreeExport: false),
            "無料でも1回目の書き出しは許可する"
        )
    }

    func testFreeTierBlocksSecondExport() {
        XCTAssertFalse(
            StoreManager.canExport(isPro: false, hasUsedFreeExport: true),
            "無料枠を使い切ったら2回目は Paywall へ送る"
        )
    }

    func testProExportsRegardlessOfFreeAllowance() {
        XCTAssertTrue(StoreManager.canExport(isPro: true, hasUsedFreeExport: false))
        XCTAssertTrue(
            StoreManager.canExport(isPro: true, hasUsedFreeExport: true),
            "Pro は無料枠の消費状況に関係なく書き出せる"
        )
    }

    func testMarkFreeExportUsedSpendsTheAllowanceOnce() {
        UserDefaults.standard.removeObject(forKey: "store.freeExportUsed")
        defer { UserDefaults.standard.removeObject(forKey: "store.freeExportUsed") }

        let store = StoreManager()
        XCTAssertFalse(store.hasUsedFreeExport)

        store.markFreeExportUsed()
        XCTAssertTrue(store.hasUsedFreeExport, "1回書き出したら無料枠は消費される")
        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: "store.freeExportUsed"),
            "再起動後も消費済みであることが残る"
        )
    }
}
