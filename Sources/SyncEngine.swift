import Combine
import Foundation
import UIKit

/// Mirrors annotation records (highlights, bookmarks, reading positions) into
/// the app's iCloud Documents container and merges remote changes back into the
/// local stores, which remain canonical (ADR-0002, ADR-0007).
///
/// Sync is zero-config: it is active whenever the ubiquity container is
/// available and silently inactive otherwise. There is no UI and no vendor
/// account — the data lives only in the user's own iCloud.
@MainActor
final class SyncEngine: ObservableObject {
    /// Must match the iCloud container declared in `Leafmark.entitlements`.
    /// The bundle id stays `com.atani.inkwell`; only the container is namespaced.
    static let containerIdentifier = "iCloud.com.atani.inkwell"

    /// True once a ubiquity container was found. Exposed for diagnostics; the
    /// UI does not surface it in v1.
    @Published private(set) var isActive = false

    private let library: LibraryStore
    private let highlights: HighlightStore
    private let bookmarks: BookmarkStore

    /// `<ubiquity>/Documents/Annotations`, resolved once the container is found.
    private var annotationsURL: URL?
    private var metadataQuery: NSMetadataQuery?
    private var cancellables: Set<AnyCancellable> = []

    /// Set while merged remote records are written back into the stores, so the
    /// stores' publishers do not schedule a push and cause an echo loop.
    private var isApplyingRemote = false
    private var pushTask: Task<Void, Never>?
    private var started = false

    /// Serializes reconcile passes: the metadata query and the debounced push
    /// can both fire, so a pass in flight defers a follow-up rather than running
    /// two interleaved loops.
    private var isReconciling = false
    private var reconcilePending = false

    /// The last document written per contentKey, so an unchanged reconcile does
    /// not rewrite the file (which would ripple to every device).
    private var lastSynced: [String: AnnotationSyncDocument] = [:]

    /// Debounce window for coalescing local mutations before a push.
    private let pushDebounce: Duration = .milliseconds(1500)

    init(library: LibraryStore, highlights: HighlightStore, bookmarks: BookmarkStore) {
        self.library = library
        self.highlights = highlights
        self.bookmarks = bookmarks
    }

    /// Resolves the ubiquity container off the main thread, then wires change
    /// observation and performs the initial reconcile. Safe to call once.
    func start() {
        guard !started else { return }
        started = true
        Task { await activate() }
    }

    private func activate() async {
        let identifier = Self.containerIdentifier
        // `url(forUbiquityContainerIdentifier:)` can block, so keep it off-main.
        let container = await Task.detached {
            FileManager.default.url(forUbiquityContainerIdentifier: identifier)
        }.value
        guard let container else {
            isActive = false
            return
        }

        let annotations = container
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Annotations", isDirectory: true)
        try? FileManager.default.createDirectory(at: annotations, withIntermediateDirectories: true)
        annotationsURL = annotations
        isActive = true

        observeLocalMutations()
        startMetadataQuery()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        await reconcileAll()
    }

    // MARK: - Change observation

    private func observeLocalMutations() {
        // dropFirst: skip the value published on subscription; the initial
        // state is handled by the explicit reconcile in `activate`.
        library.$books.dropFirst()
            .sink { [weak self] _ in self?.schedulePush() }
            .store(in: &cancellables)
        highlights.$highlights.dropFirst()
            .sink { [weak self] _ in self?.schedulePush() }
            .store(in: &cancellables)
        bookmarks.$bookmarks.dropFirst()
            .sink { [weak self] _ in self?.schedulePush() }
            .store(in: &cancellables)
    }

    private func schedulePush() {
        guard isActive, !isApplyingRemote else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: self?.pushDebounce ?? .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await self?.reconcileAll()
        }
    }

    @objc private func handleForeground() {
        Task { await reconcileAll() }
    }

    private func startMetadataQuery() {
        guard let annotationsURL else { return }
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        // Scope to our Annotations subfolder so unrelated iCloud documents do
        // not wake the engine.
        query.predicate = NSPredicate(
            format: "%K BEGINSWITH %@",
            NSMetadataItemPathKey,
            annotationsURL.path
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        query.start()
        metadataQuery = query
    }

    @objc private func metadataQueryDidUpdate() {
        // A remote arrival can land in any book's file; reconcile all books.
        // Reconcile is cheap when nothing changed (see `lastSynced`).
        Task { await reconcileAll() }
    }

    // MARK: - Reconcile

    /// Reconciles every book that has a content key. One canonical book is
    /// chosen per key so duplicate imports of the same EPUB do not fight over
    /// the same document.
    private func reconcileAll() async {
        guard isActive, let annotationsURL else { return }
        // Coalesce: if a pass is already running, ask it to run once more when
        // it finishes instead of interleaving a second loop.
        guard !isReconciling else {
            reconcilePending = true
            return
        }
        isReconciling = true
        defer { isReconciling = false }

        repeat {
            reconcilePending = false
            for book in canonicalBooksByContentKey() {
                guard let contentKey = book.contentKey else { continue }
                await reconcile(book: book, contentKey: contentKey, in: annotationsURL)
            }
        } while reconcilePending
    }

    private func canonicalBooksByContentKey() -> [Book] {
        var seen: Set<String> = []
        var result: [Book] = []
        // `library.books` is already sorted most-recent-first, so the first
        // book seen for a key is the one the user most recently touched.
        for book in library.books {
            guard let key = book.contentKey else { continue }
            if seen.insert(key).inserted { result.append(book) }
        }
        return result
    }

    private func reconcile(book: Book, contentKey: String, in directory: URL) async {
        let local = buildLocalDocument(for: book)
        let url = directory.appendingPathComponent("\(contentKey).json")

        let remote = await Self.readDocument(at: url)
        let merged = AnnotationSyncMerge.merge([local, remote])

        // Apply merged records back into the stores without echoing a push.
        isApplyingRemote = true
        highlights.applyMerged(merged.highlights, bookID: book.id)
        bookmarks.applyMerged(merged.bookmarks, bookID: book.id)
        library.applySyncedPosition(merged.position, bookID: book.id)
        isApplyingRemote = false

        // Only write when the merged document differs from what is on disk (and
        // from the last thing we wrote), to avoid rewrite storms across devices.
        if merged != remote || lastSynced[contentKey] != merged {
            await Self.writeDocument(merged, to: url)
            lastSynced[contentKey] = merged
        }
    }

    private func buildLocalDocument(for book: Book) -> AnnotationSyncDocument {
        AnnotationSyncDocument(
            schemaVersion: annotationSyncSchemaVersion,
            highlights: highlights.syncedRecords(for: book.id),
            bookmarks: bookmarks.syncedRecords(for: book.id),
            position: library.syncPosition(for: book)
        )
    }

    // MARK: - Coordinated file I/O

    /// Reads a document, merging every unresolved `NSFileVersion` conflict copy
    /// into one and marking the conflict resolved. A missing or corrupt file
    /// yields an empty document (tolerated). Runs off-main; it touches no
    /// MainActor state.
    private nonisolated static func readDocument(at url: URL) async -> AnnotationSyncDocument {
        await Task.detached {
            var documents: [AnnotationSyncDocument] = []
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
                if let document = decode(at: readURL) {
                    documents.append(document)
                }
                let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: readURL) ?? []
                for version in conflicts {
                    if let document = decode(at: version.url) {
                        documents.append(document)
                    }
                }
            }
            let merged = AnnotationSyncMerge.merge(documents)
            resolveConflicts(at: url)
            return merged
        }.value
    }

    private nonisolated static func writeDocument(_ document: AnnotationSyncDocument, to url: URL) async {
        await Task.detached {
            guard let data = try? JSONEncoder().encode(document) else { return }
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(
                writingItemAt: url,
                options: .forReplacing,
                error: &coordinationError
            ) { writeURL in
                try? FileManager.default.createDirectory(
                    at: writeURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? data.write(to: writeURL, options: .atomic)
            }
        }.value
    }

    private nonisolated static func decode(at url: URL) -> AnnotationSyncDocument? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AnnotationSyncDocument.self, from: data)
    }

    /// Merge is idempotent and commutative, so once every version is folded in
    /// the winning content is written back and the other versions are removed.
    private nonisolated static func resolveConflicts(at url: URL) {
        guard let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
              !conflicts.isEmpty
        else { return }
        for version in conflicts { version.isResolved = true }
        try? NSFileVersion.removeOtherVersionsOfItem(at: url)
    }
}
