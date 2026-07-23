import SwiftUI
import ReadiumShared

/// The home screen: a grid of imported books.
struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    @EnvironmentObject private var highlights: HighlightStore
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var bookmarks: BookmarkStore
    @State private var showImporter = false
    @State private var showStats = false
    @State private var openedBook: Book?

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if library.books.isEmpty && library.missingBooks.isEmpty {
                    ContentUnavailableView {
                        Label("Your Library Is Empty", systemImage: "books.vertical")
                    } description: {
                        Text("Import an EPUB to start reading.")
                    } actions: {
                        Button("Import Books") { showImporter = true }
                            .buttonStyle(.borderedProminent)

                        Link(
                            "Browse free books on Public Domain Library",
                            destination: URL(string: "https://publicdomainlibrary.org/en/")!
                        )
                        .font(.footnote)
                        .padding(.top, 4)
                    }
                } else {
                    ScrollView {
                        if !library.books.isEmpty {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(library.books) { book in
                                    Button {
                                        openedBook = book
                                    } label: {
                                        BookCell(book: book, cover: library.coverImage(for: book))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            highlights.removeAll(for: book.id)
                                            stats.removeAll(for: book.id)
                                            bookmarks.removeAll(for: book.id)
                                            library.delete(book)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding()
                        }

                        // Books known from the synced catalog but whose EPUB is
                        // not on this device (files are not synced — ADR-0007).
                        if !library.missingBooks.isEmpty {
                            MissingBooksSection(missingBooks: library.missingBooks) {
                                showImporter = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("Reading Statistics")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import Books")
                }
            }
            .sheet(isPresented: $showStats) {
                StatsView(stats: stats, library: library)
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.epub],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                Task {
                    for url in urls {
                        await library.importEPUB(from: url)
                    }
                }
            }
            .alert(
                "Import Failed",
                isPresented: Binding(
                    get: { library.importError != nil },
                    set: { if !$0 { library.importError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(library.importError ?? "")
            }
            .fullScreenCover(item: $openedBook) { book in
                BookOpener(book: book, library: library)
            }
        }
        .task {
            await library.installBundledSamplesIfNeeded()
            await library.scanInbox()
        }
    }
}

/// A quiet section listing books that live in the synced catalog but are not
/// imported on this device. Tapping a row opens the same file importer as the
/// toolbar "+" so the user can re-add the EPUB and recover its annotations.
private struct MissingBooksSection: View {
    let missingBooks: [MissingBook]
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On your other devices")
                .font(.headline)

            Text("Re-import these EPUB files to restore their highlights and reading positions.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: onSelect) {
                Label("Restore from EPUB Files", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Choose one or more EPUB files to restore these books")

            VStack(alignment: .leading, spacing: 12) {
                ForEach(missingBooks) { book in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.subheadline.weight(.medium))
                        if let author = book.author, !author.isEmpty {
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

private struct BookCell: View {
    let book: Book
    let cover: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Color(.systemGray4), Color(.systemGray6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(book.title)
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            .overlay(alignment: .bottom) {
                if let progression = book.progression, progression > 0 {
                    ProgressView(value: progression)
                        .tint(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }
            }

            Text(book.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)

            if let author = book.author {
                Text(author)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title)\(book.author.map { ", \($0)" } ?? "")")
    }
}

/// Opens the publication asynchronously, then presents the reader.
private struct BookOpener: View {
    let book: Book
    @ObservedObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var publication: Publication?
    @State private var error: String?

    var body: some View {
        Group {
            if let publication {
                ReaderScreen(book: book, publication: publication, library: library)
            } else if let error {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "Could Not Open Book",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView("Opening…")
            }
        }
        .task {
            do {
                publication = try await ReadiumContext.openPublication(
                    at: library.fileURL(for: book)
                )
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
