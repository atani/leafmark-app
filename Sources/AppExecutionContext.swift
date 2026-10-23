import Foundation

/// Where the app is running: build configuration, tests, Previews and
/// screenshot/demo launches. Shared by RevenueCat and Firebase Analytics.
struct AppExecutionContext: Equatable {
    static let appBundleIdentifier = "com.atani.inkwell"

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

    /// Firebase Analytics may start only from the shipping app in a Release
    /// build: never from Debug, tests, SwiftUI Previews or screenshot/demo
    /// launches. `FunnelAnalytics` also requires the production App Store.
    var allowsAnalytics: Bool {
        bundleIdentifier == Self.appBundleIdentifier && isReleaseBuild
            && !isTesting && !isPreview && !isDemo
    }
}
