import Foundation
import FirebaseAnalytics
import FirebaseCore
import StoreKit

/// Where the paywall was opened from. The values are listed in ADR-0009.
enum PaywallSource: String, CaseIterable {
    /// The single free Markdown export is spent and the reader tried again.
    case exportLimit = "export_limit"
    /// The "Leafmark Pro" item of the library menu.
    case libraryMenu = "library_menu"
    /// "Export All Highlights", which is Pro only.
    case bulkExport = "bulk_export"
    /// The reader hit the free highlight limit while reading.
    case highlightLimit = "highlight_limit"
    /// The "Upgrade" button of the free-plan footer in the highlight list.
    case highlightsUpgrade = "highlights_upgrade"
    /// Reading statistics, which are Pro only.
    case statistics
}

extension PaywallContext {
    /// The default source for a context. The free-plan footer overrides it
    /// with `.highlightsUpgrade`, because it can open either highlight context.
    var funnelSource: PaywallSource {
        switch self {
        case .general: return .libraryMenu
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
/// Names and parameter values are fixed here. No case carries a free string,
/// so a book title, author, file name, passage or note can never reach
/// Analytics through this type.
enum FunnelEvent: Equatable {
    case paywallShown(PaywallSource)
    case freeExportUsed
    case purchaseTapped(PaywallSource)
    /// A new verified StoreKit purchase. Restores and re-purchases of an
    /// already-owned Pro are not counted. The source is nil when the purchase
    /// did not start from a paywall on this device.
    case purchaseCompleted(PaywallSource?)

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
        case .paywallShown(let source), .purchaseTapped(let source):
            return ["source": source.rawValue]
        case .purchaseCompleted(let source):
            return source.map { ["source": $0.rawValue] } ?? [:]
        case .freeExportUsed:
            return [:]
        }
    }
}

/// Reads the bundled `GoogleService-Info.plist`. Why the file is not
/// committed: ADR-0009.
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
        guard AppExecutionContext.current.allowsAnalytics, FirebaseApp.app() == nil,
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
/// the shipping app, a usable `GoogleService-Info.plist` is bundled, and the
/// App Store reports the production environment. TestFlight and App Review
/// run in the Sandbox environment, so their purchases never mix into the
/// conversion rate. When the environment cannot be read, nothing is sent.
@MainActor
final class FunnelAnalytics {
    static let shared = FunnelAnalytics()

    /// Events recorded while the store environment is still being checked.
    /// The paywall can open before `AppTransaction` answers on first launch.
    static let pendingLimit = 20

    private enum State { case idle, checking, configured, disabled }

    private let configuration: FunnelAnalyticsConfiguration
    private let context: AppExecutionContext
    private let transport: any FunnelAnalyticsTransport
    private let isProductionStore: () async -> Bool
    private var state = State.idle
    private var pending: [FunnelEvent] = []

    var isConfigured: Bool { state == .configured }

    init(configuration: FunnelAnalyticsConfiguration? = nil,
         context: AppExecutionContext = .current,
         transport: (any FunnelAnalyticsTransport)? = nil,
         isProductionStore: (() async -> Bool)? = nil) {
        self.configuration = configuration ?? .bundled
        self.context = context
        self.transport = transport ?? LiveFunnelAnalyticsTransport()
        self.isProductionStore = isProductionStore ?? { await Self.liveIsProductionStore() }
    }

    /// Starts the one-time check at launch. Returns nil when the build or the
    /// configuration already rules analytics out; tests await the task.
    @discardableResult
    func start() -> Task<Void, Never>? {
        guard state == .idle else { return nil }
        guard context.allowsAnalytics, configuration.isUsable,
              let path = configuration.optionsPath else {
            state = .disabled
            return nil
        }
        state = .checking
        return Task {
            let production = await isProductionStore()
            if production && transport.configure(optionsPath: path) {
                state = .configured
                pending.forEach(log)
            } else {
                state = .disabled
            }
            pending.removeAll()
        }
    }

    func record(_ event: FunnelEvent) {
        switch state {
        case .configured:
            log(event)
        case .checking:
            if pending.count < Self.pendingLimit { pending.append(event) }
        case .idle, .disabled:
            break
        }
    }

    private func log(_ event: FunnelEvent) {
        transport.log(name: event.name, parameters: event.parameters)
    }

    /// Production only when the App Store signs an app transaction for the
    /// production environment. Sandbox (TestFlight, App Review), Xcode and
    /// any failure count as not production.
    private static func liveIsProductionStore() async -> Bool {
        guard let result = try? await AppTransaction.shared,
              case .verified(let transaction) = result else { return false }
        return transaction.environment == .production
    }
}
