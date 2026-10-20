import Foundation
import ReadiumShared

/// Persists highlights for all books as a single JSON file.
/// See ADR-0004.
@MainActor
final class HighlightStore: ObservableObject {
    @Published private(set) var highlights: [Highlight] = []

    private let storeURL: URL

    /// Parsed Locators keyed by highlight id, with the JSON each was parsed
    /// from. The reading-order sort, the reader's decorations and the export
    /// ask for locators on every call (the sort on every comparison), so each
    /// record's JSON is parsed once here instead. Keeping the JSON lets a
    /// caller holding a different copy of a record still get its own locator.
    private var locatorCache: [String: CachedLocator] = [:]

    private struct CachedLocator {
        let json: String
        let locator: Locator?
    }

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("highlights.json")
        load()
    }

    private func load() {
        guard let decoded = JSONFileStorage.load([Highlight].self, from: storeURL) else { return }
        highlights = decoded.prunedOfExpiredTombstones()
        rebuildCache()
    }

    private func save() {
        JSONFileStorage.save(highlights, to: storeURL)
    }

    /// Re-syncs the cache with `highlights`, reusing entries whose JSON is
    /// unchanged so only new or edited records are parsed.
    private func rebuildCache() {
        var cache: [String: CachedLocator] = [:]
        cache.reserveCapacity(highlights.count)
        for highlight in highlights {
            cache[highlight.id] = cachedLocator(for: highlight)
        }
        locatorCache = cache
    }

    private func cachedLocator(for highlight: Highlight) -> CachedLocator {
        if let cached = locatorCache[highlight.id], cached.json == highlight.locatorJSON {
            return cached
        }
        return CachedLocator(json: highlight.locatorJSON, locator: Self.parseLocator(highlight.locatorJSON))
    }

    private static func parseLocator(_ json: String) -> Locator? {
        guard let value = try? JSONValue(jsonString: json) else { return nil }
        return try? Locator(json: value, warnings: nil)
    }

    /// Active highlights across every book. Used for the usage milestone that
    /// offers the App Store review prompt.
    var activeCount: Int {
        highlights.filter { $0.deletedAt == nil }.count
    }

    /// Active highlight count per book ID, without sorting or locator parsing.
    func activeHighlightCounts() -> [String: Int] {
        highlights.reduce(into: [:]) { counts, highlight in
            if highlight.deletedAt == nil { counts[highlight.bookID, default: 0] += 1 }
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
        locatorCache[highlight.id] = CachedLocator(json: highlight.locatorJSON, locator: Self.parseLocator(highlight.locatorJSON))
        save()
        return highlight
    }

    func update(_ id: String, _ mutate: (inout Highlight) -> Void) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        mutate(&highlights[index])
        highlights[index].updatedAt = Date()
        locatorCache[id] = cachedLocator(for: highlights[index])
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
        rebuildCache()
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
    ///
    /// When the result holds the same records as now, nothing is published or
    /// written (see `Array.hasSameRecords(as:)`).
    func applyMerged(_ records: [SyncedHighlight], bookID: String) {
        var merged = highlights.filter { $0.bookID != bookID }
        merged.append(contentsOf: records.map { $0.highlight(bookID: bookID) })
        merged = merged.prunedOfExpiredTombstones()
        guard !merged.hasSameRecords(as: highlights) else { return }
        highlights = merged
        rebuildCache()
        save()
    }

    func locator(of highlight: Highlight) -> Locator? {
        cachedLocator(for: highlight).locator
    }

    private func progression(of highlight: Highlight) -> Double? {
        locator(of: highlight)?.locations.totalProgression
    }

    // MARK: - Export

    /// Renders all highlights of a book as Markdown, ready for Obsidian/Notion.
    ///
    /// The file starts with YAML front matter so Obsidian picks up the title,
    /// author and export date as note properties. `exportedAt` and `timeZone`
    /// are injectable to keep the `exported` date deterministic in tests.
    func exportMarkdown(
        for book: Book,
        layout: MarkdownExportLayout = .readingOrder,
        exportedAt: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let items = highlights(for: book.id)
        var lines = Self.frontMatter(for: book, exportedAt: exportedAt, timeZone: timeZone)
        lines.append("")
        lines.append("# \(Self.singleLine(book.title))")
        if let author = book.author {
            lines.append("by \(Self.singleLine(author))")
        }
        lines.append("")

        switch layout {
        case .readingOrder:
            for item in items {
                lines.append(contentsOf: markdownLines(for: item))
            }
        case .byColor:
            for color in HighlightColor.allCases {
                let group = items.filter { $0.color == color }
                guard !group.isEmpty else { continue }
                lines.append("## \(color.label)")
                lines.append("")
                for item in group {
                    lines.append(contentsOf: markdownLines(for: item))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// A line break inside a title or author would end the heading or `by`
    /// line early and turn the rest into body text.
    private static func singleLine(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n|\r|\n", with: " ", options: .regularExpression)
    }

    private func markdownLines(for item: Highlight) -> [String] {
        var lines = ["> \(item.text.replacingOccurrences(of: "\n", with: "\n> "))", ""]
        if let note = item.note, !note.isEmpty {
            lines.append(note)
            lines.append("")
        }
        if let progression = progression(of: item) {
            lines.append("— at \(Int((progression * 100).rounded()))%")
            lines.append("")
        }
        return lines
    }

    /// Reused across exports ("Export All" builds one front matter per book).
    /// Main-actor isolated with the store, so setting `timeZone` per call
    /// cannot race.
    private static let exportDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    static func frontMatter(for book: Book, exportedAt: Date, timeZone: TimeZone) -> [String] {
        let formatter = exportDateFormatter
        formatter.timeZone = timeZone

        var lines = ["---", "title: \(yamlQuoted(book.title))"]
        if let author = book.author, !author.isEmpty {
            lines.append("author: \(yamlQuoted(author))")
        }
        lines.append("source: Leafmark")
        lines.append("exported: \(formatter.string(from: exportedAt))")
        lines.append("---")
        return lines
    }

    /// Renders a YAML double-quoted scalar. Always quoting avoids YAML's
    /// implicit typing (`yes`, `1984`, `null`) and indicator characters such
    /// as `:` and `#` in book titles.
    static func yamlQuoted(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                // C0/C1 control characters are not printable in YAML.
                if scalar.value < 0x20 || (0x7F...0x9F).contains(scalar.value) {
                    result += String(format: "\\u%04X", scalar.value)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result + "\""
    }

    func exportFile(for book: Book, layout: MarkdownExportLayout = .readingOrder) -> HighlightExport {
        HighlightExport(
            text: exportMarkdown(for: book, layout: layout),
            fileName: Self.exportFileName(for: book)
        )
    }

    /// One Markdown file per book that has at least one active highlight, in
    /// the given order. File names are made unique so books sharing a title
    /// and author do not overwrite each other in the share sheet.
    func exportFiles(for books: [Book], layout: MarkdownExportLayout = .readingOrder) -> [HighlightExport] {
        let counts = activeHighlightCounts()
        var usedNames = Set<String>()
        return books
            .filter { counts[$0.id, default: 0] > 0 }
            .map { book in
                let export = exportFile(for: book, layout: layout)
                let name = Self.uniqueFileName(export.fileName, avoiding: usedNames)
                usedNames.insert(name.lowercased())
                return HighlightExport(text: export.text, fileName: name)
            }
    }

    /// Appends " (2)", " (3)" … before the extension until the name is free.
    /// Comparison is case-insensitive because the iOS file system is.
    static func uniqueFileName(_ fileName: String, avoiding usedNames: Set<String>) -> String {
        guard usedNames.contains(fileName.lowercased()) else { return fileName }
        let url = URL(fileURLWithPath: fileName)
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent
        var counter = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem) (\(counter))" : "\(stem) (\(counter)).\(ext)"
            if !usedNames.contains(candidate.lowercased()) { return candidate }
            counter += 1
        }
    }

    static func exportFileName(for book: Book) -> String {
        let baseName = [book.title, book.author]
            .compactMap(Self.sanitizedFileNamePart)
            .joined(separator: " - ")

        return "\(baseName.isEmpty ? "Highlights" : baseName).\(HighlightExport.fileExtension)"
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
