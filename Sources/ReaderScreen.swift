import SwiftUI
import StoreKit
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
    @State private var sessionStart = Date()

    /// Highlight being edited in the note sheet.
    @State private var noteTarget: Highlight?
    /// Highlight whose actions dialog (color/note/delete) is shown.
    @State private var actionTarget: Highlight?

    @AppStorage("highlight.color") private var highlightColorRaw = HighlightColor.yellow.rawValue

    private var highlightColor: HighlightColor {
        HighlightColor(rawValue: highlightColorRaw) ?? .yellow
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
                bridge: bridge,
                onLocatorChange: { locator in
                    progression = locator.locations.totalProgression
                    library.saveProgress(
                        bookID: book.id,
                        locatorJSON: try? locator.jsonString(),
                        progression: locator.locations.totalProgression
                    )
                },
                onTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        chromeVisible.toggle()
                    }
                },
                onHighlightSelection: { makeHighlight(withNote: false) },
                onNoteSelection: { makeHighlight(withNote: true) },
                onHighlightActivated: { id in
                    actionTarget = highlightStore.highlights.first { $0.id == id }
                }
            )
            .ignoresSafeArea()

            if chromeVisible {
                chrome
            }
        }
        .statusBarHidden(!chromeVisible)
        .sheet(isPresented: $showContents) {
            ContentsSheet(publication: publication) { link in
                showContents = false
                bridge.go(to: link)
            }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
        .sheet(isPresented: $showSettings) {
            AppearanceSheet()
                .presentationDetents([.medium, .large])
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
        .onChange(of: appearance.themeRaw) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.fontRaw) { bridge.submit(appearance.preferences) }
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
            if ReviewRequester.recordBookOpen() {
                ReviewRequester.markRequested()
                // Delay slightly so the reader is visible before the dialog.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    requestReview()
                }
            }
        }
        .onDisappear {
            stats.recordSession(bookID: book.id, startedAt: sessionStart, endedAt: Date())
        }
    }

    // MARK: - Highlights

    private func makeHighlight(withNote: Bool) {
        guard let locator = bridge.selectionLocator else { return }
        guard StoreManager.canAddHighlight(
            isPro: store.isPro,
            currentCount: highlightStore.highlights(for: book.id).count
        ) else {
            bridge.clearSelection()
            showPaywall = true
            return
        }
        bridge.clearSelection()
        let highlight = highlightStore.add(
            bookID: book.id,
            locator: locator,
            color: highlightColor
        )
        refreshDecorations()
        if withNote {
            noteTarget = highlight
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
                Text("\(Int((progression * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.bar, in: Capsule())
                    .padding(.bottom, 12)
            }
        }
        .transition(.opacity)
    }
}

/// Table of contents.
private struct ContentsSheet: View {
    let publication: Publication
    let onSelect: (ReadiumShared.Link) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var links: [ReadiumShared.Link] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Group {
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
                            onSelect(entry.item)
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
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                            for offset in offsets {
                                store.remove(items[offset].id)
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
                        if purchases.isPro {
                            ShareLink(
                                item: store.exportMarkdown(for: book),
                                preview: SharePreview("\(book.title) — Highlights")
                            ) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Export as Markdown")
                            .simultaneousGesture(TapGesture().onEnded {
                                if ReviewRequester.recordExport() {
                                    ReviewRequester.markRequested()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        requestReview()
                                    }
                                }
                            })
                        } else {
                            Button {
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
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: purchases)
            }
        }
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
    @Environment(\.dismiss) private var dismiss

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

                Section("Font") {
                    Picker("Font", selection: $appearance.fontRaw) {
                        ForEach(AppearanceStore.ReaderFont.allCases) { font in
                            Text(font.rawValue).tag(font.rawValue)
                        }
                    }

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
                }

                Section("Layout") {
                    Picker("Columns", selection: $appearance.columnsRaw) {
                        ForEach(AppearanceStore.ReaderColumns.allCases) { columns in
                            Text(columns.rawValue).tag(columns.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Scroll Mode", isOn: $appearance.scrollEnabled)

                    Stepper(
                        value: $appearance.lineHeight,
                        in: 0 ... AppearanceStore.lineHeightRange.upperBound,
                        step: AppearanceStore.lineHeightStep
                    ) {
                        HStack {
                            Text("Line Height")
                            Spacer()
                            Text(appearance.lineHeight > 0
                                ? String(format: "%.1f", appearance.lineHeight)
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
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
