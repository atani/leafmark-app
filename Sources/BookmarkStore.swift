import Foundation
import ReadiumShared

/// Persists bookmarks for all books as a single JSON file, mirroring
/// HighlightStore (ADR-0004).
@MainActor
final class BookmarkStore: ObservableObject {
    @Published private(set) var bookmarks: [Bookmark] = []

    private let storeURL: URL

    /// Parsed Locators keyed by bookmark id. The toolbar's "is this page
    /// bookmarked?" check and the list's sort run on every page turn and
    /// every render, so the JSON is parsed once here on load/mutation
    /// instead of on each read.
    private var locatorCache: [String: Locator] = [:]

    /// Two positions in the same resource are treated as the same page when
    /// their progressions are within this margin, so the toolbar toggle can
    /// tell whether the current page is already bookmarked.
    private static let sameProgressionEpsilon = 0.001

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bookmarks.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return }
        bookmarks = Self.pruningExpiredTombstones(decoded)
        rebuildCache()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    /// Drops tombstones past the sync retention window so soft-deleted records
    /// cannot accumulate forever in the local catalog.
    private static func pruningExpiredTombstones(_ records: [Bookmark], now: Date = Date()) -> [Bookmark] {
        records.filter { record in
            guard let deletedAt = record.deletedAt else { return true }
            return now.timeIntervalSince(deletedAt) < AnnotationSyncMerge.tombstoneRetention
        }
    }

    private func rebuildCache() {
        // uniquingKeysWith (not uniqueKeysWithValues) so a corrupt catalog
        // with duplicate ids can't trap at launch. Tombstones are excluded so a
        // soft-deleted bookmark is never matched as present.
        locatorCache = Dictionary(
            bookmarks.compactMap { bookmark -> (String, Locator)? in
                guard bookmark.deletedAt == nil else { return nil }
                return Self.parseLocator(bookmark.locatorJSON).map { (bookmark.id, $0) }
            },
            uniquingKeysWith: { current, _ in current }
        )
    }

    private static func parseLocator(_ json: String) -> Locator? {
        guard let value = try? JSONValue(jsonString: json) else { return nil }
        return try? Locator(json: value, warnings: nil)
    }

    /// Bookmarks of a book, ordered by reading position.
    func bookmarks(for bookID: String) -> [Bookmark] {
        bookmarks
            .filter { $0.bookID == bookID && $0.deletedAt == nil }
            .sorted { lhs, rhs in
                let lp = progression(of: lhs) ?? 0
                let rp = progression(of: rhs) ?? 0
                return lp == rp ? lhs.createdAt < rhs.createdAt : lp < rp
            }
    }

    func locator(of bookmark: Bookmark) -> Locator? {
        locatorCache[bookmark.id]
    }

    /// The bookmark at the given position, if any (same resource and
    /// near-identical position).
    func bookmark(for bookID: String, at locator: Locator) -> Bookmark? {
        bookmarks.first { bookmark in
            guard bookmark.bookID == bookID,
                  bookmark.deletedAt == nil,
                  let stored = self.locator(of: bookmark),
                  stored.href.isEquivalentTo(locator.href)
            else { return false }
            if let storedProgression = stored.locations.totalProgression,
               let currentProgression = locator.locations.totalProgression {
                return abs(storedProgression - currentProgression) < Self.sameProgressionEpsilon
            }
            // No total progression (e.g. positions not yet computed): fall
            // back to the resource-relative position. When neither is known,
            // treat the positions as different so toggling a new bookmark
            // never silently deletes one elsewhere in the same resource.
            if let storedPosition = stored.locations.position,
               let currentPosition = locator.locations.position {
                return storedPosition == currentPosition
            }
            return false
        }
    }

    func isBookmarked(bookID: String, at locator: Locator) -> Bool {
        bookmark(for: bookID, at: locator) != nil
    }

    @discardableResult
    func add(bookID: String, locator: Locator, title: String?) -> Bookmark {
        let now = Date()
        let bookmark = Bookmark(
            id: UUID().uuidString,
            bookID: bookID,
            locatorJSON: (try? locator.jsonString()) ?? "{}",
            title: title,
            createdAt: now,
            updatedAt: now
        )
        bookmarks.append(bookmark)
        locatorCache[bookmark.id] = locator
        save()
        return bookmark
    }

    /// Adds a bookmark at the position if none exists there, otherwise
    /// removes the existing one. Returns true when a bookmark now exists.
    @discardableResult
    func toggle(bookID: String, locator: Locator, title: String?) -> Bool {
        if let existing = bookmark(for: bookID, at: locator) {
            remove(existing.id)
            return false
        }
        add(bookID: bookID, locator: locator, title: title)
        return true
    }

    /// Soft-deletes a bookmark, leaving a tombstone so the deletion syncs to
    /// other devices. The tombstone is pruned after the retention window.
    func remove(_ id: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        bookmarks[index].deletedAt = now
        bookmarks[index].updatedAt = now
        locatorCache[id] = nil
        save()
    }

    /// Hard-deletes every bookmark of a book. Used when the book itself is
    /// removed from the library, so it must NOT leave tombstones: another
    /// device that still holds the book keeps its annotations.
    func removeAll(for bookID: String) {
        let removed = bookmarks.filter { $0.bookID == bookID }
        bookmarks.removeAll { $0.bookID == bookID }
        for bookmark in removed { locatorCache[bookmark.id] = nil }
        save()
    }

    // MARK: - Sync

    /// All records for a book including tombstones, as sync documents carry
    /// deletions.
    func syncedRecords(for bookID: String) -> [SyncedBookmark] {
        bookmarks.filter { $0.bookID == bookID }.map(SyncedBookmark.init)
    }

    /// Replaces a book's records with a merged set from the sync layer. Callers
    /// guard against the resulting publisher change re-triggering a push.
    func applyMerged(_ records: [SyncedBookmark], bookID: String) {
        bookmarks.removeAll { $0.bookID == bookID }
        bookmarks.append(contentsOf: records.map { $0.bookmark(bookID: bookID) })
        bookmarks = Self.pruningExpiredTombstones(bookmarks)
        rebuildCache()
        save()
    }

    func progression(of bookmark: Bookmark) -> Double? {
        locator(of: bookmark)?.locations.totalProgression
    }

    // MARK: - Labels

    /// A percentage label for a reading progression, clamped to 0–100 so a
    /// corrupt/out-of-range value can't trap `Int(_:)`. The constant-first
    /// order matters: `max(0, .nan)` returns 0 (the comparison is false), so
    /// NaN clamps to 0 instead of flowing into a trapping `Int(.nan)`.
    static func progressionLabel(_ progression: Double) -> String {
        let clamped = min(1, max(0, progression))
        return "\(Int((clamped * 100).rounded()))%"
    }
}
