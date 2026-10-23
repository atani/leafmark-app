import Foundation
import FirebaseAnalytics
import FirebaseCore

/// Where the paywall was opened from (ADR-0009). Each case maps one
/// `PaywallContext`, so every paywall route reports a fixed value.
enum PaywallSource: String, CaseIterable {
    /// The single free Markdown export is spent and the reader tried again.
    case exportLimit = "export_limit"
    /// The "Leafmark Pro" item of the library menu.
    case settings
    /// "Export All Highlights", which is Pro only.
    case bulkExport = "bulk_export"
    /// The third free highlight in a book is used and the reader made another.
    case highlightLimit = "highlight_limit"
    /// The "Upgrade" button of the free-plan footer, before the limit is hit.
    case highlightsUpgrade = "highlights_upgrade"
    /// Reading statistics, which are Pro only.
    case statistics
}

extension PaywallContext {
    var funnelSource: PaywallSource {
        switch self {
        case .general: return .settings
        case .highlightLimit: return .highlightLimit
        case .highlights: return .highlightsUpgrade
        case .export: return .exportLimit
        case .exportAll: return .bulkExport
        case .statistics: return .statistics
        }
    }
}

/// The only custom events Leafmark sends (ADR-0009).
///
/// Names and parameter values are fixed here. There is no case that carries a
/// free string, so a book title, author, file name, passage or note can never
/// reach Analytics through this type.
enum FunnelEvent: Equatable {
    case paywallShown(PaywallSource)
    case freeExportUsed
    case purchaseTapped
    /// A verified StoreKit purchase. Restores are not purchases.
    case purchaseCompleted

    var name: String {
        switch self {
        case .paywallShown: return "paywall_shown"
        case .freeExportUsed: return "free_export_used"
        case .purchaseTapped: return "purchase_tapped"
        case .purchaseCompleted: return "purchase_completed"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .paywallShown(let source): return ["source": source.rawValue]
        case .freeExportUsed, .purchaseTapped, .purchaseCompleted: return [:]
        }
    }
}

/// Reads the bundled `GoogleService-Info.plist`. The file is not committed to
/// the public repository, so builds without it carry no configuration.
struct FunnelAnalyticsConfiguration: Equatable {
    let optionsPath: String?

    static var bundled: Self {
        .init(optionsPath: Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"))
    }

    /// True when the file exists and names a Firebase app and API key.
    var isUsable: Bool {
        guard let optionsPath,
              let values = NSDictionary(contentsOfFile: optionsPath) as? [String: Any] else { return false }
        return ["GOOGLE_APP_ID", "API_KEY"].allSatisfy { key in
            guard let value = values[key] as? String else { return false }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("$(")
        }
    }
}

extension RevenueCatExecutionContext {
    /// Analytics is sent only from the shipping app in a Release build:
    /// never from Debug, tests, SwiftUI Previews or screenshot/demo launches.
    var allowsAnalytics: Bool {
        bundleIdentifier == Self.appBundleIdentifier && isReleaseBuild
            && !isTesting && !isPreview && !isDemo
    }
}

@MainActor
protocol FunnelAnalyticsTransport {
    func configure(optionsPath: String) -> Bool
    func log(name: String, parameters: [String: String])
}

@MainActor
private struct LiveFunnelAnalyticsTransport: FunnelAnalyticsTransport {
    func configure(optionsPath: String) -> Bool {
        // Re-check the real process, not the injected context, so tests never start Firebase.
        // FirebaseApp.configure raises when called twice.
        guard RevenueCatExecutionContext.current.allowsAnalytics, FirebaseApp.app() == nil,
              let options = FirebaseOptions(contentsOfFile: optionsPath) else { return false }
        FirebaseApp.configure(options: options)
        return true
    }

    func log(name: String, parameters: [String: String]) {
        Analytics.logEvent(name, parameters: parameters.isEmpty ? nil : parameters)
    }
}

/// Sends the purchase-funnel events of ADR-0009 to Firebase Analytics.
///
/// Nothing is configured or sent unless the build is Release, the process is
/// the shipping app, and a usable `GoogleService-Info.plist` is bundled.
@MainActor
final class FunnelAnalytics {
    static let shared = FunnelAnalytics()

    private let configuration: FunnelAnalyticsConfiguration
    private let context: RevenueCatExecutionContext
    private let transport: any FunnelAnalyticsTransport
    private(set) var isConfigured = false

    init(configuration: FunnelAnalyticsConfiguration? = nil,
         context: RevenueCatExecutionContext = .current,
         transport: (any FunnelAnalyticsTransport)? = nil) {
        self.configuration = configuration ?? .bundled
        self.context = context
        self.transport = transport ?? LiveFunnelAnalyticsTransport()
    }

    /// Configures Firebase once at launch when every condition holds.
    @discardableResult
    func start() -> Bool {
        guard !isConfigured else { return true }
        guard context.allowsAnalytics, configuration.isUsable,
              let path = configuration.optionsPath,
              transport.configure(optionsPath: path) else { return false }
        isConfigured = true
        return true
    }

    func record(_ event: FunnelEvent) {
        guard isConfigured else { return }
        transport.log(name: event.name, parameters: event.parameters)
    }
}
