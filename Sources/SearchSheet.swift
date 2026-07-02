import SwiftUI
import ReadiumShared

/// Full-text search inside the open book.
struct SearchSheet: View {
    let publication: Publication
    let onSelect: (Locator) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Locator] = []
    @State private var searching = false
    @State private var searched = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if searching {
                    ProgressView("Searching…")
                } else if searched && results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "Search This Book",
                        systemImage: "magnifyingglass",
                        description: Text("Find every occurrence of a word or phrase.")
                    )
                } else {
                    List(Array(results.enumerated()), id: \.offset) { _, locator in
                        Button {
                            onSelect(locator)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                resultText(locator)
                                    .font(.subheadline)
                                    .lineLimit(3)
                                if let title = locator.title {
                                    Text(title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search in book"
            )
            .onSubmit(of: .search) { search() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { searchTask?.cancel() }
    }

    private func resultText(_ locator: Locator) -> Text {
        let before = locator.text.before ?? ""
        let highlight = locator.text.highlight ?? ""
        let after = locator.text.after ?? ""
        return Text(before)
            + Text(highlight).bold().foregroundStyle(Color.accentColor)
            + Text(after)
    }

    private func search() {
        searchTask?.cancel()
        results = []
        searched = false
        // Also reset the spinner: submitting an empty query while a previous
        // search is still running would otherwise leave it stuck on screen.
        searching = false
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        searching = true
        searchTask = Task {
            var found: [Locator] = []
            if let iterator = try? await publication.search(query: trimmed).get() {
                // Hard cap to keep the list and memory bounded on huge books.
                while found.count < 500, !Task.isCancelled {
                    guard case .success(let page) = await iterator.next(),
                          let collection = page
                    else { break }
                    found.append(contentsOf: collection.locators)
                }
            }
            // A cancelled (superseded) task must not touch the state a newer
            // search now owns — no defer, so stale tasks exit silently.
            guard !Task.isCancelled else { return }
            results = found
            searching = false
            searched = true
        }
    }
}
