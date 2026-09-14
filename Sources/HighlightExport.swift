import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Plain-text highlight export with a stable filename for share targets.
struct HighlightExport: Transferable {
    let text: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { export in
            Data(export.text.utf8)
        }
        .suggestedFileName { export in
            export.fileName
        }
    }
}

/// Each presentation owns its file until the system share sheet has dismissed.
struct PreparedHighlightExport: Identifiable {
    let id = UUID()
    let url: URL

    init(export: HighlightExport) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent(export.fileName)
        do {
            try export.text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

struct HighlightShareSheet: UIViewControllerRepresentable {
    let file: PreparedHighlightExport
    let onCompletion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
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
    let export: HighlightExport
    @ObservedObject var purchases: StoreManager
    let onCompleted: () -> Void
    @State private var sharedFile: PreparedHighlightExport?
    @State private var pendingCleanup: PreparedHighlightExport?
    @State private var exportError = false
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Markdown preview")
                        .font(.headline)
                    Text("Save this file or share it with your notes app.")
                        .foregroundStyle(.secondary)
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
