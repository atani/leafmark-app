import Foundation
import OSLog
import StoreKit
import RevenueCat

@MainActor
protocol RevenueCatObserverTransport {
    var appUserID: String? { get }
    func configure(publicSDKKey: String) -> Bool
    func recordPurchase(_ result: StoreKit.Product.PurchaseResult) async throws
    func syncPurchases() async throws -> Set<String>
}

/// Live SDK adapter. No custom user ID, contact attributes, or advertising identifiers.
@MainActor
private struct LiveRevenueCatObserverTransport: RevenueCatObserverTransport {
    let releaseEnabled: Bool
    var appUserID: String? { Purchases.isConfigured ? Purchases.shared.appUserID : nil }

    func configure(publicSDKKey: String) -> Bool {
        // Re-check the real process, not the injected context, so tests never start the SDK.
        // Refuse to use an SDK instance configured by another owner/key.
        guard RevenueCatExecutionContext.current.allowsObserver(releaseEnabled: releaseEnabled),
              !Purchases.isConfigured else { return false }
        // SDK error/debug messages can contain complete receipt/customer response bodies.
        Purchases.logHandler = { _, _ in }
        Purchases.configure(with: .init(withAPIKey: publicSDKKey)
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
            .with(automaticDeviceIdentifierCollectionEnabled: false))
        return true
    }

    func recordPurchase(_ result: StoreKit.Product.PurchaseResult) async throws {
        _ = try await Purchases.shared.recordPurchase(result)
    }

    func syncPurchases() async throws -> Set<String> {
        Set(try await Purchases.shared.syncPurchases().allPurchasedProductIdentifiers)
    }
}

/// Opt-in observation of all SDK-collected purchase history, including production.
/// StoreKit continues to own purchase completion, entitlements, restore and family access.
@MainActor
final class RevenueCatObserver {
    static let shared = RevenueCatObserver()
    private static let productIDs: Set<String> = ["com.atani.inkwell.pro"]
    private static let migrationPrefix = "revenuecat.observer.migration.v2.products."
    // Fixed templates only: operation name and error type, never IDs, receipts or SDK messages.
    private static let logger = Logger(subsystem: RevenueCatExecutionContext.appBundleIdentifier, category: "RevenueCat")

    private let configuration: RevenueCatMigrationConfiguration
    private let context: RevenueCatExecutionContext
    private let transport: any RevenueCatObserverTransport
    private let entitlementProductIDs: () async -> Set<String>
    private let coordinator: RevenueCatMigrationCoordinator
    private var configured = false

    init(configuration: RevenueCatMigrationConfiguration? = nil,
         context: RevenueCatExecutionContext = .current,
         transport: (any RevenueCatObserverTransport)? = nil,
         entitlementProductIDs: (() async -> Set<String>)? = nil,
         defaults: UserDefaults = .standard) {
        self.configuration = configuration ?? .init(infoDictionary: Bundle.main.infoDictionary)
        self.context = context
        self.transport = transport ?? LiveRevenueCatObserverTransport(releaseEnabled: self.configuration.releaseEnabled)
        self.entitlementProductIDs = entitlementProductIDs ?? { await Self.currentEntitlementProductIDs() }
        coordinator = Self.makeCoordinator(defaults: defaults)
    }

    static func makeCoordinator(defaults: UserDefaults) -> RevenueCatMigrationCoordinator {
        let prefix = migrationPrefix
        return RevenueCatMigrationCoordinator(
            syncedProductIDs: { Set(defaults.stringArray(forKey: prefix + $0) ?? []) },
            markSynced: { defaults.set($1.sorted(), forKey: prefix + $0) },
            clearSynced: { defaults.removeObject(forKey: prefix + $0) }
        )
    }

    static func syncedProductIDsKey(customerID: String) -> String { migrationPrefix + customerID }

    /// The returned task lets callers (tests) await the migration; production ignores it.
    @discardableResult
    func start() -> Task<Void, Never>? {
        guard configureIfAllowed() else { return nil }
        return Task { await migrateExistingPurchases(userInitiated: false) }
    }

    func recordPurchase(_ result: StoreKit.Product.PurchaseResult) {
        guard case .success(.verified(let transaction)) = result,
              Self.eligible(transaction), configureIfAllowed(),
              let customerID = transport.appUserID else { return }
        coordinator.invalidate(customerID: customerID)
        Task {
            do { try await transport.recordPurchase(result) }
            catch {
                // Preserve StoreKit success; migration retries on next launch/explicit restore.
                let errorType = String(describing: type(of: error))
                Self.logger.error("recordPurchase failed: \(errorType, privacy: .public)")
            }
        }
    }

    @discardableResult
    func restoreCompleted() -> Task<Void, Never>? {
        guard configureIfAllowed() else { return nil }
        return Task { await migrateExistingPurchases(userInitiated: true) }
    }

    private func configureIfAllowed() -> Bool {
        guard configuration.permitsObserver(in: context) else { return false }
        if !configured {
            guard transport.configure(publicSDKKey: configuration.publicSDKKey) else { return false }
            configured = true
        }
        return true
    }

    private func migrateExistingPurchases(userInitiated: Bool) async {
        guard configured, let customerID = transport.appUserID else { return }
        let products = await entitlementProductIDs()
        let outcome = await coordinator.syncExistingPurchases(
            enabled: configured, customerID: customerID,
            eligibleProductIDs: products, userInitiated: userInitiated
        ) { try await transport.syncPurchases() }
        if outcome == .failed { Self.logger.error("syncExistingPurchases failed") }
    }

    private static func currentEntitlementProductIDs() async -> Set<String> {
        var products = Set<String>()
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, eligible(transaction) { products.insert(transaction.productID) }
        }
        return products
    }

    // Filters manual migration candidates, not the SDK's independent automatic collection.
    private static func eligible(_ transaction: StoreKit.Transaction) -> Bool {
        RevenueCatMigrationPurchase(
            productID: transaction.productID, isVerified: true,
            isRevoked: transaction.revocationDate != nil,
            expirationDate: transaction.expirationDate
        ).isEligible(productIDs: productIDs, now: .now)
    }
}
