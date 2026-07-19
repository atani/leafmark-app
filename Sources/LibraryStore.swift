import Foundation
import CryptoKit
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

    /// Books present in the synced catalog but not on this device — restore
    /// hints surfaced in `LibraryView` under "On your other devices"
    /// (ADR-0007 addendum). Empty when nothing is missing.
    @Published private(set) var missingBooks: [MissingBook] = []

    /// In-memory copy of the sidecar sync catalog (see `syncedCatalogURL`):
    /// the last merged view of remote-only records and deletion tombstones.
    private var syncedCatalog = LibraryCatalog()

    private let fileManager = FileManager.default

    /// Installed in reverse order so the first item below appears first in
    /// the library, whose default sort is newest-first.
    private static let bundledSamples: [(resourceName: String, fileName: String)] = [
        ("sample-frankenstein", "sample-frankenstein.epub"),
        ("sample-meditations", "sample-meditations.epub"),
        ("sample-benjamin-franklin", "sample-benjamin-franklin.epub"),
    ]

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

    /// Sidecar holding the last merged sync catalog. Kept separate from
    /// `library.json` so remote-only records and deletion tombstones never
    /// pollute the list of books actually present on this device.
    private var syncedCatalogURL: URL {
        supportDir.appendingPathComponent("SyncedCatalog.json")
    }

    init() {
        try? fileManager.createDirectory(at: booksDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)
        loadCatalog()
        loadSyncedCatalog()
        recomputeMissingBooks()
    }

    // MARK: - Catalog persistence

    private func loadCatalog() {
        guard let data = try? Data(contentsOf: catalogURL),
              let decoded = try? JSONDecoder().decode([Book].self, from: data)
        else { return }
        var migrated = decoded
        var didMigrate = false
        for index in migrated.indices where migrated[index].contentKey == nil {
            let storedURL = booksDir.appendingPathComponent(migrated[index].fileName)
            guard let key = try? Self.contentKey(forFileAt: storedURL) else { continue }
            migrated[index].contentKey = key
            didMigrate = true
        }
        books = migrated.sorted(by: Self.librarySort)
        if didMigrate { saveCatalog() }
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

    nonisolated static func contentKey(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func contentKey(forFileAt url: URL) throws -> String {
        contentKey(for: try Data(contentsOf: url, options: .mappedIfSafe))
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

    /// Copies the bundled sample EPUBs on first launch so the reviewer and new
    /// users can start reading immediately.
    func installBundledSamplesIfNeeded() async {
        let installedKey = "library.bundledSampleInstalled"
        guard !UserDefaults.standard.bool(forKey: installedKey) else { return }
        // Claim the flag up front so a re-entrant call (the .task modifier can
        // fire more than once) cannot install the sample twice; roll it back
        // on failure so the next launch retries.
        UserDefaults.standard.set(true, forKey: installedKey)

        let samples = Self.bundledSamples.compactMap { sample -> (URL, String)? in
            guard let url = Bundle.main.url(
                forResource: sample.resourceName,
                withExtension: "epub"
            ) else { return nil }
            return (url, sample.fileName)
        }
        guard samples.count == Self.bundledSamples.count else {
            UserDefaults.standard.set(false, forKey: installedKey)
            return
        }

        let pending = samples.reversed().map { sample in
            let id = UUID().uuidString
            return (
                source: sample.0,
                fileName: sample.1,
                id: id,
                destination: booksDir.appendingPathComponent("\(id).epub")
            )
        }
        do {
            for sample in pending {
                try fileManager.copyItem(at: sample.source, to: sample.destination)
            }
        } catch {
            for sample in pending {
                try? fileManager.removeItem(at: sample.destination)
            }
            UserDefaults.standard.set(false, forKey: installedKey)
            return
        }
        for sample in pending {
            await finishImport(
                id: sample.id,
                destination: sample.destination,
                originalName: sample.fileName
            )
        }
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
            contentKey: try? Self.contentKey(forFileAt: destination),
            fileName: "\(id).epub",
            title: title,
            author: author,
            addedAt: Date()
        )
        books.append(book)
        books.sort(by: Self.librarySort)
        saveCatalog()
        // A re-imported book is now local, so drop it from the restore hints;
        // the sync engine revives any tombstone on its next reconcile.
        recomputeMissingBooks()
    }

    // MARK: - Mutations

    func delete(_ book: Book) {
        try? fileManager.removeItem(at: fileURL(for: book))
        try? fileManager.removeItem(at: coverURL(for: book))
        books.removeAll { $0.id == book.id }
        saveCatalog()
        // Record a tombstone so a fresh install stops suggesting a book the
        // user intentionally deleted. Files are local-canonical, so this never
        // deletes anything on another device (ADR-0007).
        markCatalogTombstone(for: book)
        recomputeMissingBooks()
    }

    func markOpened(_ book: Book) {
        update(book.id) { $0.lastOpenedAt = Date() }
    }

    func saveProgress(bookID: String, locatorJSON: String?, progression: Double?) {
        update(bookID) {
            $0.locatorJSON = locatorJSON
            if let progression { $0.progression = progression }
            $0.positionUpdatedAt = Date()
        }
    }

    /// The reading position of a book as a sync record, or nil if it has never
    /// been opened. A position with no recorded timestamp falls back to
    /// `.distantPast` so a timestamped remote position always wins.
    func syncPosition(for book: Book) -> AnnotationSyncPosition? {
        guard let locatorJSON = book.locatorJSON else { return nil }
        return AnnotationSyncPosition(
            locatorJSON: locatorJSON,
            progression: book.progression,
            updatedAt: book.positionUpdatedAt ?? .distantPast
        )
    }

    func applySyncedPosition(_ position: AnnotationSyncPosition?, bookID: String) {
        guard let position else { return }
        update(bookID) {
            guard position.updatedAt >= ($0.positionUpdatedAt ?? .distantPast) else { return }
            $0.locatorJSON = position.locatorJSON
            $0.progression = position.progression
            $0.positionUpdatedAt = position.updatedAt
        }
    }

    // MARK: - Library catalog sync (ADR-0007)

    /// The current local books as sync records, unioned with the sidecar so
    /// deletion tombstones and books only seen on other devices ride along in
    /// the pushed catalog. Present books use `max(addedAt, lastOpenedAt)` as
    /// their `updatedAt` and win over a stale sidecar copy via last-writer-wins.
    /// Books without a `contentKey` are skipped: it is the only cross-device
    /// identity.
    func catalogRecords() -> [CatalogRecord] {
        let local = LibraryCatalog(books: books.compactMap(Self.record(for:)))
        return CatalogSyncMerge.merge(local, syncedCatalog).books
    }

    /// Stores the merged catalog in the sidecar and republishes `missingBooks`.
    /// Writes only the sidecar (never `books`), so it does not trigger the sync
    /// engine's `library.$books` push and cannot start an echo loop.
    func applyMergedCatalog(_ catalog: LibraryCatalog) {
        if catalog != syncedCatalog {
            syncedCatalog = catalog
            saveSyncedCatalog()
        }
        recomputeMissingBooks()
    }

    /// Derives the restore-hint list: catalog records that are not tombstoned
    /// and whose `contentKey` has no matching local book. Pure and static so it
    /// is unit-testable without touching the filesystem.
    nonisolated static func missingBooks(
        from catalog: [CatalogRecord],
        localContentKeys: Set<String>
    ) -> [MissingBook] {
        catalog
            .filter { $0.deletedAt == nil && !localContentKeys.contains($0.id) }
            .map { MissingBook(contentKey: $0.id, title: $0.title, author: $0.author) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func record(for book: Book) -> CatalogRecord? {
        guard let contentKey = book.contentKey else { return nil }
        return CatalogRecord(
            id: contentKey,
            title: book.title,
            author: book.author,
            updatedAt: max(book.addedAt, book.lastOpenedAt ?? book.addedAt),
            deletedAt: nil
        )
    }

    private func recomputeMissingBooks() {
        let localKeys = Set(books.compactMap(\.contentKey))
        missingBooks = Self.missingBooks(from: syncedCatalog.books, localContentKeys: localKeys)
    }

    private func loadSyncedCatalog() {
        guard let data = try? Data(contentsOf: syncedCatalogURL),
              let decoded = try? JSONDecoder().decode(LibraryCatalog.self, from: data)
        else { return }
        syncedCatalog = decoded
    }

    private func saveSyncedCatalog() {
        guard let data = try? JSONEncoder().encode(syncedCatalog) else { return }
        try? data.write(to: syncedCatalogURL, options: .atomic)
    }

    /// Records a deletion tombstone for a deliberately removed book. The
    /// tombstone's `updatedAt == deletedAt == now` beats the book's prior live
    /// `updatedAt` (import/open time), so the deletion wins on merge; a later
    /// re-import revives it (updatedAt > deletedAt clears the tombstone).
    private func markCatalogTombstone(for book: Book) {
        guard let contentKey = book.contentKey else { return }
        let now = Date()
        var records = syncedCatalog.books.filter { $0.id != contentKey }
        records.append(CatalogRecord(
            id: contentKey,
            title: book.title,
            author: book.author,
            updatedAt: now,
            deletedAt: now
        ))
        // Fold through the merge so pruning and ordering match a reconcile.
        syncedCatalog = CatalogSyncMerge.merge(LibraryCatalog(books: records), LibraryCatalog(), now: now)
        saveSyncedCatalog()
    }

    private func update(_ id: String, _ mutate: (inout Book) -> Void) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        mutate(&books[index])
        books.sort(by: Self.librarySort)
        saveCatalog()
    }
}
