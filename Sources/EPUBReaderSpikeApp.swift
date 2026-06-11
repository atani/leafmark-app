import SwiftUI

@main
struct EPUBReaderSpikeApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var appearance = AppearanceStore()
    @StateObject private var highlights = HighlightStore()
    @StateObject private var stats = StatsStore()

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library)
                .environmentObject(appearance)
                .environmentObject(highlights)
                .environmentObject(stats)
                .onOpenURL { url in
                    Task { await library.importEPUB(from: url) }
                }
        }
    }
}
