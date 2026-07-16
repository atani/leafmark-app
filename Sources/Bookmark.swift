import Foundation

/// A saved reading position the user can jump back to. Unlike a highlight,
/// a bookmark marks a whole page rather than a text range.
struct Bookmark: Identifiable, Codable, Equatable {
    let id: String
    let bookID: String
    /// The bookmarked position, as a Readium Locator JSON string.
    var locatorJSON: String
    /// Chapter title (or a short label) captured when the bookmark was made,
    /// so the list can be rendered without re-opening the publication.
    var title: String?
    var createdAt: Date
    /// Optional for decoding catalogs written before annotation sync existed.
    var updatedAt: Date? = nil
    /// A retained deletion marker used to propagate removals to other devices.
    var deletedAt: Date? = nil

    var effectiveUpdatedAt: Date { updatedAt ?? createdAt }
}
