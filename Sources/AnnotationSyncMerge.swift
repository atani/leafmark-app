import Foundation

/// Pure merge logic for annotation sync documents. Kept free of any file or
/// iCloud dependency so it is exhaustively unit-testable and can be applied to
/// an arbitrary number of `NSFileVersion` conflict copies.
///
/// The merge is a commutative, associative, idempotent union: merging the same
/// documents in any order and any number of times yields the same result. This
/// is what lets `SyncEngine` resolve file-version conflicts by simply merging
/// every version.
enum AnnotationSyncMerge {
    /// Tombstones older than this are pruned during a merge. 90 days is long
    /// enough for an offline second device to observe the deletion first.
    static let tombstoneRetention: TimeInterval = 90 * 24 * 60 * 60

    static func merge(_ documents: [AnnotationSyncDocument], now: Date = Date()) -> AnnotationSyncDocument {
        AnnotationSyncDocument(
            schemaVersion: annotationSyncSchemaVersion,
            highlights: mergeRecords(documents.map(\.highlights), now: now),
            bookmarks: mergeRecords(documents.map(\.bookmarks), now: now),
            position: mergePositions(documents.map(\.position))
        )
    }

    static func merge(
        _ a: AnnotationSyncDocument,
        _ b: AnnotationSyncDocument,
        now: Date = Date()
    ) -> AnnotationSyncDocument {
        merge([a, b], now: now)
    }

    /// Unions record collections by id (last-writer-wins on `updatedAt`), then
    /// drops tombstones past the retention window. A deletion carries the
    /// deletion time as its `updatedAt`, so plain LWW already makes a deletion
    /// win over an older edit and lose to a newer one.
    static func mergeRecords<R: SyncRecord>(_ groups: [[R]], now: Date) -> [R] {
        var winners: [String: R] = [:]
        for group in groups {
            for record in group {
                if let existing = winners[record.id] {
                    winners[record.id] = pick(existing, record)
                } else {
                    winners[record.id] = record
                }
            }
        }
        return winners.values
            .filter { record in
                guard let deletedAt = record.deletedAt else { return true }
                return now.timeIntervalSince(deletedAt) < tombstoneRetention
            }
            // Stable ordering so an unchanged merge re-encodes byte-identically,
            // letting the engine skip redundant writes.
            .sorted { $0.id < $1.id }
    }

    private static func pick<R: SyncRecord>(_ a: R, _ b: R) -> R {
        if a.updatedAt != b.updatedAt {
            return a.updatedAt > b.updatedAt ? a : b
        }
        // Same timestamp: let a deletion win so removals are sticky under a
        // race. Otherwise the two carry identical state; return one
        // deterministically.
        if (a.deletedAt != nil) != (b.deletedAt != nil) {
            return a.deletedAt != nil ? a : b
        }
        return a
    }

    private static func mergePositions(_ positions: [AnnotationSyncPosition?]) -> AnnotationSyncPosition? {
        positions.compactMap { $0 }.max { $0.updatedAt < $1.updatedAt }
    }
}
