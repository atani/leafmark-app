import Foundation

/// One continuous stretch of reading a single book.
struct ReadingSession: Codable, Identifiable, Equatable {
    let id: String
    let bookID: String
    let startedAt: Date
    let duration: TimeInterval
}

/// Records reading sessions and derives the statistics shown in StatsView.
@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var sessions: [ReadingSession] = []

    private let storeURL: URL

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("reading-sessions.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([ReadingSession].self, from: data)
        else { return }
        sessions = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    /// Sessions shorter than this are noise (opened by accident), not reading.
    static let minimumSessionDuration: TimeInterval = 5

    func recordSession(bookID: String, startedAt: Date, endedAt: Date) {
        let duration = endedAt.timeIntervalSince(startedAt)
        guard duration >= Self.minimumSessionDuration else { return }
        sessions.append(ReadingSession(
            id: UUID().uuidString,
            bookID: bookID,
            startedAt: startedAt,
            duration: duration
        ))
        save()
    }

    // MARK: - Aggregations

    private var calendar: Calendar { .current }

    func totalTime(since: Date? = nil) -> TimeInterval {
        sessions
            .filter { session in
                guard let since else { return true }
                return session.startedAt >= since
            }
            .reduce(0) { $0 + $1.duration }
    }

    var todayTime: TimeInterval {
        totalTime(since: calendar.startOfDay(for: Date()))
    }

    var thisWeekTime: TimeInterval {
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
        return totalTime(since: start)
    }

    /// Consecutive days (ending today or yesterday) with at least one session.
    var streakDays: Int {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        // A streak survives if today has no reading yet but yesterday does.
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday)
            else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Total reading time per book, most-read first.
    func timePerBook() -> [(bookID: String, time: TimeInterval)] {
        Dictionary(grouping: sessions, by: \.bookID)
            .map { (bookID: $0.key, time: $0.value.reduce(0) { $0 + $1.duration }) }
            .sorted { $0.time > $1.time }
    }

    static func format(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
