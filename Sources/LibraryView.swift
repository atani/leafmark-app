import SwiftUI
import ReadiumShared

/// The home screen: a grid of imported books.
struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var store: StoreManager
    @State private var showImporter = false
    @State private var showStats = false
    @State private var showPaywall = false
    @State private var openedBook: Book?

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if library.books.isEmpty {
                    ContentUnavailableView {
                        Label("Your Library Is Empty", systemImage: "books.vertical")
                    } description: {
                        Text("Import an EPUB to start reading.")
                    } actions: {
                        Button("Import Books") { showImporter = true }
                            .buttonStyle(.borderedProminent)

                        Link(
                            "Browse free books on Standard Ebooks",
                            destination: URL(string: "https://standardebooks.org/ebooks")!
                        )
                        .font(.footnote)
                        .padding(.top, 4)
                    }
                } else {
                    ScrollView {
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
                                        library.delete(book)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if store.isPro {
                            showStats = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("Statistics")
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
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store)
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
            await library.scanInbox()
        }
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
