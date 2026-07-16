import Foundation
import ReadiumShared

/// Persists highlights for all books as a single JSON file.
/// See ADR-0004.
@MainActor
final class HighlightStore: ObservableObject {
    @Published private(set) var highlights: [Highlight] = []

    private let storeURL: URL

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("highlights.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Highlight].self, from: data)
        else { return }
        highlights = Self.pruningExpiredTombstones(decoded)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(highlights) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    /// Drops tombstones past the sync retention window so soft-deleted records
    /// cannot accumulate forever in the local catalog.
    private static func pruningExpiredTombstones(_ records: [Highlight], now: Date = Date()) -> [Highlight] {
        records.filter { record in
            guard let deletedAt = record.deletedAt else { return true }
            return now.timeIntervalSince(deletedAt) < AnnotationSyncMerge.tombstoneRetention
        }
    }

    func highlights(for bookID: String) -> [Highlight] {
        highlights
            .filter { $0.bookID == bookID && $0.deletedAt == nil }
            .sorted { lhs, rhs in
                let lp = progression(of: lhs) ?? 0
                let rp = progression(of: rhs) ?? 0
                return lp == rp ? lhs.createdAt < rhs.createdAt : lp < rp
            }
    }

    /// The active (non-deleted) highlight with the given id, used when the
    /// reader activates a highlight decoration.
    func highlight(withID id: String) -> Highlight? {
        highlights.first { $0.id == id && $0.deletedAt == nil }
    }

    @discardableResult
    func add(
        bookID: String,
        locator: Locator,
        color: HighlightColor,
        note: String? = nil
    ) -> Highlight {
        let now = Date()
        let highlight = Highlight(
            id: UUID().uuidString,
            bookID: bookID,
            locatorJSON: (try? locator.jsonString()) ?? "{}",
            colorRaw: color.rawValue,
            note: note,
            createdAt: now,
            updatedAt: now,
            text: locator.text.highlight ?? ""
        )
        highlights.append(highlight)
        save()
        return highlight
    }

    func update(_ id: String, _ mutate: (inout Highlight) -> Void) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        mutate(&highlights[index])
        highlights[index].updatedAt = Date()
        save()
    }

    /// Soft-deletes a highlight, leaving a tombstone so the deletion syncs to
    /// other devices. The tombstone is pruned after the retention window.
    func remove(_ id: String) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        highlights[index].deletedAt = now
        highlights[index].updatedAt = now
        save()
    }

    /// Hard-deletes every highlight of a book. Used when the book itself is
    /// removed from the library, so it must NOT leave tombstones: another
    /// device that still holds the book keeps its annotations.
    func removeAll(for bookID: String) {
        highlights.removeAll { $0.bookID == bookID }
        save()
    }

    // MARK: - Sync

    /// All records for a book including tombstones, as sync documents carry
    /// deletions.
    func syncedRecords(for bookID: String) -> [SyncedHighlight] {
        highlights.filter { $0.bookID == bookID }.map(SyncedHighlight.init)
    }

    /// Replaces a book's records with a merged set from the sync layer. Callers
    /// guard against the resulting publisher change re-triggering a push.
    func applyMerged(_ records: [SyncedHighlight], bookID: String) {
        highlights.removeAll { $0.bookID == bookID }
        highlights.append(contentsOf: records.map { $0.highlight(bookID: bookID) })
        highlights = Self.pruningExpiredTombstones(highlights)
        save()
    }

    func locator(of highlight: Highlight) -> Locator? {
        guard let value = try? JSONValue(jsonString: highlight.locatorJSON) else { return nil }
        return try? Locator(json: value, warnings: nil)
    }

    private func progression(of highlight: Highlight) -> Double? {
        locator(of: highlight)?.locations.totalProgression
    }

    // MARK: - Export

    /// Renders all highlights of a book as Markdown, ready for Obsidian/Notion.
    func exportMarkdown(for book: Book) -> String {
        let items = highlights(for: book.id)
        var lines = ["# \(book.title)"]
        if let author = book.author {
            lines.append("by \(author)")
        }
        lines.append("")
        for item in items {
            lines.append("> \(item.text.replacingOccurrences(of: "\n", with: "\n> "))")
            lines.append("")
            if let note = item.note, !note.isEmpty {
                lines.append(note)
                lines.append("")
            }
            if let progression = progression(of: item) {
                lines.append("— at \(Int((progression * 100).rounded()))%")
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    func exportFile(for book: Book) -> HighlightExport {
        HighlightExport(
            text: exportMarkdown(for: book),
            fileName: Self.exportFileName(for: book)
        )
    }

    static func exportFileName(for book: Book) -> String {
        let baseName = [book.title, book.author]
            .compactMap(Self.sanitizedFileNamePart)
            .joined(separator: " - ")

        return "\(baseName.isEmpty ? "Highlights" : baseName).txt"
    }

    private static func sanitizedFileNamePart(_ value: String?) -> String? {
        guard let value else { return nil }

        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)

        let cleanedScalars = value.unicodeScalars.map { scalar in
            invalidCharacters.contains(scalar) ? " " : String(scalar)
        }
        let cleaned = cleanedScalars.joined()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))

        return cleaned.isEmpty ? nil : cleaned
    }
}
