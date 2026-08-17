import Foundation

/// Decides when to offer the App Store review prompt.
///
/// Milestones, all of which are moments where the reader just got something
/// out of the app rather than moments where it interrupted them:
/// - A third distinct book has been opened
/// - A Markdown export was shared
/// - A tenth highlight was created
/// - A book was read to 90%
///
/// A milestone only *offers* the prompt. `requestReview()` reports nothing
/// back and iOS drops it silently — while another sheet is presenting, or once
/// Apple's own display budget (three prompts per 365 days) is spent. Attempts
/// are therefore timestamped and spaced out rather than capped at one, so a
/// prompt that was never actually shown is retried at the next milestone
/// instead of permanently burning the only chance.
///
/// What this deliberately does not do: ask how the reader feels first and only
/// forward the happy ones to the prompt. Apple prohibits gating the prompt on
/// sentiment, and `docs/marketing.md` lists it under 今月はやらないこと.
enum ReviewRequester {
    private static let openedBookIDsKey = "reviewRequester.openedBookIDs"
    private static let attemptsKey = "reviewRequester.attemptTimestamps"
    /// Pre-1.14 one-shot flag, folded into `attemptsKey` on first read.
    private static let legacyHasRequestedKey = "reviewRequester.hasRequested"

    /// Distinct books opened before the prompt is offered.
    static let bookOpenMilestone = 3
    /// Highlights created before the prompt is offered.
    static let highlightMilestone = 10
    /// Share of a book that counts as having read it.
    static let finishedProgression = 0.9

    /// Attempts allowed per 365 days. Apple displays at most three prompts in
    /// that window; a fourth attempt costs nothing when the system ignores it,
    /// and pays off when an earlier attempt was dropped without being shown.
    static let maxAttemptsPerYear = 4
    /// Minimum gap between attempts, so nobody is asked twice in a month.
    static let minimumInterval: TimeInterval = 21 * 24 * 60 * 60

    private static let year: TimeInterval = 365 * 24 * 60 * 60

    /// True when the rate limit allows another prompt right now.
    static func canAsk(defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        let attempts = recentAttempts(defaults: defaults, now: now)
        guard attempts.count < maxAttemptsPerYear else { return false }
        guard let last = attempts.max() else { return true }
        return now.timeIntervalSince(last) >= minimumInterval
    }

    /// Call when a book is opened. Returns `true` when the prompt should be
    /// shown.
    static func recordBookOpen(
        bookID: String,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        var ids = defaults.stringArray(forKey: openedBookIDsKey) ?? []
        if !ids.contains(bookID) {
            ids.append(bookID)
            defaults.set(ids, forKey: openedBookIDsKey)
        }
        guard ids.count >= bookOpenMilestone else { return false }
        return canAsk(defaults: defaults, now: now)
    }

    /// Call when the Markdown export share sheet is opened, matching where the
    /// free export quota is spent (`ShareLink` reports no completion). Returns
    /// `true` when the prompt should be shown; the caller is expected to defer
    /// it until no other sheet is presenting.
    static func recordExport(defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        canAsk(defaults: defaults, now: now)
    }

    /// Call after a highlight is created, with the reader's total across all
    /// books. Returns `true` when the prompt should be shown.
    static func recordHighlightCreated(
        totalCount: Int,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        guard totalCount >= highlightMilestone else { return false }
        return canAsk(defaults: defaults, now: now)
    }

    /// Call as the reading position moves. Returns `true` once the reader has
    /// reached the end of a book and the prompt should be shown.
    static func recordReadingProgress(
        _ progression: Double?,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        guard let progression, progression >= finishedProgression else { return false }
        return canAsk(defaults: defaults, now: now)
    }

    /// Record that the prompt has just been offered, so the next milestone
    /// waits out the cooldown instead of asking again immediately. Call it
    /// before `requestReview()`, which cannot report whether it displayed.
    static func markRequested(defaults: UserDefaults = .standard, now: Date = Date()) {
        var stored = storedAttempts(defaults: defaults)
        stored.append(now.timeIntervalSince1970)
        defaults.set(stored, forKey: attemptsKey)
    }

    private static func recentAttempts(defaults: UserDefaults, now: Date) -> [Date] {
        migrateLegacyFlagIfNeeded(defaults: defaults, now: now)
        let cutoff = now.addingTimeInterval(-year)
        return storedAttempts(defaults: defaults)
            .map(Date.init(timeIntervalSince1970:))
            .filter { $0 > cutoff }
    }

    private static func storedAttempts(defaults: UserDefaults) -> [Double] {
        defaults.array(forKey: attemptsKey) as? [Double] ?? []
    }

    /// Installs that already saw the one-shot prompt keep that history: the old
    /// flag becomes a single attempt dated now, so the cooldown applies before
    /// they are asked again.
    private static func migrateLegacyFlagIfNeeded(defaults: UserDefaults, now: Date) {
        guard defaults.bool(forKey: legacyHasRequestedKey) else { return }
        defaults.removeObject(forKey: legacyHasRequestedKey)
        var stored = storedAttempts(defaults: defaults)
        stored.append(now.timeIntervalSince1970)
        defaults.set(stored, forKey: attemptsKey)
    }
}
