import Foundation

extension AppExecutionContext {
    func allowsObserver(releaseEnabled: Bool) -> Bool {
        bundleIdentifier == Self.appBundleIdentifier && !isTesting && !isPreview && !isDemo
            && (!isReleaseBuild || releaseEnabled)
    }
}

struct RevenueCatMigrationConfiguration: Equatable {
    let mode: String
    let publicSDKKey: String
    let dataSharingApproved: Bool
    var integrationReady = false
    var privacyReady = false
    var releaseEnabled = false

    init(mode: String, publicSDKKey: String, dataSharingApproved: Bool,
         integrationReady: Bool = false, privacyReady: Bool = false, releaseEnabled: Bool = false) {
        self.mode = mode
        self.publicSDKKey = publicSDKKey
        self.dataSharingApproved = dataSharingApproved
        self.integrationReady = integrationReady
        self.privacyReady = privacyReady
        self.releaseEnabled = releaseEnabled
    }

    init(infoDictionary info: [String: Any]?) {
        func flag(_ key: String) -> Bool { info?[key] as? String == "YES" }
        self.init(mode: info?["RevenueCatMode"] as? String ?? "disabled",
                  publicSDKKey: info?["RevenueCatPublicSDKKey"] as? String ?? "",
                  dataSharingApproved: flag("RevenueCatDataSharingApproved"),
                  integrationReady: flag("RevenueCatIntegrationReady"),
                  privacyReady: flag("RevenueCatPrivacyReady"),
                  releaseEnabled: flag("RevenueCatReleaseEnabled"))
    }

    func permitsObserver(in context: AppExecutionContext) -> Bool {
        context.allowsObserver(releaseEnabled: releaseEnabled)
            && mode == "observer" && dataSharingApproved && integrationReady && privacyReady && validPublicSDKKey
    }

    private var validPublicSDKKey: Bool {
        let suffix = publicSDKKey.dropFirst(5)
        return publicSDKKey.hasPrefix("appl_") && suffix.count >= 10
            && suffix.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
            && !["example", "placeholder", "replace", "your"].contains(where: publicSDKKey.lowercased().contains)
    }
}

struct RevenueCatMigrationPurchase: Equatable {
    let productID: String
    let isVerified: Bool
    let isRevoked: Bool
    let expirationDate: Date?
    /// Family Sharing grants belong to the organizer's purchase. RevenueCat's
    /// sync does not report them for the member, so syncing them would fail
    /// and retry on every launch. StoreKit still unlocks Pro for the member.
    var isFamilyShared = false

    func isEligible(productIDs: Set<String>, now: Date) -> Bool {
        isVerified && !isRevoked && !isFamilyShared && productIDs.contains(productID)
            && (expirationDate.map { $0 > now } ?? true)
    }
}

/// StoreKitを利用権の正本に保ち、成功した移行だけを顧客ID別に記録する。
@MainActor
final class RevenueCatMigrationCoordinator {
    enum Outcome: Equatable { case skipped, synced, failed }

    private let syncedProductIDs: (String) -> Set<String>
    private let markSynced: (String, Set<String>) -> Void
    private let clearSynced: (String) -> Void
    private var attemptedProductIDs = [String: Set<String>]()
    private var inFlightCustomers = Set<String>()
    private var generations = [String: UInt64]()

    init(syncedProductIDs: @escaping (String) -> Set<String>,
         markSynced: @escaping (String, Set<String>) -> Void,
         clearSynced: @escaping (String) -> Void) {
        self.syncedProductIDs = syncedProductIDs
        self.markSynced = markSynced
        self.clearSynced = clearSynced
    }

    func invalidate(customerID: String) {
        generations[customerID, default: 0] &+= 1
        attemptedProductIDs.removeValue(forKey: customerID)
        clearSynced(customerID)
    }

    func syncExistingPurchases(
        enabled: Bool,
        customerID: String,
        eligibleProductIDs: Set<String>,
        userInitiated: Bool = false,
        sync: () async throws -> Set<String>
    ) async -> Outcome {
        guard enabled, !customerID.isEmpty, !eligibleProductIDs.isEmpty,
              !inFlightCustomers.contains(customerID) else { return .skipped }
        if !userInitiated && (eligibleProductIDs.isSubset(of: syncedProductIDs(customerID))
            || eligibleProductIDs.isSubset(of: attemptedProductIDs[customerID] ?? [])) { return .skipped }
        let generation = generations[customerID, default: 0]
        attemptedProductIDs[customerID] = eligibleProductIDs
        inFlightCustomers.insert(customerID)
        defer { inFlightCustomers.remove(customerID) }
        do {
            let recordedProductIDs = try await sync()
            // A newer purchase may have invalidated this request while it awaited
            // the backend. Never persist an older response over that invalidation.
            guard generation == generations[customerID, default: 0] else { return .skipped }
            guard eligibleProductIDs.isSubset(of: recordedProductIDs) else { return .failed }
            markSynced(customerID, eligibleProductIDs)
            return .synced
        } catch {
            return .failed
        }
    }
}
