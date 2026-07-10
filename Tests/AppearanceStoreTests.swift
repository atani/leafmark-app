import XCTest
@testable import Leafmark

/// AppearanceStore is backed by @AppStorage (UserDefaults.standard), so
/// every test saves and restores the touched keys to avoid leaking state
/// into other tests or the host app.
@MainActor
final class AppearanceStoreTests: XCTestCase {
    private let touchedKeys = ["reader.font", "reader.fontWeight", "reader.lineHeight", "reader.pageMargins"]
    private var savedValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in touchedKeys {
            savedValues[key] = UserDefaults.standard.object(forKey: key)
        }
    }

    override func tearDown() {
        for key in touchedKeys {
            if let value = savedValues[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    // MARK: - selectedFontFamily

    func testSelectedFontFamilyResolvesCustomPrefix() {
        let store = AppearanceStore()
        store.fontRaw = AppearanceStore.customFontPrefix + "My Font"
        XCTAssertEqual(store.selectedFontFamily?.rawValue, "My Font")
    }

    func testSelectedFontFamilyResolvesSystemPrefix() {
        let store = AppearanceStore()
        store.fontRaw = AppearanceStore.systemFontPrefix + "Avenir Next"
        XCTAssertEqual(store.selectedFontFamily?.rawValue, "Avenir Next")
    }

    func testSelectedFontFamilyForBuiltins() {
        let store = AppearanceStore()

        store.fontRaw = AppearanceStore.ReaderFont.georgia.rawValue
        XCTAssertEqual(store.selectedFontFamily?.rawValue, "Georgia")

        store.fontRaw = AppearanceStore.ReaderFont.publisher.rawValue
        XCTAssertNil(store.selectedFontFamily, "Publisher は出版社既定に任せるため nil")
    }

    func testPreferencesCarrySelectedCustomFamily() {
        let store = AppearanceStore()
        store.fontRaw = AppearanceStore.customFontPrefix + "游明朝"
        XCTAssertEqual(store.preferences.fontFamily?.rawValue, "游明朝")
    }

    // MARK: - fontWeight

    func testPreferencesOmitFontWeightAtDefault() {
        let store = AppearanceStore()
        store.fontWeight = 1.0
        XCTAssertNil(store.preferences.fontWeight, "1.0 は出版社の太さを尊重して nil 送信")
    }

    func testPreferencesIncludeAdjustedFontWeight() {
        let store = AppearanceStore()

        store.fontWeight = 1.25
        XCTAssertEqual(store.preferences.fontWeight, 1.25)

        store.fontWeight = AppearanceStore.fontWeightRange.lowerBound
        XCTAssertEqual(store.preferences.fontWeight, 0.5, "下限も送信される")

        store.fontWeight = AppearanceStore.fontWeightRange.upperBound
        XCTAssertEqual(store.preferences.fontWeight, 2.5, "上限も送信される")
    }

    func testReaderAdjustmentRangesAllowFineControl() {
        XCTAssertEqual(AppearanceStore.fontWeightStep, 0.05)
        XCTAssertEqual(AppearanceStore.lineHeightRange.lowerBound, 0.8)
        XCTAssertEqual(AppearanceStore.lineHeightStep, 0.05)
        XCTAssertEqual(AppearanceStore.pageMarginsRange.lowerBound, 0.0)
        XCTAssertEqual(AppearanceStore.pageMarginsStep, 0.05)
    }
}
