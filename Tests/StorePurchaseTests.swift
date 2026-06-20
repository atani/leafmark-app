import XCTest
import StoreKitTest
@testable import Inkwell

/// Exercises the real purchase flow against the bundled StoreKit
/// configuration (Inkwell.storekit) — no App Store Connect required.
///
/// Note: under headless `xcodebuild test` on some simulator runtimes the
/// StoreKit test daemon does not serve the configuration's products to a
/// hosted unit-test bundle, so `Product.products` comes back empty. These
/// tests skip in that case and run their real assertions wherever the
/// configuration loads (e.g. when run from Xcode). The purchase flow itself
/// is also wired to the scheme's Run action StoreKit configuration.
@MainActor
final class StorePurchaseTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "Inkwell")
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
