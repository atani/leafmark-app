import XCTest
import StoreKitTest
@testable import Leafmark

/// Exercises the real purchase flow against the bundled StoreKit
/// configuration (Leafmark.storekit) — no App Store Connect required.
///
/// These tests are opt-in. `Product.purchase()` asks StoreKit to present the
/// confirmation sheet, which needs a UI anchor; a hosted unit-test bundle has
/// no foreground scene to anchor to, so under plain `xcodebuild test` the
/// purchase never resolves and the run hangs until it fails with
/// "Could not find a UI anchor for com.atani.inkwell.pro purchase".
///
/// Skipping by default keeps `xcodebuild test` green without callers having
/// to remember `-skip-testing:`. Set the environment variable below (the
/// scheme's Test action, or `-testRunnerEnv`) to actually exercise purchases,
/// which works when the tests run with a real UI host such as from Xcode.
@MainActor
final class StorePurchaseTests: XCTestCase {
    /// Set to "1" to run the purchase tests. See the type comment for why.
    static let optInEnvironmentKey = "LEAFMARK_RUN_STOREKIT_PURCHASE_TESTS"

    private var session: SKTestSession!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment[Self.optInEnvironmentKey] == "1",
            "購入テストは UI アンカーを要求するため既定ではスキップする。"
                + "実行するには \(Self.optInEnvironmentKey)=1 を設定する。"
        )
        session = try SKTestSession(configurationFileNamed: "Leafmark")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    override func tearDown() {
        session?.clearTransactions()
        session = nil
        super.tearDown()
    }

    /// Loads the store and skips the test when the configuration's products
    /// are not served by this environment.
    private func loadedStore() async throws -> StoreManager {
        let store = StoreManager()
        await store.load()
        try XCTSkipIf(
            store.product == nil,
            "StoreKit configuration products not available in this test environment; "
                + "run from Xcode (or a runtime that serves SKTestSession products) to exercise purchases."
        )
        return store
    }

    func testProductLoadsFromConfiguration() async throws {
        let store = try await loadedStore()
        XCTAssertEqual(store.product?.id, StoreManager.proProductID)
        XCTAssertEqual(store.product?.displayPrice, "$9.99")
        XCTAssertFalse(store.isPro, "購入前は Pro ではない")
    }

    func testPurchaseUnlocksPro() async throws {
        let store = try await loadedStore()
        let unlocked = await store.purchase()
        XCTAssertTrue(unlocked, "購入が成功する")
        XCTAssertTrue(store.isPro, "購入後は Pro になる")
    }

    func testEntitlementRestoredOnFreshInstance() async throws {
        let buyer = try await loadedStore()
        _ = await buyer.purchase()
        XCTAssertTrue(buyer.isPro)

        // A fresh instance (app relaunch) sees the entitlement on load.
        let relaunched = StoreManager()
        await relaunched.load()
        XCTAssertTrue(relaunched.isPro, "再起動後もエンタイトルメントを復元する")
    }
}
