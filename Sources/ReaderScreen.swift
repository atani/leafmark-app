import SwiftUI
import StoreKit
import UIKit
import UniformTypeIdentifiers
import ReadiumShared
import ReadiumNavigator

/// Full-screen reading experience: navigator + tap-to-toggle chrome,
/// table of contents, highlights and appearance settings.
struct ReaderScreen: View {
    let book: Book
    let publication: Publication
    @ObservedObject var library: LibraryStore
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var highlightStore: HighlightStore
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var fontStore: FontStore
    @EnvironmentObject private var bookmarkStore: BookmarkStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @StateObject private var bridge = NavigatorBridge()
    @State private var chromeVisible = true
    @State private var showContents = false
    @State private var showSettings = false
    @State private var showHighlights = false
    @State private var showSearch = false
    @State private var showPaywall = false
    @State private var progression: Double?
    /// The current reading position, used to add/toggle bookmarks.
    @State private var currentLocator: Locator?
    @State private var sessionStart = Date()

    /// Synthetic ADE-style page positions (~1024 chars each), loaded once
    /// from Readium's positions service. Empty when the service is missing,
    /// which hides the optional page header/footer.
    @State private var positions: [Locator] = []

    /// Highlight being edited in the note sheet.
    @State private var noteTarget: Highlight?
    /// Highlight whose actions dialog (color/note/delete) is shown.
    @State private var actionTarget: Highlight?
    /// Highlight the user tried to make when the free limit stopped them.
    /// Applied automatically if they upgrade from the paywall.
    @State private var pendingHighlight: (locator: Locator, withNote: Bool)?

    /// Content image the user tapped, presented full-screen for zoom/pan.
    @State private var zoomImageTarget: ZoomImageTarget?

    @AppStorage("highlight.color") private var highlightColorRaw = HighlightColor.yellow.rawValue

    private var highlightColor: HighlightColor {
        HighlightColor(rawValue: highlightColorRaw) ?? .yellow
    }

    /// Family name of the selected user-imported font, or nil for built-ins.
    private var selectedCustomFamily: String? {
        guard appearance.fontRaw.hasPrefix(AppearanceStore.customFontPrefix) else { return nil }
        return String(appearance.fontRaw.dropFirst(AppearanceStore.customFontPrefix.count))
    }

    private var initialLocator: Locator? {
        guard let json = book.locatorJSON,
              let value = try? JSONValue(jsonString: json),
              let locator = try? Locator(json: value, warnings: nil)
        else { return nil }
        return locator
    }

    var body: some View {
        ZStack {
            ReaderView(
                publication: publication,
                initialLocation: initialLocator,
                preferences: appearance.preferences,
                makeFontFamilyDeclarations: {
                    var declarations = fontStore.fontFamilyDeclarations(for: selectedCustomFamily)
                    // Synthetic bolding via -webkit-text-stroke, so the Font
                    // Weight setting also thickens single-face fonts (which
                    // Readium's native font-weight cannot; see issue #22). Like
                    // the imported-font declarations, this is fixed for the
                    // navigator's lifetime, so a weight change affecting the
                    // stroke takes effect the next time a book is opened. The
                    // native fontWeight preference stays live and untouched.
                    if let synthetic = SyntheticWeight.declaration(forWeight: appearance.fontWeight) {
                        declarations.append(synthetic)
                    }
                    return declarations
                },
                bridge: bridge,
                onLocatorChange: { locator in
                    progression = locator.locations.totalProgression
                    currentLocator = locator
                    library.saveProgress(
                        bookID: book.id,
                        locatorJSON: try? locator.jsonString(),
                        progression: locator.locations.totalProgression
                    )
                    // Reaching the end of a book is the strongest signal that
                    // the app did its job, so it is worth an ask.
                    if ReviewRequester.recordReadingProgress(locator.locations.totalProgression) {
                        offerReviewPrompt(after: 1.5)
                    }
                },
                onTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        chromeVisible.toggle()
                    }
                },
                onImageTap: { image in
                    zoomImageTarget = ZoomImageTarget(image: image)
                },
                onHighlightSelection: { makeHighlight(withNote: false) },
                onNoteSelection: { makeHighlight(withNote: true) },
                onHighlightActivated: { id in
                    actionTarget = highlightStore.highlight(withID: id)
                }
            )
            .ignoresSafeArea()

            if chromeVisible {
                chrome
            }

            // Optional page header/footer. Shown only while the chrome is
            // hidden so they never collide with the navigation bar or the
            // progress-bar pill, mirroring a distraction-free reader.
            if !chromeVisible,
               appearance.showPageHeader || appearance.showPageFooter,
               let info = PagePositionInfo(positions: positions, current: currentLocator) {
                pageOverlay(info)
            }
        }
        .statusBarHidden(!chromeVisible)
        .sheet(isPresented: $showContents) {
            NavigationSheet(
                publication: publication,
                book: book,
                bookmarks: bookmarkStore,
                onSelectLink: { link in
                    showContents = false
                    bridge.go(to: link)
                },
                onSelectLocator: { locator in
                    showContents = false
                    bridge.go(to: locator)
                }
            )
        }
        .sheet(isPresented: $showHighlights) {
            HighlightsSheet(
                book: book,
                store: highlightStore,
                purchases: store,
                onSelect: { highlight in
                    showHighlights = false
                    if let locator = highlightStore.locator(of: highlight) {
                        bridge.go(to: locator)
                    }
                }
            )
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // Closing the paywall without buying abandons the interrupted
            // highlight — a later upgrade from another screen must not
            // resurrect a selection the user has long forgotten.
            // (On purchase, onChange(of: isPro) already applied it.)
            pendingHighlight = nil
        }) {
            PaywallView(store: store, context: .highlightLimit)
        }
        .sheet(isPresented: $showSettings) {
            AppearanceSheet()
                .presentationDetents([.fraction(0.35), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $showSearch) {
            SearchSheet(publication: publication) { locator in
                showSearch = false
                bridge.go(to: locator)
            }
        }
        .sheet(item: $noteTarget) { highlight in
            NoteEditorSheet(highlight: highlight, store: highlightStore)
        }
        .fullScreenCover(item: $zoomImageTarget) { target in
            ZoomableImageView(publication: publication, image: target.image)
        }
        .confirmationDialog(
            "Highlight",
            isPresented: Binding(
                get: { actionTarget != nil },
                set: { if !$0 { actionTarget = nil } }
            ),
            titleVisibility: .hidden
        ) {
            if let target = actionTarget {
                ForEach(HighlightColor.allCases) { color in
                    if color != target.color {
                        Button(color.label) { recolor(target, to: color) }
                    }
                }
                Button(target.note?.isEmpty == false ? "Edit Note" : "Add Note") {
                    noteTarget = target
                }
                Button("Delete Highlight", role: .destructive) {
                    highlightStore.remove(target.id)
                    refreshDecorations()
                }
            }
        }
        .onReceive(highlightStore.$highlights) { _ in refreshDecorations() }
        .onChange(of: store.isPro) { _, isPro in
            // The user upgraded mid-flow: finish the highlight they were
            // making when the free limit interrupted them.
            guard isPro, let pending = pendingHighlight else { return }
            pendingHighlight = nil
            addHighlight(at: pending.locator, withNote: pending.withNote)
        }
        .onChange(of: appearance.themeRaw) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.fontRaw) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.fontWeight) {
            bridge.submit(appearance.preferences)
            // The serve-time declaration cannot reach the open pages, so the
            // stroke is rewritten in place; otherwise the control looks dead
            // until the native weight snaps to a real Bold face.
            bridge.applySyntheticWeight(appearance.fontWeight)
        }
        .onChange(of: appearance.fontSize) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.columnsRaw) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.scrollEnabled) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.lineHeight) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.pageMargins) { bridge.submit(appearance.preferences) }
        .onAppear {
            library.markOpened(book)
            sessionStart = Date()
            // The navigator is created in the same render pass; defer one
            // turn of the run loop so decorations land on a live web view.
            DispatchQueue.main.async { refreshDecorations() }
            if ReviewRequester.recordBookOpen(bookID: book.id) {
                offerReviewPrompt(after: 2)
            }
        }
        .onDisappear {
            stats.recordSession(bookID: book.id, startedAt: sessionStart, endedAt: Date())
        }
        .task {
            // Load the synthetic page list once. An empty result (no
            // positions service) simply hides the header/footer.
            positions = (try? await publication.positions().get()) ?? []
        }
    }

    // MARK: - Page overlay

    /// Unobtrusive header (pages left in chapter) and footer (page X of Y),
    /// each gated by its Appearance toggle. Non-interactive so taps still
    /// reach the reader to toggle the chrome.
    private func pageOverlay(_ info: PagePositionInfo) -> some View {
        VStack {
            if appearance.showPageHeader {
                pageLabel(info.chapterHeaderText)
                    .padding(.top, 6)
            }

            Spacer()

            if appearance.showPageFooter {
                pageLabel(info.footerText)
                    .padding(.bottom, 6)
            }
        }
        .padding(.horizontal)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// Capsule-backed caption so the label stays legible even when book
    /// content (a heading, an image) runs underneath it.
    private func pageLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
    }

    // MARK: - Highlights

    private func makeHighlight(withNote: Bool) {
        guard let locator = bridge.selectionLocator else { return }
        bridge.clearSelection()
        guard StoreManager.canAddHighlight(
            isPro: store.isPro,
            currentCount: highlightStore.highlights(for: book.id).count
        ) else {
            // Remember what the user wanted so an upgrade from the paywall
            // completes it instead of making them reselect the text.
            pendingHighlight = (locator, withNote)
            showPaywall = true
            return
        }
        addHighlight(at: locator, withNote: withNote)
    }

    private func addHighlight(at locator: Locator, withNote: Bool) {
        let highlight = highlightStore.add(
            bookID: book.id,
            locator: locator,
            color: highlightColor
        )
        refreshDecorations()
        if withNote {
            noteTarget = highlight
            // The note editor opens right away; asking over it would be
            // dropped by the system and interrupt the reader besides.
            return
        }
        if ReviewRequester.recordHighlightCreated(totalCount: highlightStore.activeCount) {
            offerReviewPrompt(after: 1.5)
        }
    }

    /// Offers the App Store review prompt after `delay`, so it lands on a
    /// settled screen instead of one still animating. The attempt is recorded
    /// up front because `requestReview()` reports nothing back, and because two
    /// milestones reached moments apart must not ask twice.
    private func offerReviewPrompt(after delay: TimeInterval) {
        ReviewRequester.markRequested()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            requestReview()
        }
    }

    private func recolor(_ highlight: Highlight, to color: HighlightColor) {
        highlightColorRaw = color.rawValue
        highlightStore.update(highlight.id) { $0.color = color }
        refreshDecorations()
    }

    private func refreshDecorations() {
        bridge.applyHighlights(
            highlightStore.highlights(for: book.id),
            store: highlightStore
        )
    }

    // MARK: - Bookmarks

    private var isCurrentPageBookmarked: Bool {
        guard let currentLocator else { return false }
        return bookmarkStore.isBookmarked(bookID: book.id, at: currentLocator)
    }

    private func toggleBookmark() {
        guard let currentLocator else { return }
        // Store the chapter title when the locator has one; otherwise leave
        // it nil and let the list fall back to "Bookmark" — the row shows
        // the progression separately, so a "42% … 42%" duplicate is avoided.
        bookmarkStore.toggle(bookID: book.id, locator: currentLocator, title: currentLocator.title)
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack {
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Close")

                Spacer()

                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Spacer()

                if publication.isSearchable {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }

                Button {
                    toggleBookmark()
                } label: {
                    Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                }
                .disabled(currentLocator == nil)
                .accessibilityLabel(isCurrentPageBookmarked ? "Remove Bookmark" : "Add Bookmark")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("Appearance")

                Button {
                    showHighlights = true
                } label: {
                    Image(systemName: "highlighter")
                }
                .accessibilityLabel("Highlights")

                Button {
                    showContents = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("Contents")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)

            Spacer()

            if let progression {
                VStack(spacing: 4) {
                    ProgressView(value: progression)
                        .tint(.secondary)
                    Text("\(Int((progression * 100).rounded()))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.bar, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .transition(.opacity)
    }
}

/// Identifiable wrapper so a tapped content image can drive `fullScreenCover`.
/// A fresh `id` per tap lets the user reopen the same image after dismissing.
private struct ZoomImageTarget: Identifiable {
    let id = UUID()
    let image: ImageContentElement
}

/// Table of contents and the book's bookmarks, on two tabs.
private struct NavigationSheet: View {
    let publication: Publication
    let book: Book
    @ObservedObject var bookmarks: BookmarkStore
    let onSelectLink: (ReadiumShared.Link) -> Void
    let onSelectLocator: (Locator) -> Void

    private enum Tab: Hashable { case contents, bookmarks }

    @Environment(\.dismiss) private var dismiss
    @State private var links: [ReadiumShared.Link] = []
    @State private var loaded = false
    @State private var tab: Tab = .contents

    private var bookBookmarks: [Bookmark] { bookmarks.bookmarks(for: book.id) }

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .contents: contentsList
                case .bookmarks: bookmarksList
                }
            }
            .navigationTitle(tab == .contents ? "Contents" : "Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $tab) {
                        Text("Contents").tag(Tab.contents)
                        Text("Bookmarks").tag(Tab.bookmarks)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            links = (try? await publication.tableOfContents().get()) ?? []
            loaded = true
        }
    }

    @ViewBuilder
    private var contentsList: some View {
        if !loaded {
            ProgressView()
        } else if links.isEmpty {
            ContentUnavailableView(
                "No Contents",
                systemImage: "list.bullet",
                description: Text("This book does not provide a table of contents.")
            )
        } else {
            List(flatten(links, level: 0), id: \.item.href) { entry in
                Button {
                    onSelectLink(entry.item)
                } label: {
                    Text(entry.item.title ?? entry.item.href.description)
                        .lineLimit(2)
                        .padding(.leading, CGFloat(entry.level) * 16)
                }
                .tint(.primary)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var bookmarksList: some View {
        if bookBookmarks.isEmpty {
            ContentUnavailableView(
                "No Bookmarks",
                systemImage: "bookmark",
                description: Text("Tap the bookmark button while reading to save a page here.")
            )
        } else {
            List {
                ForEach(bookBookmarks) { bookmark in
                    Button {
                        if let locator = bookmarks.locator(of: bookmark) {
                            onSelectLocator(locator)
                        }
                    } label: {
                        HStack {
                            Text(bookmark.title ?? "Bookmark")
                                .lineLimit(1)
                            Spacer()
                            if let progression = bookmarks.progression(of: bookmark) {
                                Text(BookmarkStore.progressionLabel(progression))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    for bookmark in offsets.map({ bookBookmarks[$0] }) {
                        bookmarks.remove(bookmark.id)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func flatten(
        _ links: [ReadiumShared.Link],
        level: Int
    ) -> [(item: ReadiumShared.Link, level: Int)] {
        links.flatMap { link in
            [(link, level)] + flatten(link.children, level: level + 1)
        }
    }
}

/// All highlights of the open book, with Markdown export.
private struct HighlightsSheet: View {
    let book: Book
    @ObservedObject var store: HighlightStore
    @ObservedObject var purchases: StoreManager
    let onSelect: (Highlight) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var showPaywall = false
    @State private var paywallContext: PaywallContext = .export

    /// Set when the free export is spent, and applied only after this sheet
    /// closes. Flipping the entitlement while the share sheet is presenting
    /// would swap the ShareLink out for the paywall Button mid-presentation,
    /// which crashes inside SwiftUI's activity picker
    /// (EXC_BAD_ACCESS in SharingActivityPickerBridge.show).
    @State private var freeExportPendingConsume = false

    /// Set when an export reached the review milestone, and applied only after
    /// this sheet closes. iOS silently drops `requestReview()` while another
    /// sheet (here, the share sheet) is presenting, and the prompt is offered
    /// only once per install, so firing it too early burns the only chance.
    @State private var reviewPendingAfterExport = false

    private var items: [Highlight] {
        store.highlights(for: book.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Highlights",
                        systemImage: "highlighter",
                        description: Text("Select text while reading to create a highlight.")
                    )
                } else {
                    List {
                        ForEach(items) { highlight in
                            Button {
                                onSelect(highlight)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(highlight.color.color)
                                        .frame(width: 4)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(highlight.text)
                                            .font(.subheadline)
                                            .lineLimit(3)
                                        if let note = highlight.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                        .onDelete { offsets in
                            let idsToRemove = offsets.map { items[$0].id }
                            for id in idsToRemove {
                                store.remove(id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Highlights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !items.isEmpty {
                        if StoreManager.canExport(
                            isPro: purchases.isPro,
                            hasUsedFreeExport: purchases.hasUsedFreeExport
                        ) {
                            ShareLink(
                                item: store.exportFile(for: book),
                                preview: SharePreview("\(book.title) — Highlights")
                            ) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel(
                                purchases.isPro
                                    ? "Export as Markdown"
                                    : "Export as Markdown (one free export)"
                            )
                            .simultaneousGesture(TapGesture().onEnded {
                                freeExportPendingConsume = true
                                if ReviewRequester.recordExport() {
                                    reviewPendingAfterExport = true
                                }
                            })
                        } else {
                            Button {
                                paywallContext = .export
                                showPaywall = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Export as Markdown (Leafmark Pro)")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !purchases.isPro {
                    freePlanFooter
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: purchases, context: paywallContext)
            }
            .onDisappear {
                // Safe to change the entitlement now: the share sheet is gone,
                // so nothing is mid-presentation.
                if freeExportPendingConsume {
                    freeExportPendingConsume = false
                    purchases.markFreeExportUsed()
                }
                if reviewPendingAfterExport {
                    reviewPendingAfterExport = false
                    ReviewRequester.markRequested()
                    // Let the dismissal animation finish so the prompt lands on
                    // the reader instead of a view that is still going away.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        requestReview()
                    }
                }
            }
        }
    }

    /// Keeps the free quota visible so the paywall never feels like an
    /// ambush: the user always knows how many highlights they have left.
    private var freePlanFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Free plan: \(min(items.count, StoreManager.freeHighlightLimit)) of \(StoreManager.freeHighlightLimit) highlights in this book")
                if !purchases.hasUsedFreeExport {
                    Text("One free Markdown export available")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Upgrade") {
                paywallContext = .highlightLimit
                showPaywall = true
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// Edits the note attached to a highlight.
private struct NoteEditorSheet: View {
    let highlight: Highlight
    @ObservedObject var store: HighlightStore

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(highlight.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal, 4)

                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.update(highlight.id) { $0.note = text }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { text = highlight.note ?? "" }
    }
}

/// Theme / font family / font size controls.
private struct AppearanceSheet: View {
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var fontStore: FontStore
    @Environment(\.dismiss) private var dismiss
    @State private var showFontImporter = false

    private static let fontTypes: [UTType] = [
        UTType(filenameExtension: "ttf"),
        UTType(filenameExtension: "otf"),
    ].compactMap { $0 }

    /// Unique imported family names, in a stable order for the picker.
    private var importedFamilies: [String] {
        var seen = Set<String>()
        return fontStore.fonts.compactMap { font in
            seen.insert(font.familyName).inserted ? font.familyName : nil
        }
    }

    private var systemFamilies: [String] {
        UIFont.familyNames
            .filter { !$0.hasPrefix(".") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Distinguishes faces of the same family in the management list.
    private func faceLabel(for font: CustomFont) -> String {
        var qualifiers: [String] = []
        if let weight = font.cssWeight, weight != 400 {
            qualifiers.append(weight >= 600 ? "Bold \(weight)" : "Weight \(weight)")
        }
        if font.italic == true {
            qualifiers.append("Italic")
        }
        return qualifiers.isEmpty
            ? font.familyName
            : "\(font.familyName) (\(qualifiers.joined(separator: ", ")))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: $appearance.themeRaw) {
                        ForEach(AppearanceStore.ReaderTheme.allCases) { theme in
                            Text(theme.label).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("Font", selection: $appearance.fontRaw) {
                        ForEach(AppearanceStore.ReaderFont.allCases) { font in
                            Text(font.rawValue).tag(font.rawValue)
                        }
                        Section("System Fonts") {
                            ForEach(systemFamilies, id: \.self) { family in
                                Text(family)
                                    .tag(AppearanceStore.systemFontPrefix + family)
                            }
                        }
                        // One entry per family: multiple faces (regular /
                        // bold files) share a picker row and a tag.
                        if !importedFamilies.isEmpty {
                            Section("Imported Fonts") {
                                ForEach(importedFamilies, id: \.self) { family in
                                    Text(family)
                                        .tag(AppearanceStore.customFontPrefix + family)
                                }
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)

                    HStack {
                        Button {
                            appearance.adjustFontSize(by: -AppearanceStore.fontSizeStep)
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Text("\(Int((appearance.fontSize * 100).rounded()))%")
                            .font(.callout.monospacedDigit())
                            .frame(width: 64)

                        Button {
                            appearance.adjustFontSize(by: AppearanceStore.fontSizeStep)
                        } label: {
                            Image(systemName: "textformat.size.larger")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    // Above 100% this also applies a synthetic -webkit-text-stroke
                    // so single-face fonts thicken too (issue #22). The native
                    // font-weight updates live; the synthetic stroke is baked in
                    // at book open, so its change shows the next time the book is
                    // opened.
                    Stepper(
                        value: $appearance.fontWeight,
                        in: AppearanceStore.fontWeightRange,
                        step: AppearanceStore.fontWeightStep
                    ) {
                        HStack {
                            Text("Font Weight")
                            Spacer()
                            Text(appearance.fontWeight == 1.0
                                ? "Default"
                                : "\(Int((appearance.fontWeight * 100).rounded()))%")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showFontImporter = true
                    } label: {
                        Label("Import Font…", systemImage: "plus")
                    }
                } header: {
                    Text("Font")
                } footer: {
                    if !fontStore.fonts.isEmpty {
                        Text("Import one or more .ttf or .otf files. ZIP files are not supported. Reopen this book to use a font you just imported.")
                    } else {
                        Text("Import one or more .ttf or .otf files. ZIP files are not supported.")
                    }
                }

                if !fontStore.fonts.isEmpty {
                    Section("Imported Fonts") {
                        ForEach(fontStore.fonts) { font in
                            Text(faceLabel(for: font))
                        }
                        .onDelete { offsets in
                            // Resolve targets before mutating: removing
                            // shifts the indices in `fonts`.
                            let removed = offsets.map { fontStore.fonts[$0] }
                            for font in removed {
                                fontStore.remove(font)
                                // Fall back to the publisher default only
                                // when no other face of the family remains.
                                let familyGone = !fontStore.fonts.contains { $0.familyName == font.familyName }
                                if familyGone,
                                   appearance.fontRaw == AppearanceStore.customFontPrefix + font.familyName {
                                    appearance.fontRaw = AppearanceStore.ReaderFont.publisher.rawValue
                                }
                            }
                        }
                    }
                }

                Section("Layout") {
                    Picker("Columns", selection: $appearance.columnsRaw) {
                        ForEach(AppearanceStore.ReaderColumns.allCases) { columns in
                            Text(columns.rawValue).tag(columns.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Scroll Mode", isOn: $appearance.scrollEnabled)

                    Toggle("Chapter Pages in Header", isOn: $appearance.showPageHeader)

                    Toggle("Page Numbers in Footer", isOn: $appearance.showPageFooter)

                    Stepper(
                        value: $appearance.lineHeight,
                        in: 0 ... AppearanceStore.lineHeightRange.upperBound,
                        step: AppearanceStore.lineHeightStep
                    ) {
                        HStack {
                            Text("Line Height")
                            Spacer()
                            Text(appearance.lineHeight > 0
                                ? String(format: "%.2f", appearance.lineHeight)
                                : "Default")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: appearance.lineHeight) { _, value in
                        // Snap from "Default" (0) straight into the valid range.
                        if value > 0, value < AppearanceStore.lineHeightRange.lowerBound {
                            appearance.lineHeight = AppearanceStore.lineHeightRange.lowerBound
                        }
                    }

                    Stepper(
                        value: $appearance.pageMargins,
                        in: AppearanceStore.pageMarginsRange,
                        step: AppearanceStore.pageMarginsStep
                    ) {
                        HStack {
                            Text("Margins")
                            Spacer()
                            Text(String(format: "%.2fx", appearance.pageMargins))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Readers reporting rendering problems could not tell which
                // build they were on ("the app gives no indication"), which
                // made it impossible to know whether a fix had reached them.
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppInfo.versionDisplay)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    // The system prompt can only be shown a few times a year
                    // and gives no way to ask for it. This link always works,
                    // for the reader who went looking for it.
                    Link(destination: AppInfo.writeReviewURL) {
                        Label("Rate Leafmark", systemImage: "star")
                    }
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFontImporter,
                allowedContentTypes: Self.fontTypes,
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                var lastImported: CustomFont?
                for url in urls {
                    lastImported = fontStore.importFont(from: url) ?? lastImported
                }
                if let imported = lastImported {
                    appearance.fontRaw = AppearanceStore.customFontPrefix + imported.familyName
                }
            }
        }
    }
}
