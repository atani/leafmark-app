import Foundation
import UIKit
import ReadiumShared

/// Owns the on-disk library: EPUB files, cover thumbnails and the catalog.
///
/// Layout:
/// - Documents/Books/<uuid>.epub   — imported books (backed up by iCloud)
/// - Library/Application Support/Covers/<uuid>.png
/// - Library/Application Support/library.json
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published var importError: String?

    private let fileManager = FileManager.default

    private var documentsDir: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var booksDir: URL {
        documentsDir.appendingPathComponent("Books", isDirectory: true)
    }

    private var supportDir: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var coversDir: URL {
        supportDir.appendingPathComponent("Covers", isDirectory: true)
    }

    private var catalogURL: URL {
        supportDir.appendingPathComponent("library.json")
    }

    init() {
        try? fileManager.createDirectory(at: booksDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)
        loadCatalog()
    }

    // MARK: - Catalog persistence

    private func loadCatalog() {
        guard let data = try? Data(contentsOf: catalogURL),
              let decoded = try? JSONDecoder().decode([Book].self, from: data)
        else { return }
        books = decoded.sorted(by: Self.librarySort)
    }

    private func saveCatalog() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? data.write(to: catalogURL, options: .atomic)
    }

    private static func librarySort(_ a: Book, _ b: Book) -> Bool {
        switch (a.lastOpenedAt, b.lastOpenedAt) {
        case let (la?, lb?): return la > lb
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return a.addedAt > b.addedAt
        }
    }

    // MARK: - Files

    func fileURL(for book: Book) -> URL {
        booksDir.appendingPathComponent(book.fileName)
    }

    func coverURL(for book: Book) -> URL {
        coversDir.appendingPathComponent("\(book.id).png")
    }

    func coverImage(for book: Book) -> UIImage? {
        UIImage(contentsOfFile: coverURL(for: book).path)
    }

    // MARK: - Import

    /// Imports an EPUB picked from the Files app or handed over via "Open in".
    func importEPUB(from url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let id = UUID().uuidString
        let destination = booksDir.appendingPathComponent("\(id).epub")
        do {
            try fileManager.copyItem(at: url, to: destination)
        } catch {
            importError = "Could not copy the file: \(error.localizedDescription)"
            return
        }

        await finishImport(id: id, destination: destination, originalName: url.lastPathComponent)
    }

    /// Imports loose EPUB files dropped into Documents (file sharing / "Save to Files").
    func scanInbox() async {
        let candidates = (try? fileManager.contentsOfDirectory(
            at: documentsDir,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in candidates where url.pathExtension.lowercased() == "epub" {
            let id = UUID().uuidString
            let destination = booksDir.appendingPathComponent("\(id).epub")
            do {
                try fileManager.moveItem(at: url, to: destination)
            } catch {
                continue
            }
            await finishImport(id: id, destination: destination, originalName: url.lastPathComponent)
        }
    }

    private func finishImport(id: String, destination: URL, originalName: String) async {
        var title = (originalName as NSString).deletingPathExtension
        var author: String?

        // Best effort: parse metadata and cover with Readium. The book is
        // still added when parsing fails, so the user can see and retry it.
        if let publication = try? await ReadiumContext.openPublication(at: destination) {
            if let metaTitle = publication.metadata.title, !metaTitle.isEmpty {
                title = metaTitle
            }
            author = publication.metadata.authors.map(\.name).joined(separator: ", ")
            if author?.isEmpty == true { author = nil }

            if let cover = try? await publication.coverFitting(
                maxSize: CGSize(width: 300, height: 450)
            ).get(), let data = cover.pngData() {
                try? data.write(to: coversDir.appendingPathComponent("\(id).png"))
            }
        }

        let book = Book(
            id: id,
            fileName: "\(id).epub",
            title: title,
            author: author,
            addedAt: Date()
        )
        books.append(book)
        books.sort(by: Self.librarySort)
        saveCatalog()
    }

    // MARK: - Mutations

    func delete(_ book: Book) {
        try? fileManager.removeItem(at: fileURL(for: book))
        try? fileManager.removeItem(at: coverURL(for: book))
        books.removeAll { $0.id == book.id }
        saveCatalog()
    }

    func markOpened(_ book: Book) {
        update(book.id) { $0.lastOpenedAt = Date() }
    }

    func saveProgress(bookID: String, locatorJSON: String?, progression: Double?) {
        update(bookID) {
            $0.locatorJSON = locatorJSON
            if let progression { $0.progression = progression }
        }
    }

    private func update(_ id: String, _ mutate: (inout Book) -> Void) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        mutate(&books[index])
        books.sort(by: Self.librarySort)
        saveCatalog()
    }
}
