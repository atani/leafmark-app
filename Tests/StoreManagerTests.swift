import XCTest
@testable import Leafmark

@MainActor
final class StoreManagerTests: XCTestCase {
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
}
