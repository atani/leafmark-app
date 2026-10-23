import Foundation
import StoreKit

/// Owns the single "Leafmark Pro" non-consumable purchase (ADR-0005).
///
/// Free reading is always available; Pro unlocks the annotation workflow:
/// unlimited highlights, Markdown export and reading statistics.
@MainActor
final class StoreManager: ObservableObject {
    static let proProductID = "com.atani.inkwell.pro"

    /// Free tier allows a few highlights per book so the feature can be
    /// tried before buying. Pro removes the cap.
    nonisolated static let freeHighlightLimit = 3

    /// Persists whether the one free Markdown export has been spent.
    private static let freeExportUsedKey = "store.freeExportUsed"

    @Published private(set) var isPro = false

    /// True once the free tier's single Markdown export has been used.
    ///
    /// Free readers get to export their highlights exactly once so they can
    /// see the actual Markdown land in Obsidian before paying. Promising
    /// "your highlights are yours" while blocking every export contradicts
    /// the pitch, so the first one is always allowed.
    @Published private(set) var hasUsedFreeExport =
        UserDefaults.standard.bool(forKey: StoreManager.freeExportUsedKey)
    @Published private(set) var product: Product?
    @Published private(set) var purchaseInFlight = false
    @Published private(set) var productLoadFailed = false

    private var updatesTask: Task<Void, Never>?
    private let analytics: FunnelAnalytics

#if DEBUG
    /// Forces the Pro entitlement for App Store screenshot capture, enabled
    /// only by the `-leafmarkForcePro` launch argument in DEBUG builds. The
    /// simulator does not serve the bundled StoreKit configuration to apps
    /// launched outside Xcode, so this is the only way to render the Pro-only
    /// screens (statistics, export) for screenshots. Never compiled into release.
    private let forcePro = ProcessInfo.processInfo.arguments.contains("-leafmarkForcePro")
#endif

    private let defaults: UserDefaults

    /// A purchase this device started that StoreKit left pending (Ask to Buy,
    /// extra authentication). Its approval arrives through Transaction.updates.
    private struct PendingPurchase: Codable {
        let source: String?
        let requestedAt: Date
    }
    private static let pendingPurchaseKey = "store.funnel.pendingPurchase"
    /// Ask to Buy requests expire; an approval after this is not attributed.
    nonisolated static let pendingPurchaseLifetime: TimeInterval = 7 * 24 * 60 * 60
    /// Allows for a device clock that runs ahead of the App Store's.
    nonisolated static let purchaseClockTolerance: TimeInterval = 10 * 60

    init(analytics: FunnelAnalytics? = nil, defaults: UserDefaults? = nil) {
        self.analytics = analytics ?? .shared
        self.defaults = defaults ?? .standard
#if DEBUG
        if forcePro { isPro = true }
#endif
        // Apply Transaction.updates (purchases made on other devices, Ask to
        // Buy approvals, refunds) for the whole app lifetime.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    self.completePendingPurchase(CompletedProPurchase(transaction))
                    await self.refreshEntitlements()
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Loads the product metadata and the current entitlement state.
    func load() async {
        await refreshEntitlements()
        productLoadFailed = false
        do {
            let products = try await Product.products(for: [Self.proProductID])
            // An empty array (no throw) means the product ID is unknown in this
            // environment — treat it the same as a network failure so the
            // PaywallView shows the retry button instead of an endless spinner.
            if let found = products.first {
                product = found
            } else {
                product = nil
                productLoadFailed = true
            }
        } catch {
            product = nil
            productLoadFailed = true
        }
    }

    /// Buys Leafmark Pro. Returns true when the purchase completed and unlocked.
    /// `source` is the paywall entry the purchase started from (ADR-0009).
    @discardableResult
    func purchase(source: PaywallSource? = nil) async -> Bool {
        guard let product else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        let wasPro = isPro
        let requestedAt = Date()

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                RevenueCatObserver.shared.recordPurchase(.success(verification))
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    defaults.removeObject(forKey: Self.pendingPurchaseKey)
                    recordCompletedPurchase(CompletedProPurchase(transaction), wasPro: wasPro,
                                            source: source, requestedAt: requestedAt)
                    await refreshEntitlements()
                    return isPro
                }
                return false
            case .pending:
                rememberPendingPurchase(source: source, requestedAt: requestedAt)
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// True for a new Pro purchase. A re-purchase by an Apple ID that already
    /// owned Pro returns the original transaction, so it is dated before the
    /// request; that, a Family Sharing grant, or Pro already being unlocked
    /// means nothing new was bought.
    nonisolated static func isNewPurchase(_ purchase: CompletedProPurchase, wasPro: Bool,
                                          requestedAt: Date) -> Bool {
        purchase.productID == proProductID && !purchase.isFamilyShared && !purchase.isRevoked && !wasPro
            && purchase.purchaseDate >= requestedAt.addingTimeInterval(-purchaseClockTolerance)
    }

    /// Sends `purchase_completed` once for a new purchase. Restores never call this.
    @discardableResult
    func recordCompletedPurchase(_ purchase: CompletedProPurchase, wasPro: Bool,
                                 source: PaywallSource?, requestedAt: Date) -> Bool {
        guard Self.isNewPurchase(purchase, wasPro: wasPro, requestedAt: requestedAt) else { return false }
        analytics.record(.purchaseCompleted(source))
        return true
    }

    /// Counts a pending purchase of this device once StoreKit approves it.
    /// Purchases made on other devices are counted on the device that made them.
    ///
    /// The current `isPro` is not consulted: entitlements may refresh before
    /// the update arrives. The saved request itself shows Pro was not owned
    /// when the purchase started. The request is cleared only when it is
    /// counted or expires, so an unrelated older transaction (dated before the
    /// request) cannot consume it, and a counted approval cannot count twice.
    @discardableResult
    func completePendingPurchase(_ purchase: CompletedProPurchase, now: Date = Date()) -> Bool {
        guard purchase.productID == Self.proProductID,
              let data = defaults.data(forKey: Self.pendingPurchaseKey),
              let pending = try? JSONDecoder().decode(PendingPurchase.self, from: data) else { return false }
        guard now.timeIntervalSince(pending.requestedAt) <= Self.pendingPurchaseLifetime else {
            defaults.removeObject(forKey: Self.pendingPurchaseKey)
            return false
        }
        guard Self.isNewPurchase(purchase, wasPro: false, requestedAt: pending.requestedAt) else { return false }
        defaults.removeObject(forKey: Self.pendingPurchaseKey)
        return recordCompletedPurchase(purchase, wasPro: false,
                                       source: pending.source.flatMap(PaywallSource.init(rawValue:)),
                                       requestedAt: pending.requestedAt)
    }

#if DEBUG
    /// Lets unit tests reproduce entitlements refreshing before an update. Never compiled into release.
    func setProForTesting(_ value: Bool) { isPro = value }
#endif

    func rememberPendingPurchase(source: PaywallSource?, requestedAt: Date) {
        let pending = PendingPurchase(source: source?.rawValue, requestedAt: requestedAt)
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: Self.pendingPurchaseKey)
        }
    }

    /// Restores a previous purchase (App Store account sync).
    func restore() async {
        do {
            try await AppStore.sync()
            RevenueCatObserver.shared.restoreCompleted()
        } catch {}
        await refreshEntitlements()
    }

    /// True while the user is allowed to create another highlight in a book.
    static func canAddHighlight(isPro: Bool, currentCount: Int) -> Bool {
        isPro || currentCount < freeHighlightLimit
    }

    /// True while the user is allowed to run a Markdown export.
    ///
    /// Pro exports without limit; the free tier gets exactly one.
    static func canExport(isPro: Bool, hasUsedFreeExport: Bool) -> Bool {
        isPro || !hasUsedFreeExport
    }

    /// Spends the free tier's single export. No-op for Pro, so restoring or
    /// buying Pro never consumes the free allowance.
    func markFreeExportUsed() {
        guard !isPro, !hasUsedFreeExport else { return }
        hasUsedFreeExport = true
        UserDefaults.standard.set(true, forKey: Self.freeExportUsedKey)
        analytics.record(.freeExportUsed)
    }

    /// Records the system share completion result; opening or canceling is not an export.
    @discardableResult
    func completeExport(success: Bool) -> Bool {
        guard success else { return false }
        markFreeExportUsed()
        return true
    }

    private func refreshEntitlements() async {
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
#if DEBUG
        isPro = forcePro || unlocked
#else
        isPro = unlocked
#endif
    }
}

/// The parts of a finished StoreKit transaction that decide whether it is a
/// new Pro purchase. Kept separate from `Transaction` so tests can build one.
struct CompletedProPurchase: Equatable {
    let productID: String
    let purchaseDate: Date
    var isFamilyShared = false
    var isRevoked = false
}

extension CompletedProPurchase {
    init(_ transaction: Transaction) {
        self.init(productID: transaction.productID, purchaseDate: transaction.purchaseDate,
                  isFamilyShared: transaction.ownershipType == .familyShared,
                  isRevoked: transaction.revocationDate != nil)
    }
}
