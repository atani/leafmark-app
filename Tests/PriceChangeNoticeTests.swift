import XCTest
@testable import Leafmark

final class PriceChangeNoticeTests: XCTestCase {
    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    func testVisibleUntilTheEndOfTheDayBeforeInLocalTime() {
        let tokyo = calendar("Asia/Tokyo")
        // 東京の 2026-11-15 23:59:59 と 2026-11-16 00:00:00
        XCTAssertTrue(PriceChangeNotice.isVisible(now: date("2026-11-15T14:59:59Z"), calendar: tokyo))
        XCTAssertFalse(PriceChangeNotice.isVisible(now: date("2026-11-15T15:00:00Z"), calendar: tokyo))
    }

    func testBoundaryFollowsTheDeviceTimeZoneNotUTC() {
        let honolulu = calendar("Pacific/Honolulu")
        // UTC では 11-16 でも、ホノルルではまだ 11-15 なので表示する
        XCTAssertTrue(PriceChangeNotice.isVisible(now: date("2026-11-16T09:59:59Z"), calendar: honolulu))
        XCTAssertFalse(PriceChangeNotice.isVisible(now: date("2026-11-16T10:00:00Z"), calendar: honolulu))
    }

    func testHiddenLongAfterTheChange() {
        XCTAssertFalse(PriceChangeNotice.isVisible(now: date("2027-01-01T00:00:00Z"), calendar: calendar("UTC")))
        XCTAssertTrue(PriceChangeNotice.isVisible(now: date("2026-10-17T00:00:00Z"), calendar: calendar("UTC")))
    }

    func testMessageNamesTheDateAndNoAmount() {
        let message = PriceChangeNotice.message(calendar: calendar("Asia/Tokyo"), locale: Locale(identifier: "en_US"))
        XCTAssertEqual(message, "Price changes on November 16, 2026. If you've already purchased, there's nothing more to pay.")
        XCTAssertNil(message.range(of: #"[$¥€£]|\d+\.\d{2}"#, options: .regularExpression), "金額・通貨を書かない")
    }
}
