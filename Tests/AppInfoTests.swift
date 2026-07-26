import XCTest
@testable import Leafmark

final class AppInfoTests: XCTestCase {
    func testVersionMatchesTheBundle() {
        let expected = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        XCTAssertEqual(AppInfo.version, expected ?? "—")
    }

    func testBuildMatchesTheBundle() {
        let expected = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        XCTAssertEqual(AppInfo.build, expected ?? "—")
    }

    func testDisplayCombinesVersionAndBuild() {
        XCTAssertEqual(
            AppInfo.versionDisplay,
            "\(AppInfo.version) (\(AppInfo.build))",
            "同じマーケティング版で複数ビルドが出るのでビルド番号も見せる"
        )
    }

    func testDisplayIsNotEmptyOrPlaceholderOnly() {
        XCTAssertFalse(AppInfo.versionDisplay.isEmpty)
        XCTAssertNotEqual(
            AppInfo.versionDisplay,
            "— (—)",
            "バンドルから版が取れない状態では報告の切り分けに使えない"
        )
    }
}
