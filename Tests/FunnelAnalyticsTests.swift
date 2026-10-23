import XCTest
@testable import Leafmark

@MainActor
final class FunnelAnalyticsTests: XCTestCase {
    private var files: [URL] = []

    override func tearDown() {
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        files = []
        super.tearDown()
    }

    // MARK: - Events

    func testEachEventIsSentOnceWithItsFixedNameAndParameters() {
        let transport = TransportSpy()
        let analytics = readyAnalytics(transport: transport)

        analytics.record(.paywallShown(.exportLimit))
        analytics.record(.freeExportUsed)
        analytics.record(.purchaseTapped)
        analytics.record(.purchaseCompleted)

        XCTAssertEqual(transport.logged, [
            .init(name: "paywall_shown", parameters: ["source": "export_limit"]),
            .init(name: "free_export_used", parameters: [:]),
            .init(name: "purchase_tapped", parameters: [:]),
            .init(name: "purchase_completed", parameters: [:]),
        ])
    }

    func testEveryPaywallRouteReportsAFixedSource() {
        let expected: [PaywallContext: String] = [
            .general: "settings", .export: "export_limit", .exportAll: "bulk_export",
            .highlightLimit: "highlight_limit", .highlights: "highlights_upgrade", .statistics: "statistics",
        ]
        for (context, source) in expected {
            XCTAssertEqual(FunnelEvent.paywallShown(context.funnelSource).parameters, ["source": source], "\(context)")
        }
        XCTAssertEqual(Set(expected.values), Set(PaywallSource.allCases.map(\.rawValue)))
    }

    func testFreeExportEventIsSentOnlyWhenTheAllowanceIsSpent() {
        let key = "store.freeExportUsed"
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        let transport = TransportSpy()
        let store = StoreManager(analytics: readyAnalytics(transport: transport))

        XCTAssertFalse(store.completeExport(success: false))
        XCTAssertTrue(transport.logged.isEmpty, "共有の取り消しは書き出しではない")
        XCTAssertTrue(store.completeExport(success: true))
        store.markFreeExportUsed()
        XCTAssertEqual(transport.logged, [.init(name: "free_export_used", parameters: [:])])
    }

    // MARK: - Configuration gates

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
                                            transport: transport)
            XCTAssertFalse(analytics.start(), "\(configuration)")
            analytics.record(.purchaseTapped)
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
            let analytics = FunnelAnalytics(configuration: usable, context: context, transport: transport)
            XCTAssertFalse(analytics.start(), "\(context)")
            analytics.record(.purchaseCompleted)
            XCTAssertEqual(transport.configurations, 0, "\(context)")
            XCTAssertTrue(transport.logged.isEmpty, "\(context)")
        }
    }

    func testReleaseWithConfigurationConfiguresOnlyOnce() throws {
        let transport = TransportSpy()
        let analytics = FunnelAnalytics(configuration: .init(optionsPath: try usablePlist()),
                                        context: context(release: true), transport: transport)
        XCTAssertTrue(analytics.start())
        XCTAssertTrue(analytics.start())
        XCTAssertEqual(transport.configurations, 1)
    }

    func testLiveAnalyticsStaysUnconfiguredInTests() {
        XCTAssertFalse(FunnelAnalytics.shared.isConfigured)
        XCTAssertFalse(FunnelAnalytics.shared.start())
        XCTAssertFalse(FunnelAnalytics.shared.isConfigured)
    }

    // MARK: - Helpers

    private func readyAnalytics(transport: TransportSpy) -> FunnelAnalytics {
        let analytics = FunnelAnalytics(configuration: .init(optionsPath: try? usablePlist()),
                                        context: context(release: true), transport: transport)
        XCTAssertTrue(analytics.start())
        return analytics
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
                         preview: Bool = false, demo: Bool = false) -> RevenueCatExecutionContext {
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
