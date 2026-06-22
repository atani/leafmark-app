import Foundation

/// Tracks usage milestones and decides when to prompt for an App Store review.
///
/// Triggers (whichever comes first, only once per install):
/// - Third distinct book opened
/// - First Markdown export completed
enum ReviewRequester {
    private static let openedBookIDsKey = "reviewRequester.openedBookIDs"
    private static let hasExportedKey = "reviewRequester.hasExported"
    private static let hasRequestedKey = "reviewRequester.hasRequested"

    static var shouldRequest: Bool {
        !UserDefaults.standard.bool(forKey: hasRequestedKey)
    }

    /// Call when a book is opened. Returns `true` when the review prompt
    /// should be shown (third distinct book, first time only).
    static func recordBookOpen(bookID: String) -> Bool {
        guard shouldRequest else { return false }
        var ids = UserDefaults.standard.stringArray(forKey: openedBookIDsKey) ?? []
        if !ids.contains(bookID) {
            ids.append(bookID)
            UserDefaults.standard.set(ids, forKey: openedBookIDsKey)
        }
        return ids.count >= 3
    }

    /// Call after a successful Markdown export. Returns `true` when the
    /// review prompt should be shown (first export, first time only).
    static func recordExport() -> Bool {
        guard shouldRequest else { return false }
        if UserDefaults.standard.bool(forKey: hasExportedKey) { return false }
        UserDefaults.standard.set(true, forKey: hasExportedKey)
        return true
    }

    /// Mark that the review dialog has been presented so it is never shown again.
    static func markRequested() {
        UserDefaults.standard.set(true, forKey: hasRequestedKey)
    }
}
