import XCTest
import RevenueCat
import StoreKit
@testable import Leafmark

@MainActor
final class RevenueCatMigrationTests: XCTestCase {
    // 設定検証専用の文字列。SDKの初期化・接続には使わない。
    private let configuration = RevenueCatMigrationConfiguration(
        mode: "sandbox", publicSDKKey: "appl_configurationOnly123", dataSharingApproved: true
    )

    func testLiveObserverDoesNotInitializeSDKInTestsOrWithoutConfiguration() {
        XCTAssertFalse(Purchases.isConfigured)
        RevenueCatObserver.shared.start()
        RevenueCatObserver.shared.restoreCompleted()
        XCTAssertFalse(Purchases.isConfigured)
    }

    func testAllObserverEntryPointsStayUnconfiguredWithSandboxConsentAndKey() {
        let observer = RevenueCatObserver(configuration: configuration)
        XCTAssertFalse(Purchases.isConfigured)
        observer.start()
        observer.recordPurchase(.pending)
        observer.recordPurchase(.userCancelled)
        observer.restoreCompleted()
        XCTAssertFalse(Purchases.isConfigured)
    }

    func testDefaultAndUnapprovedConfigurationsCannotSend() {
        let disabled = RevenueCatMigrationConfiguration(mode: "disabled", publicSDKKey: "", dataSharingApproved: false)
        XCTAssertFalse(disabled.hasSandboxConfiguration(isDebugBuild: true, isTesting: false, isSandbox: true))
        let unapproved = RevenueCatMigrationConfiguration(mode: "sandbox", publicSDKKey: configuration.publicSDKKey, dataSharingApproved: false)
        XCTAssertFalse(unapproved.hasSandboxConfiguration(isDebugBuild: true, isTesting: false, isSandbox: true))
    }

    func testReleaseProductionAndTestsCannotSendEvenWithConfiguration() {
        XCTAssertFalse(configuration.hasSandboxConfiguration(isDebugBuild: false, isTesting: false, isSandbox: true))
        XCTAssertFalse(configuration.hasSandboxConfiguration(isDebugBuild: true, isTesting: false, isSandbox: false))
        XCTAssertFalse(configuration.hasSandboxConfiguration(isDebugBuild: true, isTesting: true, isSandbox: true))
        XCTAssertTrue(configuration.hasSandboxConfiguration(isDebugBuild: true, isTesting: false, isSandbox: true))
    }

    func testPrivateKeysPlaceholdersAndUnresolvedBuildSettingsAreRejected() {
        for key in ["", "sk_secret", "test_store", "$(REVENUECAT_PUBLIC_SDK_KEY)", "appl_yourKey123456", "appl_example123456", "appl_a b12345678", "appl_<replace_me>"] {
            let value = RevenueCatMigrationConfiguration(mode: "sandbox", publicSDKKey: key, dataSharingApproved: true)
            XCTAssertFalse(value.hasSandboxConfiguration(isDebugBuild: true, isTesting: false, isSandbox: true), key)
        }
    }

    func testLifetimeAndActiveSubscriptionAreEligible() {
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(purchase(expiration: nil).isEligible(productIDs: ["pro"], now: now))
        XCTAssertTrue(purchase(expiration: Date(timeIntervalSince1970: 101)).isEligible(productIDs: ["pro"], now: now))
    }

    func testExpiredRefundedUnverifiedAndUnknownProductsAreExcluded() {
        let now = Date(timeIntervalSince1970: 100)
        for value in [purchase(expiration: now), purchase(expiration: Date(timeIntervalSince1970: 99)), purchase(revoked: true), purchase(verified: false), purchase(productID: "other")] {
            XCTAssertFalse(value.isEligible(productIDs: ["pro"], now: now))
        }
    }

    func testDisabledAndFreeCustomersNeverSync() async {
        let state = State()
        let coordinator = makeCoordinator(state)
        let disabled = await coordinator.syncExistingPurchases(enabled: false, customerID: "a", eligibleProductIDs: ["pro"]) { XCTFail("disabled"); return [] }
        let free = await coordinator.syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: []) { XCTFail("free"); return [] }
        XCTAssertEqual(disabled, .skipped)
        XCTAssertEqual(free, .skipped)
        XCTAssertTrue(state.synced.isEmpty)
    }

    func testSuccessfulSyncIsOncePerCustomerAcrossLaunches() async {
        let state = State()
        let first = await makeCoordinator(state).syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"]) { ["pro"] }
        let second = await makeCoordinator(state).syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"]) { XCTFail("repeat launch"); return [] }
        XCTAssertEqual(first, .synced)
        XCTAssertEqual(second, .skipped)
        XCTAssertEqual(state.synced, ["a": ["pro"]])
    }

    func testNewRevenueCatIdentityGetsItsOwnMigration() async {
        let state = State(); state.synced = ["old-customer": ["pro"]]
        let result = await makeCoordinator(state).syncExistingPurchases(enabled: true, customerID: "new-customer", eligibleProductIDs: ["pro"]) { ["pro"] }
        XCTAssertEqual(result, .synced)
        XCTAssertEqual(state.synced, ["old-customer": ["pro"], "new-customer": ["pro"]])
    }

    func testOfflineFailureDoesNotPersistSuccessAndRetriesOnNextLaunch() async {
        let state = State()
        let coordinator = makeCoordinator(state)
        let failed = await coordinator.syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"]) { throw URLError(.notConnectedToInternet) }
        let sameSession = await coordinator.syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"]) { XCTFail("busy retry"); return [] }
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(sameSession, .skipped)
        XCTAssertTrue(state.synced.isEmpty)
        let nextLaunch = await makeCoordinator(state).syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"]) { ["pro"] }
        XCTAssertEqual(nextLaunch, .synced)
    }

    func testMisconfiguredCatalogDoesNotMarkMigrationComplete() async {
        let state = State()
        let result = await makeCoordinator(state).syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro", "legacy"]) { ["pro"] }
        XCTAssertEqual(result, .failed)
        XCTAssertTrue(state.synced.isEmpty)
    }

    func testExplicitRestoreCanRetryAfterFailure() async {
        let state = State()
        let coordinator = makeCoordinator(state)
        _ = await coordinator.syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"]) { throw URLError(.timedOut) }
        let restored = await coordinator.syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"], userInitiated: true) { ["pro"] }
        XCTAssertEqual(restored, .synced)
    }

    func testConcurrentMigrationIsDeduplicated() async {
        let state = State()
        let coordinator = makeCoordinator(state)
        var continuation: CheckedContinuation<Set<String>, Never>?
        let first = Task { await coordinator.syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"]) {
            await withCheckedContinuation { continuation = $0 }
        } }
        while continuation == nil { await Task.yield() }
        let second = await coordinator.syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["pro"], userInitiated: true) { XCTFail("concurrent sync"); return [] }
        continuation?.resume(returning: ["pro"])
        let firstOutcome = await first.value
        XCTAssertEqual(second, .skipped)
        XCTAssertEqual(firstOutcome, .synced)
    }

    func testSandboxKeyAndConsentCannotEnableUnisolatedSDK() {
        XCTAssertTrue(configuration.hasSandboxConfiguration(isDebugBuild: true, isTesting: false, isSandbox: true))
        XCTAssertFalse(configuration.permitsSandboxObserver(isDebugBuild: true, isTesting: false, isSandbox: true))
        XCTAssertFalse(configuration.permitsSandboxObserver(isDebugBuild: false, isTesting: false, isSandbox: true))
        XCTAssertFalse(configuration.permitsSandboxObserver(isDebugBuild: true, isTesting: false, isSandbox: false))
    }

    func testStaleSyncCannotOverwriteNewPurchaseInvalidation() async {
        let state = State()
        let coordinator = makeCoordinator(state)
        var continuation: CheckedContinuation<Set<String>, Never>?
        let oldSync = Task { await coordinator.syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["monthly"]) {
            await withCheckedContinuation { continuation = $0 }
        } }
        while continuation == nil { await Task.yield() }
        // A new lifetime purchase invalidates migration before its record request.
        // That request fails: no new success is written, but the old sync arrives.
        coordinator.invalidate(customerID: "a")
        continuation?.resume(returning: ["monthly"])
        let oldOutcome = await oldSync.value
        XCTAssertEqual(oldOutcome, .skipped)
        XCTAssertTrue(state.synced.isEmpty)
        var calls = 0
        let nextLaunch = await makeCoordinator(state).syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["monthly", "lifetime"]) {
            calls += 1
            return ["monthly", "lifetime"]
        }
        XCTAssertEqual(nextLaunch, .synced)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(state.synced["a"], ["monthly", "lifetime"])
    }

    func testLargerProductSetTriggersSyncAfterEarlierSuccess() async {
        let state = State()
        _ = await makeCoordinator(state).syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["monthly"]) { ["monthly"] }
        var calls = 0
        let result = await makeCoordinator(state).syncExistingPurchases(enabled: true, customerID: "a", eligibleProductIDs: ["monthly", "lifetime"]) {
            calls += 1
            return ["monthly", "lifetime"]
        }
        XCTAssertEqual(result, .synced)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(state.synced["a"], ["monthly", "lifetime"])
    }

    func testObserverActivationRequiresEveryReadinessGate() {
        var complete = observerConfiguration()
        XCTAssertTrue(complete.permitsObserver(in: executionContext()))
        for gate in ["consent", "integration", "privacy", "mode", "key"] {
            var candidate = complete
            switch gate {
            case "consent": candidate = .init(mode: complete.mode, publicSDKKey: complete.publicSDKKey, dataSharingApproved: false, integrationReady: true, privacyReady: true)
            case "integration": candidate.integrationReady = false
            case "privacy": candidate.privacyReady = false
            case "mode": candidate = .init(mode: "sandbox", publicSDKKey: complete.publicSDKKey, dataSharingApproved: true, integrationReady: true, privacyReady: true)
            default: candidate = .init(mode: "observer", publicSDKKey: "", dataSharingApproved: true, integrationReady: true, privacyReady: true)
            }
            XCTAssertFalse(candidate.permitsObserver(in: executionContext()), gate)
        }
        XCTAssertFalse(complete.permitsObserver(in: executionContext(release: true)))
        complete.releaseEnabled = true
        XCTAssertTrue(complete.permitsObserver(in: executionContext(release: true)))
    }

    func testObserverRejectsTestsPreviewsDemoAndOtherBundle() {
        let complete = observerConfiguration()
        XCTAssertFalse(complete.permitsObserver(in: executionContext(testing: true)))
        XCTAssertFalse(complete.permitsObserver(in: executionContext(preview: true)))
        XCTAssertFalse(complete.permitsObserver(in: executionContext(demo: true)))
        XCTAssertFalse(complete.permitsObserver(in: executionContext(bundle: "com.atani.inkwell.widget")))
        XCTAssertFalse(complete.permitsObserver(in: executionContext(bundle: "com.example.other")))
    }

    func testAuthorizedProductionPurchaseCanBeMigrated() {
        XCTAssertTrue(purchase(sandbox: false).isEligible(productIDs: ["pro"], now: Date(timeIntervalSince1970: 100)))
    }

    func testIncompleteReadinessNeverCallsTransportFromAnyEntryPoint() async {
        for ready in [false, true] {
            var config = observerConfiguration()
            config.integrationReady = ready
            config.privacyReady = false
            let transport = TransportSpy()
            let observer = RevenueCatObserver(configuration: config, context: executionContext(), transport: transport, entitlementProductIDs: { ["pro"] })
            observer.start()
            observer.recordPurchase(.pending)
            observer.recordPurchase(.userCancelled)
            observer.restoreCompleted()
            await Task.yield()
            XCTAssertEqual(transport.configurations, 0)
            XCTAssertEqual(transport.syncs, 0)
            XCTAssertFalse(Purchases.isConfigured)
        }
    }

    func testReadyObserverConfiguresTransportOnlyOnceWithoutLiveSDK() async {
        let transport = TransportSpy()
        let observer = RevenueCatObserver(configuration: observerConfiguration(), context: executionContext(), transport: transport, entitlementProductIDs: { [] })
        observer.start()
        observer.start()
        observer.restoreCompleted()
        await Task.yield()
        XCTAssertEqual(transport.configurations, 1)
        XCTAssertEqual(transport.syncs, 0)
        XCTAssertFalse(Purchases.isConfigured)
    }

    func testRejectedTransportOwnerDoesNotSync() async {
        let transport = TransportSpy()
        transport.acceptsConfiguration = false
        let observer = RevenueCatObserver(configuration: observerConfiguration(), context: executionContext(), transport: transport, entitlementProductIDs: { ["pro"] })
        observer.start()
        observer.restoreCompleted()
        await Task.yield()
        XCTAssertGreaterThanOrEqual(transport.configurations, 1)
        XCTAssertEqual(transport.syncs, 0)
        XCTAssertFalse(Purchases.isConfigured)
    }

    func testActualDemoAndScreenshotLaunchMarkersCannotEnableObserver() {
        for argument in ["-demo", "-demo-pattern", "-demo-reference-image", "-store-screenshot-gallery",
                         "-tutorial-live-video-test-mode", "-show-monetization-demo", "-show-ad-demo",
                         "-screenshot-seed", "-screenshot-tab", "-ignore-purchases", "-force-pro",
                         "-leafmarkForcePro", "-ui-test-save-success", "UITEST_PRO", "UITEST_HISTORY", "UITEST_PAYWALL"] {
            let context = RevenueCatExecutionContext.make(bundleIdentifier: executionContext().bundleIdentifier,
                isReleaseBuild: false, arguments: ["app", argument], environment: [:], hasXCTestClass: false)
            XCTAssertTrue(context.isDemo, argument)
            XCTAssertFalse(observerConfiguration().permitsObserver(in: context), argument)
        }
        for key in ["SPH_UI_TEST_EMPTY_STORE", "SPH_UI_TEST_PREVIEW_PLANS", "UITEST_PRO", "PEYO_RECORD_DEMO"] {
            let context = RevenueCatExecutionContext.make(bundleIdentifier: executionContext().bundleIdentifier,
                isReleaseBuild: false, arguments: ["app"], environment: [key: "1"], hasXCTestClass: false)
            XCTAssertTrue(context.isDemo, key)
            XCTAssertFalse(observerConfiguration().permitsObserver(in: context), key)
        }
    }

    func testOrdinaryLaunchAndRuntimeTestPreviewDetection() {
        let bundle = executionContext().bundleIdentifier
        let ordinary = RevenueCatExecutionContext.make(bundleIdentifier: bundle, isReleaseBuild: false,
            arguments: ["app", "-AppleLanguages", "(ja)"], environment: [:], hasXCTestClass: false)
        XCTAssertTrue(observerConfiguration().permitsObserver(in: ordinary))
        for environment in [["XCTestConfigurationFilePath": "test.xctest"], ["XCODE_RUNNING_FOR_PREVIEWS": "1"]] {
            let context = RevenueCatExecutionContext.make(bundleIdentifier: bundle, isReleaseBuild: false,
                arguments: ["app"], environment: environment, hasXCTestClass: false)
            XCTAssertFalse(observerConfiguration().permitsObserver(in: context))
        }
        let testing = RevenueCatExecutionContext.make(bundleIdentifier: bundle, isReleaseBuild: false,
            arguments: ["app"], environment: [:], hasXCTestClass: true)
        XCTAssertFalse(observerConfiguration().permitsObserver(in: testing))
    }

    private func observerConfiguration() -> RevenueCatMigrationConfiguration {
        // A configuration-format fixture sent only to TransportSpy, never the live SDK.
        .init(mode: "observer", publicSDKKey: configuration.publicSDKKey, dataSharingApproved: true,
              integrationReady: true, privacyReady: true)
    }

    private func executionContext(bundle: String = "com.atani.inkwell", release: Bool = false,
                                  testing: Bool = false, preview: Bool = false, demo: Bool = false) -> RevenueCatExecutionContext {
        .init(bundleIdentifier: bundle, isReleaseBuild: release, isTesting: testing, isPreview: preview, isDemo: demo)
    }

    private final class TransportSpy: RevenueCatObserverTransport {
        var appUserID: String? { "unit-test-only" }
        var acceptsConfiguration = true
        var configurations = 0
        var syncs = 0
        func configure(publicSDKKey: String) -> Bool { configurations += 1; return acceptsConfiguration }
        func recordPurchase(_ result: StoreKit.Product.PurchaseResult) async throws { XCTFail("No real transaction in these tests") }
        func syncPurchases() async throws -> Set<String> { syncs += 1; return ["pro"] }
    }

    private func purchase(productID: String = "pro", verified: Bool = true, revoked: Bool = false, expiration: Date? = nil, sandbox: Bool = true) -> RevenueCatMigrationPurchase {
        .init(productID: productID, isVerified: verified, isRevoked: revoked, expirationDate: expiration, isSandbox: sandbox)
    }

    private final class State { var synced = [String: Set<String>]() }

    private func makeCoordinator(_ state: State) -> RevenueCatMigrationCoordinator {
        .init(syncedProductIDs: { state.synced[$0] ?? [] },
              markSynced: { state.synced[$0] = $1 },
              clearSynced: { state.synced.removeValue(forKey: $0) })
    }
}
