import Foundation

/// A book in the user's library, persisted as JSON in the catalog file.
struct Book: Identifiable, Codable, Equatable {
    let id: String
    /// SHA-256 of the EPUB bytes. Unlike `id`, this is stable across imports.
    var contentKey: String? = nil
    var fileName: String
    var title: String
    var author: String?
    var addedAt: Date
    var lastOpenedAt: Date?
    /// Total reading progression in 0...1, if known.
    var progression: Double?
    /// Last reading position, as a Readium Locator JSON string.
    var locatorJSON: String?
    /// Last local or remote change to the reading position.
    var positionUpdatedAt: Date? = nil
}

/// User-selected ordering for the library grid.
///
/// Sorting is deliberately a presentation concern. `LibraryStore.books` keeps
/// its activity-based order because the sync engine relies on that order when
/// resolving duplicate imports.
enum LibrarySortOrder: String, CaseIterable, Identifiable {
    /// Same activity-based order `LibraryStore.books` is stored in. Kept as
    /// an explicit, selectable case (and the default) so upgrading users see
    /// no change in their library's order.
    case recentlyOpened
    case recentlyAdded
    case title
    case author

    var id: Self { self }

    var label: String {
        switch self {
        case .recentlyOpened: "Recently Opened"
        case .recentlyAdded: "Recently Added"
        case .title: "Title"
        case .author: "Author"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyOpened: "clock.arrow.circlepath"
        case .recentlyAdded: "calendar.badge.plus"
        case .title: "textformat"
        case .author: "person"
        }
    }

    func sorted(_ books: [Book]) -> [Book] {
        books.sorted { lhs, rhs in
            switch self {
            case .recentlyOpened:
                return recentlyOpenedComesBefore(lhs, rhs)

            case .recentlyAdded:
                if lhs.addedAt != rhs.addedAt { return lhs.addedAt > rhs.addedAt }
                return titleComesBefore(lhs, rhs)

            case .title:
                return titleComesBefore(lhs, rhs)

            case .author:
                return authorComesBefore(lhs, rhs)
            }
        }
    }

    /// Mirrors `LibraryStore`'s stored order (most recently opened first,
    /// unopened books by most recently added), with a title tiebreak for a
    /// deterministic grid position.
    private func recentlyOpenedComesBefore(_ lhs: Book, _ rhs: Book) -> Bool {
        switch (lhs.lastOpenedAt, rhs.lastOpenedAt) {
        case let (lhsOpened?, rhsOpened?):
            if lhsOpened != rhsOpened { return lhsOpened > rhsOpened }
            return titleComesBefore(lhs, rhs)
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            if lhs.addedAt != rhs.addedAt { return lhs.addedAt > rhs.addedAt }
            return titleComesBefore(lhs, rhs)
        }
    }

    private func titleComesBefore(_ lhs: Book, _ rhs: Book) -> Bool {
        let comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if comparison != .orderedSame { return comparison == .orderedAscending }
        if lhs.addedAt != rhs.addedAt { return lhs.addedAt > rhs.addedAt }
        return lhs.id < rhs.id
    }

    private func authorComesBefore(_ lhs: Book, _ rhs: Book) -> Bool {
        let lhsAuthorName = normalizedAuthor(lhs.author)
        let rhsAuthorName = normalizedAuthor(rhs.author)
        switch (lhsAuthorName, rhsAuthorName) {
        case let (lhsName?, rhsName?):
            let comparison = lhsName.localizedCaseInsensitiveCompare(rhsName)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return titleComesBefore(lhs, rhs)
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            return titleComesBefore(lhs, rhs)
        }
    }

    private func normalizedAuthor(_ author: String?) -> String? {
        guard let author = author?.trimmingCharacters(in: .whitespacesAndNewlines),
              !author.isEmpty
        else { return nil }
        return author
    }
}
