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
    case recentlyAdded
    case title
    case author

    var id: Self { self }

    var title: String {
        switch self {
        case .recentlyAdded: "Recently Added"
        case .title: "Title"
        case .author: "Author"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyAdded: "calendar.badge.plus"
        case .title: "textformat"
        case .author: "person"
        }
    }

    func sorted(_ books: [Book]) -> [Book] {
        books.sorted { lhs, rhs in
            switch self {
            case .recentlyAdded:
                if lhs.addedAt != rhs.addedAt { return lhs.addedAt > rhs.addedAt }
                return titleComesBefore(lhs, rhs)

            case .title:
                return titleComesBefore(lhs, rhs)

            case .author:
                let lhsAuthor = normalizedAuthor(lhs.author)
                let rhsAuthor = normalizedAuthor(rhs.author)
                switch (lhsAuthor, rhsAuthor) {
                case let (lhsAuthor?, rhsAuthor?):
                    let comparison = lhsAuthor.localizedCaseInsensitiveCompare(rhsAuthor)
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
        }
    }

    private func titleComesBefore(_ lhs: Book, _ rhs: Book) -> Bool {
        let comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if comparison != .orderedSame { return comparison == .orderedAscending }
        if lhs.addedAt != rhs.addedAt { return lhs.addedAt > rhs.addedAt }
        return lhs.id < rhs.id
    }

    private func normalizedAuthor(_ author: String?) -> String? {
        guard let author = author?.trimmingCharacters(in: .whitespacesAndNewlines),
              !author.isEmpty
        else { return nil }
        return author
    }
}
