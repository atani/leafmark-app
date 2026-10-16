import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// How highlights are arranged inside an exported Markdown file.
enum MarkdownExportLayout: String, CaseIterable, Identifiable {
    /// Reading order, the layout every export used before 1.19.
    case readingOrder
    /// One `##` heading per highlight color, each in reading order.
    case byColor

    /// UserDefaults key shared by the per-book and all-books export screens.
    static let storageKey = "export.markdownLayout"

    var id: Self { self }

    var label: String {
        switch self {
        case .readingOrder: "Reading Order"
        case .byColor: "By Color"
        }
    }
}

/// Markdown highlight export with a stable filename for share targets.
struct HighlightExport: Transferable {
    let text: String
    let fileName: String

    static let fileExtension = "md"

    /// Resolves to the system's Markdown type (`net.daringfireball.markdown`)
    /// so share targets such as Obsidian accept the file as a note.
    static let contentType: UTType =
        UTType(filenameExtension: fileExtension, conformingTo: .plainText) ?? .plainText

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: contentType) { export in
            Data(export.text.utf8)
        }
        .suggestedFileName { export in
            export.fileName
        }
    }
}

/// Each presentation owns its files until the system share sheet has dismissed.
struct PreparedHighlightExport: Identifiable {
    let id = UUID()
    let urls: [URL]
    private let directory: URL

    /// The first file. Single-book exports carry exactly one.
    var url: URL { urls[0] }

    init(export: HighlightExport) throws {
        try self.init(exports: [export])
    }

    /// Writes every export into one temporary directory. File names must be
    /// unique (see `HighlightStore.uniqueFileName`).
    init(exports: [HighlightExport]) throws {
        precondition(!exports.isEmpty, "An export needs at least one file")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
        var urls: [URL] = []
        do {
            for export in exports {
                let url = directory.appendingPathComponent(export.fileName)
                try export.text.write(to: url, atomically: true, encoding: .utf8)
                urls.append(url)
            }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
        self.urls = urls
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}

struct HighlightShareSheet: UIViewControllerRepresentable {
    let file: PreparedHighlightExport
    let onCompletion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: file.urls, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            DispatchQueue.main.async {
                onCompletion(completed && error == nil)
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ReadingNotesExportView: View {
    /// Rebuilds the export whenever the layout changes.
    let makeExport: (MarkdownExportLayout) -> HighlightExport
    @ObservedObject var purchases: StoreManager
    let onCompleted: () -> Void
    @AppStorage(MarkdownExportLayout.storageKey) private var layout = MarkdownExportLayout.readingOrder
    @State private var sharedFile: PreparedHighlightExport?
    @State private var pendingCleanup: PreparedHighlightExport?
    @State private var exportError = false
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let export = makeExport(layout)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Markdown preview")
                        .font(.headline)
                    Text("Save this file or share it with Obsidian or your notes app.")
                        .foregroundStyle(.secondary)
                    MarkdownLayoutPicker(layout: $layout)
                    Text(export.text)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        guard StoreManager.canExport(isPro: purchases.isPro, hasUsedFreeExport: purchases.hasUsedFreeExport) else {
                            showPaywall = true
                            return
                        }
                        do {
                            let file = try PreparedHighlightExport(export: export)
                            pendingCleanup = file
                            sharedFile = file
                        } catch {
                            exportError = true
                        }
                    } label: {
                        Label(purchases.isPro ? "Export Reading Notes" : (purchases.hasUsedFreeExport ? "Unlock Unlimited Export" : "Export Reading Notes — First Export Free"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    if !purchases.isPro && !purchases.hasUsedFreeExport {
                        Text("Canceling the share sheet keeps your free export available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Reading Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $sharedFile, onDismiss: {
                pendingCleanup?.cleanup()
                pendingCleanup = nil
            }) { file in
                HighlightShareSheet(file: file) { success in
                    // UIKit can dismiss before delivering its completion handler.
                    // Record success here, independently of SwiftUI's onDismiss.
                    if purchases.completeExport(success: success) {
                        onCompleted()
                    }
                    sharedFile = nil
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: purchases, context: .export)
            }
            .alert("Could Not Prepare Export", isPresented: $exportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your notes are safe. Please try again.")
            }
        }
    }
}

/// Exports every book with highlights at once, one Markdown file per book.
/// Pro only: the caller shows the paywall instead for free users, and this
/// flow never spends the free tier's single export.
struct AllHighlightsExportView: View {
    let books: [Book]
    @ObservedObject var purchases: StoreManager
    @EnvironmentObject private var highlights: HighlightStore
    @AppStorage(MarkdownExportLayout.storageKey) private var layout = MarkdownExportLayout.readingOrder
    @State private var sharedFile: PreparedHighlightExport?
    @State private var pendingCleanup: PreparedHighlightExport?
    @State private var exportError = false
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Only titles and counts here; the Markdown is built on export.
        let counts = highlights.activeHighlightCounts()
        let exportable = books.filter { counts[$0.id, default: 0] > 0 }
        NavigationStack {
            List {
                Section {
                    MarkdownLayoutPicker(layout: $layout)
                } footer: {
                    Text("Each book becomes its own Markdown file with front matter for Obsidian.")
                }
                Section {
                    if exportable.isEmpty {
                        Text("No highlights yet. Highlight a passage in any book to export it.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(exportable) { book in
                            let count = counts[book.id, default: 0]
                            LabeledContent {
                                Text(count == 1 ? "1 highlight" : "\(count) highlights")
                            } label: {
                                Label(book.title, systemImage: "doc.text")
                                    .lineLimit(2)
                            }
                        }
                    }
                } header: {
                    Text(exportable.count == 1 ? "1 file" : "\(exportable.count) files")
                }
                Section {
                    Button {
                        guard purchases.isPro else {
                            showPaywall = true
                            return
                        }
                        do {
                            let exports = highlights.exportFiles(for: books, layout: layout)
                            guard !exports.isEmpty else { return }
                            let file = try PreparedHighlightExport(exports: exports)
                            pendingCleanup = file
                            sharedFile = file
                        } catch {
                            exportError = true
                        }
                    } label: {
                        Label("Export All", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(exportable.isEmpty)
                }
            }
            .navigationTitle("Export All Highlights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $sharedFile, onDismiss: {
                pendingCleanup?.cleanup()
                pendingCleanup = nil
            }) { file in
                HighlightShareSheet(file: file) { _ in
                    sharedFile = nil
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: purchases, context: .exportAll)
            }
            .alert("Could Not Prepare Export", isPresented: $exportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your notes are safe. Please try again.")
            }
        }
    }
}

private struct MarkdownLayoutPicker: View {
    @Binding var layout: MarkdownExportLayout

    var body: some View {
        Picker("Arrange Highlights", selection: $layout) {
            ForEach(MarkdownExportLayout.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}
