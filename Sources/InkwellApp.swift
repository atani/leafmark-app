import SwiftUI

@main
struct InkwellApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var appearance = AppearanceStore()
    @StateObject private var highlights = HighlightStore()
    @StateObject private var stats = StatsStore()
    @StateObject private var store = StoreManager()
    @StateObject private var fonts = FontStore()
    @StateObject private var bookmarks = BookmarkStore()

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
                .onOpenURL { url in
                    Task { await library.importEPUB(from: url) }
                }
        }
    }
}
