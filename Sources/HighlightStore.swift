import Foundation
import ReadiumShared

/// Persists highlights for all books as a single JSON file.
/// See ADR-0004.
@MainActor
final class HighlightStore: ObservableObject {
    @Published private(set) var highlights: [Highlight] = []

    private var storeURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("highlights.json")
    }

    init() {
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Highlight].self, from: data)
        else { return }
        highlights = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(highlights) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    func highlights(for bookID: String) -> [Highlight] {
        highlights
            .filter { $0.bookID == bookID }
            .sorted { lhs, rhs in
                let lp = progression(of: lhs) ?? 0
                let rp = progression(of: rhs) ?? 0
                return lp == rp ? lhs.createdAt < rhs.createdAt : lp < rp
            }
    }

    @discardableResult
    func add(
        bookID: String,
        locator: Locator,
        color: HighlightColor,
        note: String? = nil
    ) -> Highlight {
        let highlight = Highlight(
            id: UUID().uuidString,
            bookID: bookID,
            locatorJSON: (try? locator.jsonString()) ?? "{}",
            colorRaw: color.rawValue,
            note: note,
            createdAt: Date(),
            text: locator.text.highlight ?? ""
        )
        highlights.append(highlight)
        save()
        return highlight
    }

    func update(_ id: String, _ mutate: (inout Highlight) -> Void) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        mutate(&highlights[index])
        save()
    }

    func remove(_ id: String) {
        highlights.removeAll { $0.id == id }
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
}
