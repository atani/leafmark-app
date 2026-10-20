import Foundation

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

/// A local record that can carry a sync deletion tombstone.
protocol TombstoneCarrying {
    var deletedAt: Date? { get }
}

extension Highlight: TombstoneCarrying {}
extension Bookmark: TombstoneCarrying {}

extension Array where Element: TombstoneCarrying {
    /// Drops tombstones past the sync retention window so soft-deleted records
    /// cannot accumulate forever in a local catalog.
    func prunedOfExpiredTombstones(now: Date = Date()) -> [Element] {
        filter { !AnnotationSyncMerge.isExpiredTombstone(deletedAt: $0.deletedAt, now: now) }
    }

}

extension Array where Element: Identifiable & Equatable, Element.ID == String {
    /// True when both arrays hold the same records, ignoring order.
    ///
    /// The sync engine re-applies every book's merged records on each
    /// reconcile pass, and the merged records arrive sorted by id while the
    /// local array is in insertion order. Comparing order-insensitively lets a
    /// store skip the publish and the file write when nothing changed. Duplicate
    /// ids can make this report a difference that is not there, which only
    /// costs the write it would have done anyway.
    func hasSameRecords(as other: [Element]) -> Bool {
        count == other.count
            && sorted { $0.id < $1.id } == other.sorted { $0.id < $1.id }
    }
}
