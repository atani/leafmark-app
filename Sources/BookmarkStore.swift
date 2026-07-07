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
        bookmarks = decoded
        rebuildCache()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private func rebuildCache() {
        // uniquingKeysWith (not uniqueKeysWithValues) so a corrupt catalog
        // with duplicate ids can't trap at launch.
        locatorCache = Dictionary(
            bookmarks.compactMap { bookmark in
                Self.parseLocator(bookmark.locatorJSON).map { (bookmark.id, $0) }
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
            .filter { $0.bookID == bookID }
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
        let bookmark = Bookmark(
            id: UUID().uuidString,
            bookID: bookID,
            locatorJSON: (try? locator.jsonString()) ?? "{}",
            title: title,
            createdAt: Date()
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

    func remove(_ id: String) {
        bookmarks.removeAll { $0.id == id }
        locatorCache[id] = nil
        save()
    }

    func removeAll(for bookID: String) {
        let removed = bookmarks.filter { $0.bookID == bookID }
        bookmarks.removeAll { $0.bookID == bookID }
        for bookmark in removed { locatorCache[bookmark.id] = nil }
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
