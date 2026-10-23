import Foundation
import ReadiumShared

/// Best-effort JSON persistence shared by the local stores.
///
/// Uses default `JSONEncoder` / `JSONDecoder` settings and atomic writes, so
/// the on-disk format is exactly what each store wrote before this helper
/// existed. Failures are silent by design: a missing or corrupt file loads as
/// nil (the store keeps its empty default) and a failed write keeps the
/// previous file.
enum JSONFileStorage {
    static func load<Value: Decodable>(_ type: Value.Type, from url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<Value: Encodable>(_ value: Value, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Parses the Readium Locator JSON stored on books, highlights and bookmarks.
enum LocatorJSON {
    /// The Locator, or nil when the string is not valid Locator JSON.
    static func parse(_ json: String) -> Locator? {
        guard let value = try? JSONValue(jsonString: json) else { return nil }
        return try? Locator(json: value, warnings: nil)
    }
}

/// A per-book annotation record that can carry a sync deletion tombstone.
protocol LocalAnnotationRecord: Identifiable, Equatable where ID == String {
    var bookID: String { get }
    var deletedAt: Date? { get }
}

extension Highlight: LocalAnnotationRecord {}
extension Bookmark: LocalAnnotationRecord {}

extension Array where Element: LocalAnnotationRecord {
    /// Drops tombstones past the sync retention window so soft-deleted records
    /// cannot accumulate forever in a local catalog.
    func prunedOfExpiredTombstones(now: Date = Date()) -> [Element] {
        filter { !AnnotationSyncMerge.isExpiredTombstone(deletedAt: $0.deletedAt, now: now) }
    }

    /// The records after replacing one book's records with `incoming` and
    /// pruning expired tombstones, or nil when that would change nothing.
    ///
    /// The sync engine applies every book's merged records on each reconcile
    /// pass, so the unchanged case is the common one. It is decided by
    /// comparing only that book's records (order-insensitively: merged records
    /// arrive sorted by id, local ones in insertion order) plus one linear scan
    /// of the other books for expired tombstones. That scan keeps the pruning
    /// of other books' tombstones that a full replace performs: when one is
    /// found, the full replace runs. An expired tombstone of this book is in
    /// the local records but not in the pruned `incoming`, so it also forces
    /// the replace.
    func replacingRecords(of bookID: String, with incoming: [Element], now: Date = Date()) -> [Element]? {
        let incoming = incoming.prunedOfExpiredTombstones(now: now)
        var current: [Element] = []
        var othersHaveExpiredTombstone = false
        for record in self {
            if record.bookID == bookID {
                current.append(record)
            } else if !othersHaveExpiredTombstone,
                      AnnotationSyncMerge.isExpiredTombstone(deletedAt: record.deletedAt, now: now) {
                othersHaveExpiredTombstone = true
            }
        }
        if !othersHaveExpiredTombstone, current.hasSameRecords(as: incoming) {
            return nil
        }
        var replaced = filter { $0.bookID != bookID }
        replaced.append(contentsOf: incoming)
        return replaced.prunedOfExpiredTombstones(now: now)
    }
}

extension Array where Element: Identifiable & Equatable, Element.ID == String {
    /// True when both arrays hold the same records, ignoring order. Duplicate
    /// ids can make this report a difference that is not there, which only
    /// costs the write a store would have done anyway.
    func hasSameRecords(as other: [Element]) -> Bool {
        count == other.count
            && sorted { $0.id < $1.id } == other.sorted { $0.id < $1.id }
    }
}
