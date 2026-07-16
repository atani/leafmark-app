import SwiftUI

@main
struct LeafmarkApp: App {
    @StateObject private var library: LibraryStore
    @StateObject private var appearance = AppearanceStore()
    @StateObject private var highlights: HighlightStore
    @StateObject private var stats = StatsStore()
    @StateObject private var store = StoreManager()
    @StateObject private var fonts = FontStore()
    @StateObject private var bookmarks: BookmarkStore
    @StateObject private var sync: SyncEngine

    init() {
        // The sync engine mirrors the same store instances that the views use,
        // so it must be built from them rather than from fresh copies.
        let library = LibraryStore()
        let highlights = HighlightStore()
        let bookmarks = BookmarkStore()
        _library = StateObject(wrappedValue: library)
        _highlights = StateObject(wrappedValue: highlights)
        _bookmarks = StateObject(wrappedValue: bookmarks)
        _sync = StateObject(wrappedValue: SyncEngine(
            library: library,
            highlights: highlights,
            bookmarks: bookmarks
        ))
    }

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library)
                .environmentObject(appearance)
                .environmentObject(highlights)
                .environmentObject(stats)
                .environmentObject(store)
                .environmentObject(fonts)
                .environmentObject(bookmarks)
                .task { await store.load() }
                .task { sync.start() }
                .onOpenURL { url in
                    Task { await library.importEPUB(from: url) }
                }
        }
    }
}
