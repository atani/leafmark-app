import Foundation

struct RevenueCatExecutionContext: Equatable {
    let bundleIdentifier: String?
    let isReleaseBuild: Bool
    let isTesting: Bool
    let isPreview: Bool
    let isDemo: Bool

    static var current: Self {
        #if DEBUG
        let release = false
        #else
        let release = true
        #endif
        return make(bundleIdentifier: Bundle.main.bundleIdentifier, isReleaseBuild: release,
                    arguments: ProcessInfo.processInfo.arguments,
                    environment: ProcessInfo.processInfo.environment,
                    hasXCTestClass: NSClassFromString("XCTestCase") != nil)
    }

    // UI-test apps and standalone screenshot captures do not always load XCTest.
    static func make(bundleIdentifier: String?, isReleaseBuild: Bool,
                     arguments: [String], environment: [String: String],
                     hasXCTestClass: Bool) -> Self {
        let captureSwitches: Set<String> = [
            "-ignore-purchases", "-force-pro", "-leafmarkForcePro",
            "-show-monetization-demo", "-show-ad-demo"
        ]
        let capturePrefixes = ["-demo", "-screenshot", "-store-screenshot", "-tutorial", "-ui-test", "UITEST_"]
        let captureArguments = arguments.contains {
            captureSwitches.contains($0) || capturePrefixes.contains(where: $0.hasPrefix)
        }
        let captureEnvironment = environment.contains { key, value in
            !value.isEmpty && (key.hasPrefix("SPH_UI_TEST_") || key.hasPrefix("UITEST_")
                || key.hasPrefix("PEYO_RECORD_"))
        }
        return .init(bundleIdentifier: bundleIdentifier, isReleaseBuild: isReleaseBuild,
                     isTesting: hasXCTestClass || environment["XCTestConfigurationFilePath"] != nil,
                     isPreview: environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1",
                     isDemo: captureArguments || captureEnvironment)
    }
}

struct RevenueCatMigrationConfiguration: Equatable {
    let mode: String
    let publicSDKKey: String
    let dataSharingApproved: Bool
    var integrationReady = false
    var privacyReady = false
    var releaseEnabled = false

    // Legacy Sandbox-only flags never authorize the SDK's broader automatic paths.
    func permitsSandboxObserver(isDebugBuild: Bool, isTesting: Bool, isSandbox: Bool) -> Bool { false }

    func hasSandboxConfiguration(isDebugBuild: Bool, isTesting: Bool, isSandbox: Bool) -> Bool {
        isDebugBuild && !isTesting && isSandbox && dataSharingApproved && mode == "sandbox" && validPublicSDKKey
    }

    func permitsObserver(in context: RevenueCatExecutionContext) -> Bool {
        context.bundleIdentifier == "com.atani.inkwell" && !context.isTesting && !context.isPreview
            && !context.isDemo && (!context.isReleaseBuild || releaseEnabled)
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
    let isSandbox: Bool

    func isEligible(productIDs: Set<String>, now: Date) -> Bool {
        isVerified && !isRevoked && productIDs.contains(productID)
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
