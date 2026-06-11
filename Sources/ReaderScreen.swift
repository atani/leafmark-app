import SwiftUI
import ReadiumShared
import ReadiumNavigator

/// Full-screen reading experience: navigator + tap-to-toggle chrome,
/// table of contents and appearance settings.
struct ReaderScreen: View {
    let book: Book
    let publication: Publication
    @ObservedObject var library: LibraryStore
    @EnvironmentObject private var appearance: AppearanceStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var bridge = NavigatorBridge()
    @State private var chromeVisible = true
    @State private var showContents = false
    @State private var showSettings = false
    @State private var progression: Double?

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
        .sheet(isPresented: $showSettings) {
            AppearanceSheet()
                .presentationDetents([.height(320)])
                .onDisappear {
                    bridge.submit(appearance.preferences)
                }
        }
        .onChange(of: appearance.themeRaw) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.fontRaw) { bridge.submit(appearance.preferences) }
        .onChange(of: appearance.fontSize) { bridge.submit(appearance.preferences) }
        .onAppear { library.markOpened(book) }
    }

    private var chrome: some View {
        VStack {
            HStack {
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

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("Appearance")

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
