import Foundation

/// Schema version of the on-disk library catalog document. Additive fields stay
/// backward-compatible via optional Codable properties (ADR-0002 / ADR-0007);
/// bump only for a non-additive change.
let librarySyncSchemaVersion = 1

/// A synced description of one book the user has imported, keyed by `contentKey`
/// (SHA-256 of the EPUB bytes) so it lines up across devices where the
/// per-import `Book.id` differs. The EPUB file itself is intentionally NOT
/// synced (ADR-0007); only this metadata travels through iCloud so a fresh
/// install can tell the user which books to re-import.
///
/// A non-nil `deletedAt` is a tombstone marking a deliberate local deletion, so
/// a fresh install stops suggesting a book the user intentionally removed. The
/// tombstone never deletes anything on another device — files are local-canonical
/// — it only removes the book from the restore-hint list.
struct CatalogRecord: SyncRecord, Codable, Identifiable, Sendable {
    /// The book's `contentKey`; also the cross-device merge identity.
    let id: String
    var title: String
    var author: String?
    var updatedAt: Date
    var deletedAt: Date?
}

/// The synced library catalog: one JSON document in the app's iCloud Documents
/// container at `Documents/Library/catalog.json`. Files are not synced (only
/// this metadata is), so the document lists what books exist, not their bytes.
struct LibraryCatalog: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var books: [CatalogRecord]

    init(schemaVersion: Int = librarySyncSchemaVersion, books: [CatalogRecord] = []) {
        self.schemaVersion = schemaVersion
        self.books = books
    }
}

/// A book present in the synced catalog but absent from this device's library —
/// a restore hint surfaced in `LibraryView` under "On your other devices".
struct MissingBook: Identifiable, Equatable, Sendable {
    var contentKey: String
    var title: String
    var author: String?

    var id: String { contentKey }
}
