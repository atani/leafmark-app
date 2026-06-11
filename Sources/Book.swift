import Foundation

/// A book in the user's library, persisted as JSON in the catalog file.
struct Book: Identifiable, Codable, Equatable {
    let id: String
    var fileName: String
    var title: String
    var author: String?
    var addedAt: Date
    var lastOpenedAt: Date?
    /// Total reading progression in 0...1, if known.
    var progression: Double?
    /// Last reading position, as a Readium Locator JSON string.
    var locatorJSON: String?
}
