import XCTest
@testable import Leafmark

final class ReviewRequesterTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "ReviewRequesterTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func days(_ count: Double) -> Date {
        now.addingTimeInterval(count * 24 * 60 * 60)
    }

    // MARK: - Book opens

    func testAsksOnThirdDistinctBook() {
        XCTAssertFalse(ReviewRequester.recordBookOpen(bookID: "a", defaults: defaults, now: now))
        XCTAssertFalse(ReviewRequester.recordBookOpen(bookID: "b", defaults: defaults, now: now))
        XCTAssertTrue(ReviewRequester.recordBookOpen(bookID: "c", defaults: defaults, now: now))
    }

    func testReopeningTheSameBookDoesNotCount() {
        for _ in 0 ..< 5 {
            XCTAssertFalse(
                ReviewRequester.recordBookOpen(bookID: "a", defaults: defaults, now: now)
            )
        }
    }

    // MARK: - Highlights and reading progress

    func testAsksOnTenthHighlight() {
        XCTAssertFalse(
            ReviewRequester.recordHighlightCreated(totalCount: 9, defaults: defaults, now: now)
        )
        XCTAssertTrue(
            ReviewRequester.recordHighlightCreated(totalCount: 10, defaults: defaults, now: now)
        )
    }

    func testAsksOnlyNearTheEndOfABook() {
        XCTAssertFalse(ReviewRequester.recordReadingProgress(nil, defaults: defaults, now: now))
        XCTAssertFalse(ReviewRequester.recordReadingProgress(0.5, defaults: defaults, now: now))
        XCTAssertFalse(ReviewRequester.recordReadingProgress(0.89, defaults: defaults, now: now))
        XCTAssertTrue(ReviewRequester.recordReadingProgress(0.9, defaults: defaults, now: now))
        XCTAssertTrue(ReviewRequester.recordReadingProgress(1.0, defaults: defaults, now: now))
    }

    // MARK: - Rate limiting

    func testCooldownBlocksASecondAskAndThenExpires() {
        ReviewRequester.markRequested(defaults: defaults, now: now)

        XCTAssertFalse(ReviewRequester.canAsk(defaults: defaults, now: days(20)))
        XCTAssertTrue(ReviewRequester.canAsk(defaults: defaults, now: days(21)))
    }

    func testMilestonesRespectTheCooldown() {
        _ = ReviewRequester.recordBookOpen(bookID: "a", defaults: defaults, now: now)
        _ = ReviewRequester.recordBookOpen(bookID: "b", defaults: defaults, now: now)
        XCTAssertTrue(ReviewRequester.recordBookOpen(bookID: "c", defaults: defaults, now: now))
        ReviewRequester.markRequested(defaults: defaults, now: now)

        // A different milestone reached moments later must not ask again.
        XCTAssertFalse(
            ReviewRequester.recordHighlightCreated(totalCount: 20, defaults: defaults, now: now)
        )
        XCTAssertTrue(
            ReviewRequester.recordHighlightCreated(
                totalCount: 20,
                defaults: defaults,
                now: days(21)
            )
        )
    }

    func testStopsAfterTheAnnualLimit() {
        for index in 0 ..< ReviewRequester.maxAttemptsPerYear {
            let date = days(Double(index) * 30)
            XCTAssertTrue(ReviewRequester.canAsk(defaults: defaults, now: date))
            ReviewRequester.markRequested(defaults: defaults, now: date)
        }

        XCTAssertFalse(ReviewRequester.canAsk(defaults: defaults, now: days(200)))
    }

    func testAttemptsOlderThanAYearStopCounting() {
        for index in 0 ..< ReviewRequester.maxAttemptsPerYear {
            ReviewRequester.markRequested(defaults: defaults, now: days(Double(index) * 30))
        }
        XCTAssertFalse(ReviewRequester.canAsk(defaults: defaults, now: days(200)))

        // 366 days after the first attempt, only that one has aged out, which
        // is enough to free a slot.
        XCTAssertTrue(ReviewRequester.canAsk(defaults: defaults, now: days(366)))
    }

    // MARK: - Migration from the pre-1.14 one-shot flag

    func testLegacyOneShotFlagBecomesASingleAttempt() {
        defaults.set(true, forKey: "reviewRequester.hasRequested")

        // The install already saw a prompt, so the cooldown applies from now,
        // but it is no longer locked out forever.
        XCTAssertFalse(ReviewRequester.canAsk(defaults: defaults, now: now))
        XCTAssertTrue(ReviewRequester.canAsk(defaults: defaults, now: days(21)))
        XCTAssertFalse(defaults.bool(forKey: "reviewRequester.hasRequested"))
    }
}
