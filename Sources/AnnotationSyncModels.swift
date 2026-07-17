import Foundation

/// Schema version of the on-disk annotation sync document. Bump only for a
/// non-additive change; additive fields stay backward-compatible via optional
/// Codable properties, mirroring the catalog's migration strategy (ADR-0002).
let annotationSyncSchemaVersion = 1

/// A book's synced annotations, stored as one JSON file per book in the app's
/// iCloud Documents container (`Documents/Annotations/<contentKey>.json`).
///
/// Records are keyed by `contentKey` (SHA-256 of the EPUB bytes) rather than
/// `Book.id`, so they line up across devices where the per-import UUID differs.
/// The device-local `bookID` is therefore intentionally absent from the synced
/// records: it is re-attached from the local library when a document is merged
/// back in.
struct AnnotationSyncDocument: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var highlights: [SyncedHighlight]
    var bookmarks: [SyncedBookmark]
    var position: AnnotationSyncPosition?

    init(
        schemaVersion: Int = annotationSyncSchemaVersion,
        highlights: [SyncedHighlight] = [],
        bookmarks: [SyncedBookmark] = [],
        position: AnnotationSyncPosition? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.highlights = highlights
        self.bookmarks = bookmarks
        self.position = position
    }
}

/// A record that can be merged last-writer-wins across devices. A record with a
/// non-nil `deletedAt` is a tombstone that propagates a deletion.
protocol SyncRecord: Equatable, Sendable {
    var id: String { get }
    var updatedAt: Date { get }
    var deletedAt: Date? { get }
}

struct SyncedHighlight: SyncRecord, Codable, Identifiable {
    let id: String
    var locatorJSON: String
    var colorRaw: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var text: String
}

struct SyncedBookmark: SyncRecord, Codable, Identifiable {
    let id: String
    var locatorJSON: String
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

/// The reading position, a single record merged LWW by `updatedAt`.
struct AnnotationSyncPosition: Codable, Equatable, Sendable {
    var locatorJSON: String
    var progression: Double?
    var updatedAt: Date
}

// MARK: - Conversions between store models and synced records

extension SyncedHighlight {
    init(_ highlight: Highlight) {
        self.init(
            id: highlight.id,
            locatorJSON: highlight.locatorJSON,
            colorRaw: highlight.colorRaw,
            note: highlight.note,
            createdAt: highlight.createdAt,
            updatedAt: highlight.effectiveUpdatedAt,
            deletedAt: highlight.deletedAt,
            text: highlight.text
        )
    }

    /// Re-attaches the device-local `bookID` when applying a merged document.
    func highlight(bookID: String) -> Highlight {
        Highlight(
            id: id,
            bookID: bookID,
            locatorJSON: locatorJSON,
            colorRaw: colorRaw,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            text: text
        )
    }
}

extension SyncedBookmark {
    init(_ bookmark: Bookmark) {
        self.init(
            id: bookmark.id,
            locatorJSON: bookmark.locatorJSON,
            title: bookmark.title,
            createdAt: bookmark.createdAt,
            updatedAt: bookmark.effectiveUpdatedAt,
            deletedAt: bookmark.deletedAt
        )
    }

    func bookmark(bookID: String) -> Bookmark {
        Bookmark(
            id: id,
            bookID: bookID,
            locatorJSON: locatorJSON,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
