import Foundation
import ReadiumShared

/// Persists bookmarks for all books as a single JSON file, mirroring
/// HighlightStore (ADR-0004).
@MainActor
final class BookmarkStore: ObservableObject {
    @Published private(set) var bookmarks: [Bookmark] = []

    private let storeURL: URL

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
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        try? data.write(to: storeURL, options: .atomic)
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
        guard let value = try? JSONValue(jsonString: bookmark.locatorJSON) else { return nil }
        return try? Locator(json: value, warnings: nil)
    }

    /// The bookmark at the given position, if any (same resource and
    /// near-identical progression).
    func bookmark(for bookID: String, at locator: Locator) -> Bookmark? {
        bookmarks.first { bookmark in
            guard bookmark.bookID == bookID,
                  let stored = self.locator(of: bookmark),
                  stored.href.isEquivalentTo(locator.href)
            else { return false }
            let a = stored.locations.totalProgression
            let b = locator.locations.totalProgression
            // Same resource with no progression info counts as the same page.
            guard let a, let b else { return a == nil && b == nil }
            return abs(a - b) < Self.sameProgressionEpsilon
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
        save()
    }

    func removeAll(for bookID: String) {
        bookmarks.removeAll { $0.bookID == bookID }
        save()
    }

    func progression(of bookmark: Bookmark) -> Double? {
        locator(of: bookmark)?.locations.totalProgression
    }
}
