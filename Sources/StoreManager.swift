import Foundation
import StoreKit

/// Owns the single "Inkwell Pro" non-consumable purchase (ADR-0005).
///
/// Free reading is always available; Pro unlocks the annotation workflow:
/// unlimited highlights, Markdown export and reading statistics.
@MainActor
final class StoreManager: ObservableObject {
    static let proProductID = "com.atani.inkwell.pro"

    /// Free tier allows a few highlights per book so the feature can be
    /// tried before buying. Pro removes the cap.
    static let freeHighlightLimit = 3

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var purchaseInFlight = false

    private var updatesTask: Task<Void, Never>?

#if DEBUG
    /// Forces the Pro entitlement for App Store screenshot capture, enabled
    /// only by the `-inkwellForcePro` launch argument in DEBUG builds. The
    /// simulator does not serve the bundled StoreKit configuration to apps
    /// launched outside Xcode, so this is the only way to render the Pro-only
    /// screens (statistics, export) for screenshots. Never compiled into release.
    private let forcePro = ProcessInfo.processInfo.arguments.contains("-inkwellForcePro")
#endif

    init() {
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
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
        } catch {
            product = nil
        }
    }

    /// Buys Inkwell Pro. Returns true when the purchase completed and unlocked.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return isPro
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// Restores a previous purchase (App Store account sync).
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// True while the user is allowed to create another highlight in a book.
    static func canAddHighlight(isPro: Bool, currentCount: Int) -> Bool {
        isPro || currentCount < freeHighlightLimit
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
