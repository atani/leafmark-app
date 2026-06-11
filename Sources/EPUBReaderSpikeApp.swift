import SwiftUI

@main
struct EPUBReaderSpikeApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var appearance = AppearanceStore()

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library)
                .environmentObject(appearance)
                .onOpenURL { url in
                    Task { await library.importEPUB(from: url) }
                }
        }
    }
}
