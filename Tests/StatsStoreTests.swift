import XCTest
@testable import Inkwell

@MainActor
final class StatsStoreTests: XCTestCase {
    private var tempURL: URL!
    private var store: StatsStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("stats-\(UUID().uuidString).json")
        store = StatsStore(storeURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    // MARK: - format

    func testFormatUnderOneHour() {
        XCTAssertEqual(StatsStore.format(0), "0m")
        XCTAssertEqual(StatsStore.format(59), "0m")
        XCTAssertEqual(StatsStore.format(60), "1m")
        XCTAssertEqual(StatsStore.format(25 * 60), "25m")
        XCTAssertEqual(StatsStore.format(59 * 60), "59m")
    }

    func testFormatOverOneHour() {
        XCTAssertEqual(StatsStore.format(60 * 60), "1h 0m")
        XCTAssertEqual(StatsStore.format(90 * 60), "1h 30m")
        XCTAssertEqual(StatsStore.format(125 * 60), "2h 5m")
    }

    // MARK: - recordSession

    func testRecordSessionDropsTooShortSessions() {
        let start = Date()
        store.recordSession(bookID: "a", startedAt: start, endedAt: start.addingTimeInterval(4))
        XCTAssertEqual(store.sessions.count, 0, "5秒未満は記録されない")

        store.recordSession(bookID: "a", startedAt: start, endedAt: start.addingTimeInterval(5))
        XCTAssertEqual(store.sessions.count, 1, "ちょうど5秒は記録される")
    }

    func testRecordSessionPersistsAcrossInstances() {
        let start = Date()
        store.recordSession(bookID: "a", startedAt: start, endedAt: start.addingTimeInterval(600))
        let reloaded = StatsStore(storeURL: tempURL)
        XCTAssertEqual(reloaded.sessions.count, 1)
    }

    func testRemoveAllForBookRemovesOnlyThatBook() {
        let start = Date()
        store.recordSession(bookID: "a", startedAt: start, endedAt: start.addingTimeInterval(600))
        store.recordSession(bookID: "a", startedAt: start, endedAt: start.addingTimeInterval(300))
        store.recordSession(bookID: "b", startedAt: start, endedAt: start.addingTimeInterval(120))

        store.removeAll(for: "a")

        XCTAssertTrue(store.sessions.allSatisfy { $0.bookID == "b" }, "対象の本のセッションは全削除、他は残る")
        XCTAssertEqual(store.sessions.count, 1)

        let reloaded = StatsStore(storeURL: tempURL)
        XCTAssertEqual(reloaded.sessions.count, 1, "削除が永続化される")
    }

    // MARK: - aggregations

    func testTotalTimeSumsDurations() {
        let start = Date()
        store.recordSession(bookID: "a", startedAt: start, endedAt: start.addingTimeInterval(600))
        store.recordSession(bookID: "b", startedAt: start, endedAt: start.addingTimeInterval(300))
        XCTAssertEqual(store.totalTime(), 900, accuracy: 0.001)
    }

    func testTimePerBookSortedByMostRead() {
        let start = Date()
        store.recordSession(bookID: "a", startedAt: start, endedAt: start.addingTimeInterval(120))
        store.recordSession(bookID: "b", startedAt: start, endedAt: start.addingTimeInterval(600))
        store.recordSession(bookID: "a", startedAt: start, endedAt: start.addingTimeInterval(120))

        let ranking = store.timePerBook()
        XCTAssertEqual(ranking.count, 2)
        XCTAssertEqual(ranking[0].bookID, "b", "最も読んだ本が先頭")
        XCTAssertEqual(ranking[0].time, 600, accuracy: 0.001)
        XCTAssertEqual(ranking[1].bookID, "a")
        XCTAssertEqual(ranking[1].time, 240, accuracy: 0.001)
    }

    // MARK: - streakDays

    func testStreakIsZeroWhenNoSessions() {
        XCTAssertEqual(store.streakDays, 0)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for offset in 0...2 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            store.recordSession(bookID: "a", startedAt: day, endedAt: day.addingTimeInterval(600))
        }
        XCTAssertEqual(store.streakDays, 3)
    }

    func testStreakSurvivesWhenTodayEmptyButYesterdayRead() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for offset in 1...2 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            store.recordSession(bookID: "a", startedAt: day, endedAt: day.addingTimeInterval(600))
        }
        XCTAssertEqual(store.streakDays, 2, "今日未読でも昨日読んでいれば連続は継続")
    }

    func testStreakBreaksWithGap() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 今日と、3日前のみ（間に空白）
        store.recordSession(bookID: "a", startedAt: today, endedAt: today.addingTimeInterval(600))
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: today)!
        store.recordSession(bookID: "a", startedAt: threeDaysAgo, endedAt: threeDaysAgo.addingTimeInterval(600))
        XCTAssertEqual(store.streakDays, 1)
    }
}
