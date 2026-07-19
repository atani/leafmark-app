import Foundation

/// Pure merge logic for the synced library catalog. Like `AnnotationSyncMerge`
/// it is free of any file or iCloud dependency so it is exhaustively
/// unit-testable and can fold an arbitrary number of `NSFileVersion` conflict
/// copies into one.
///
/// The record union, last-writer-wins on `updatedAt`, tombstone stickiness and
/// 90-day pruning are shared with annotations: this reuses the generic
/// `AnnotationSyncMerge.mergeRecords`, so catalog and annotation records obey
/// exactly the same semantics.
///
/// Revive-on-reimport is a direct consequence of plain LWW: a re-import writes a
/// record whose `updatedAt` is later than the tombstone's `deletedAt`
/// (== the tombstone's `updatedAt`), so the live record wins and clears the
/// tombstone. `testTombstoneRevivesOnReimport` pins this behaviour.
enum CatalogSyncMerge {
    static func merge(_ catalogs: [LibraryCatalog], now: Date = Date()) -> LibraryCatalog {
        LibraryCatalog(
            schemaVersion: librarySyncSchemaVersion,
            books: AnnotationSyncMerge.mergeRecords(catalogs.map(\.books), now: now)
        )
    }

    static func merge(
        _ a: LibraryCatalog,
        _ b: LibraryCatalog,
        now: Date = Date()
    ) -> LibraryCatalog {
        merge([a, b], now: now)
    }
}
