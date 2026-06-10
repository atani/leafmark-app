import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = ReaderModel()
    @State private var showImporter = false

    private var isReaderPresented: Binding<Bool> {
        Binding(
            get: { model.publication != nil },
            set: { if !$0 { model.publication = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Day 0 spike: Readium で EPUB を開いて読めるか")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if model.isOpening {
                    ProgressView("解析中...")
                } else {
                    Button("EPUB を開く") {
                        showImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .navigationTitle("EPUB Reader Spike")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.epub]
            ) { result in
                switch result {
                case .success(let url):
                    Task { await model.open(pickedURL: url) }
                case .failure(let error):
                    model.errorMessage = error.localizedDescription
                }
            }
            .fullScreenCover(isPresented: isReaderPresented) {
                if let publication = model.publication {
                    NavigationStack {
                        ReaderView(publication: publication)
                            .ignoresSafeArea()
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("閉じる") {
                                        model.publication = nil
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
}
