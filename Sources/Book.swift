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
