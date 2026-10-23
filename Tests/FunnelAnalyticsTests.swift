import XCTest
@testable import Leafmark

@MainActor
final class FunnelAnalyticsTests: XCTestCase {
    private var files: [URL] = []
    private var suites: [String] = []

    override func tearDown() {
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        suites.forEach { UserDefaults().removePersistentDomain(forName: $0) }
        files = []
        suites = []
        super.tearDown()
    }

    // MARK: - Events

    func testEachEventIsSentOnceWithItsFixedNameAndParameters() async {
        let transport = TransportSpy()
        let analytics = await readyAnalytics(transport: transport)

        analytics.record(.paywallShown(.exportLimit))
        analytics.record(.freeExportUsed)
        analytics.record(.purchaseTapped(.libraryMenu))
        analytics.record(.purchaseCompleted(.bulkExport))
        analytics.record(.purchaseCompleted(nil))

        XCTAssertEqual(transport.logged, [
            .init(name: "paywall_shown", parameters: ["source": "export_limit"]),
            .init(name: "free_export_used", parameters: [:]),
            .init(name: "purchase_tapped", parameters: ["source": "library_menu"]),
            .init(name: "purchase_completed", parameters: ["source": "bulk_export"]),
            .init(name: "purchase_completed", parameters: [:]),
        ])
    }

    func testEveryPaywallRouteReportsAFixedSource() {
        let expected: [PaywallContext: String] = [
            .general: "library_menu", .export: "export_limit", .exportAll: "bulk_export",
            .highlightLimit: "highlight_limit", .highlights: "highlights_upgrade", .statistics: "statistics",
        ]
        for (context, source) in expected {
            XCTAssertEqual(FunnelEvent.paywallShown(context.funnelSource).parameters, ["source": source], "\(context)")
        }
        XCTAssertEqual(Set(expected.values), Set(PaywallSource.allCases.map(\.rawValue)))
    }

    func testPaywallSendsShownAndTappedWithItsSource() async {
        let transport = TransportSpy()
        let analytics = await readyAnalytics(transport: transport)
        let store = StoreManager(analytics: analytics, defaults: isolatedDefaults())

        PaywallView(store: store, context: .general, analytics: analytics).recordShown()
        // The footer opens the highlight-limit context but reports its own entry.
        let footer = PaywallView(store: store, context: .highlightLimit, source: .highlightsUpgrade,
                                 analytics: analytics)
        footer.recordShown()
        // No product loads in unit tests, so purchase() returns without buying.
        let unlocked = await footer.purchaseTapped()

        XCTAssertFalse(unlocked)
        XCTAssertEqual(transport.logged, [
            .init(name: "paywall_shown", parameters: ["source": "library_menu"]),
            .init(name: "paywall_shown", parameters: ["source": "highlights_upgrade"]),
            .init(name: "purchase_tapped", parameters: ["source": "highlights_upgrade"]),
        ])
    }

    func testFreeExportEventIsSentOnlyWhenTheAllowanceIsSpent() async {
        let key = "store.freeExportUsed"
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        let transport = TransportSpy()
        let store = StoreManager(analytics: await readyAnalytics(transport: transport))

        XCTAssertFalse(store.completeExport(success: false))
        XCTAssertTrue(transport.logged.isEmpty, "共有の取り消しは書き出しではない")
        XCTAssertTrue(store.completeExport(success: true))
        store.markFreeExportUsed()
        XCTAssertEqual(transport.logged, [.init(name: "free_export_used", parameters: [:])])
    }

    // MARK: - purchase_completed

    func testNewPurchaseIsCountedOnceWithItsSource() async {
        let transport = TransportSpy()
        let store = StoreManager(analytics: await readyAnalytics(transport: transport), defaults: isolatedDefaults())
        let requestedAt = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertTrue(store.recordCompletedPurchase(purchase(at: requestedAt.addingTimeInterval(5)),
                                                    wasPro: false, source: .exportLimit, requestedAt: requestedAt))
        XCTAssertEqual(transport.logged, [.init(name: "purchase_completed", parameters: ["source": "export_limit"])])
    }

    func testRepurchaseRestoreFamilySharingAndRevokedAreNotCounted() async {
        let transport = TransportSpy()
        let store = StoreManager(analytics: await readyAnalytics(transport: transport), defaults: isolatedDefaults())
        let requestedAt = Date(timeIntervalSince1970: 1_000_000)
        let recent = requestedAt.addingTimeInterval(5)

        // Already Pro before buying.
        XCTAssertFalse(store.recordCompletedPurchase(purchase(at: recent), wasPro: true,
                                                     source: .libraryMenu, requestedAt: requestedAt))
        // The App Store returned the original transaction of an earlier purchase.
        XCTAssertFalse(store.recordCompletedPurchase(purchase(at: requestedAt.addingTimeInterval(-86_400)),
                                                     wasPro: false, source: .libraryMenu, requestedAt: requestedAt))
        XCTAssertFalse(store.recordCompletedPurchase(purchase(at: recent, familyShared: true), wasPro: false,
                                                     source: .libraryMenu, requestedAt: requestedAt))
        XCTAssertFalse(store.recordCompletedPurchase(purchase(at: recent, revoked: true), wasPro: false,
                                                     source: .libraryMenu, requestedAt: requestedAt))
        XCTAssertFalse(store.recordCompletedPurchase(.init(productID: "other", purchaseDate: recent), wasPro: false,
                                                     source: .libraryMenu, requestedAt: requestedAt))
        XCTAssertTrue(transport.logged.isEmpty)
    }

    func testAskToBuyApprovalIsCountedOnceWithTheOriginalSource() async {
        let transport = TransportSpy()
        let store = StoreManager(analytics: await readyAnalytics(transport: transport), defaults: isolatedDefaults())
        let requestedAt = Date(timeIntervalSince1970: 1_000_000)
        let approved = purchase(at: requestedAt.addingTimeInterval(3_600))

        // A Transaction.updates delivery with no pending request on this device is not counted.
        XCTAssertFalse(store.completePendingPurchase(approved, now: approved.purchaseDate))
        store.rememberPendingPurchase(source: .statistics, requestedAt: requestedAt)
        XCTAssertTrue(store.completePendingPurchase(approved, now: approved.purchaseDate))
        XCTAssertFalse(store.completePendingPurchase(approved, now: approved.purchaseDate),
                       "承認は 1 回だけ数える")
        XCTAssertEqual(transport.logged, [.init(name: "purchase_completed", parameters: ["source": "statistics"])])
    }

    /// Regression: at launch, entitlements can refresh (isPro = true) before
    /// the approval arrives through Transaction.updates. It still counts once.
    func testAskToBuyApprovalIsCountedOnceEvenWhenAlreadyPro() async {
        let transport = TransportSpy()
        let store = StoreManager(analytics: await readyAnalytics(transport: transport), defaults: isolatedDefaults())
        let requestedAt = Date(timeIntervalSince1970: 1_000_000)
        let approved = purchase(at: requestedAt.addingTimeInterval(3_600))
        store.rememberPendingPurchase(source: .bulkExport, requestedAt: requestedAt)
        store.setProForTesting(true)

        XCTAssertTrue(store.isPro)
        XCTAssertTrue(store.completePendingPurchase(approved, now: approved.purchaseDate))
        XCTAssertFalse(store.completePendingPurchase(approved, now: approved.purchaseDate))
        XCTAssertEqual(transport.logged, [.init(name: "purchase_completed", parameters: ["source": "bulk_export"])])
    }

    func testOlderTransactionDoesNotConsumeThePendingRequest() async {
        let transport = TransportSpy()
        let store = StoreManager(analytics: await readyAnalytics(transport: transport), defaults: isolatedDefaults())
        let requestedAt = Date(timeIntervalSince1970: 1_000_000)
        store.rememberPendingPurchase(source: .exportLimit, requestedAt: requestedAt)

        // An update about an earlier transaction (dated before the request) arrives first.
        let older = purchase(at: requestedAt.addingTimeInterval(-86_400))
        XCTAssertFalse(store.completePendingPurchase(older, now: requestedAt.addingTimeInterval(60)))
        let approved = purchase(at: requestedAt.addingTimeInterval(3_600))
        XCTAssertTrue(store.completePendingPurchase(approved, now: approved.purchaseDate))
        XCTAssertEqual(transport.logged, [.init(name: "purchase_completed", parameters: ["source": "export_limit"])])
    }

    func testExpiredPendingRequestIsNotCounted() async {
        let transport = TransportSpy()
        let store = StoreManager(analytics: await readyAnalytics(transport: transport), defaults: isolatedDefaults())
        let requestedAt = Date(timeIntervalSince1970: 1_000_000)
        let late = requestedAt.addingTimeInterval(StoreManager.pendingPurchaseLifetime + 1)
        store.rememberPendingPurchase(source: .statistics, requestedAt: requestedAt)

        XCTAssertFalse(store.completePendingPurchase(purchase(at: late), now: late))
        XCTAssertTrue(transport.logged.isEmpty)
    }

    // MARK: - Configuration and environment gates

    func testMissingOrEmptyFirebaseConfigurationNeverConfigures() throws {
        let configurations: [FunnelAnalyticsConfiguration] = [
            .init(optionsPath: nil),
            .init(optionsPath: "/nonexistent/GoogleService-Info.plist"),
            .init(optionsPath: try plist(["GOOGLE_APP_ID": "", "API_KEY": ""])),
            .init(optionsPath: try plist(["GOOGLE_APP_ID": "1:1:ios:abc"])),
            .init(optionsPath: try plist(["GOOGLE_APP_ID": "$(GOOGLE_APP_ID)", "API_KEY": "key"])),
        ]
        for configuration in configurations {
            let transport = TransportSpy()
            let analytics = FunnelAnalytics(configuration: configuration, context: context(release: true),
                                            transport: transport, isProductionStore: { true })
            XCTAssertNil(analytics.start(), "\(configuration)")
            analytics.record(.freeExportUsed)
            XCTAssertEqual(transport.configurations, 0, "\(configuration)")
            XCTAssertTrue(transport.logged.isEmpty, "\(configuration)")
        }
    }

    func testDebugTestsPreviewsDemoAndOtherBundlesNeverConfigure() throws {
        let usable = FunnelAnalyticsConfiguration(optionsPath: try usablePlist())
        let contexts = [
            context(release: false),
            context(release: true, testing: true),
            context(release: true, preview: true),
            context(release: true, demo: true),
            context(bundle: "com.example.other", release: true),
        ]
        for context in contexts {
            let transport = TransportSpy()
            let analytics = FunnelAnalytics(configuration: usable, context: context, transport: transport,
                                            isProductionStore: { true })
            XCTAssertNil(analytics.start(), "\(context)")
            analytics.record(.purchaseCompleted(nil))
            XCTAssertEqual(transport.configurations, 0, "\(context)")
            XCTAssertTrue(transport.logged.isEmpty, "\(context)")
        }
    }

    func testSandboxOrUnknownStoreEnvironmentNeverConfiguresAndDropsQueuedEvents() async throws {
        // TestFlight and App Review run in Sandbox; a failed lookup also reports false.
        let transport = TransportSpy()
        let analytics = FunnelAnalytics(configuration: .init(optionsPath: try usablePlist()),
                                        context: context(release: true), transport: transport,
                                        isProductionStore: { false })
        let task = analytics.start()
        analytics.record(.paywallShown(.libraryMenu))
        await task?.value
        analytics.record(.purchaseTapped(.libraryMenu))

        XCTAssertFalse(analytics.isConfigured)
        XCTAssertEqual(transport.configurations, 0)
        XCTAssertTrue(transport.logged.isEmpty)
    }

    func testProductionConfiguresOnceAndFlushesEventsQueuedDuringTheCheck() async throws {
        let transport = TransportSpy()
        let analytics = FunnelAnalytics(configuration: .init(optionsPath: try usablePlist()),
                                        context: context(release: true), transport: transport,
                                        isProductionStore: { true })
        let task = analytics.start()
        XCTAssertNotNil(task)
        analytics.record(.paywallShown(.statistics))
        await task?.value
        XCTAssertNil(analytics.start(), "2 回目は何もしない")

        XCTAssertTrue(analytics.isConfigured)
        XCTAssertEqual(transport.configurations, 1)
        XCTAssertEqual(transport.logged, [.init(name: "paywall_shown", parameters: ["source": "statistics"])])
    }

    func testLiveAnalyticsStaysUnconfiguredInTests() {
        XCTAssertNil(FunnelAnalytics.shared.start())
        XCTAssertFalse(FunnelAnalytics.shared.isConfigured)
    }

    // MARK: - Helpers

    private func readyAnalytics(transport: TransportSpy) async -> FunnelAnalytics {
        let analytics = FunnelAnalytics(configuration: .init(optionsPath: try? usablePlist()),
                                        context: context(release: true), transport: transport,
                                        isProductionStore: { true })
        await analytics.start()?.value
        XCTAssertTrue(analytics.isConfigured)
        return analytics
    }

    private func purchase(at date: Date, familyShared: Bool = false, revoked: Bool = false) -> CompletedProPurchase {
        .init(productID: StoreManager.proProductID, purchaseDate: date, isFamilyShared: familyShared, isRevoked: revoked)
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "FunnelAnalyticsTests.\(UUID().uuidString)"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    private func usablePlist() throws -> String {
        // A format fixture handed only to TransportSpy, never to Firebase.
        try plist(["GOOGLE_APP_ID": "1:1:ios:fixture", "API_KEY": "fixture-key"])
    }

    private func plist(_ values: [String: String]) throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FunnelAnalyticsTests-\(UUID().uuidString).plist")
        try (values as NSDictionary).write(to: url)
        files.append(url)
        return url.path
    }

    private func context(bundle: String = "com.atani.inkwell", release: Bool, testing: Bool = false,
                         preview: Bool = false, demo: Bool = false) -> AppExecutionContext {
        .init(bundleIdentifier: bundle, isReleaseBuild: release, isTesting: testing, isPreview: preview, isDemo: demo)
    }

    private struct Logged: Equatable {
        let name: String
        let parameters: [String: String]
    }

    private final class TransportSpy: FunnelAnalyticsTransport {
        private(set) var configurations = 0
        private(set) var logged: [Logged] = []

        func configure(optionsPath: String) -> Bool {
            configurations += 1
            return true
        }

        func log(name: String, parameters: [String: String]) {
            logged.append(.init(name: name, parameters: parameters))
        }
    }
}
