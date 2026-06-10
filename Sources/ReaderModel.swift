import Foundation
import ReadiumShared
import ReadiumStreamer

// Day 0 spike: can Readium open and parse an arbitrary EPUB picked from Files?
@MainActor
final class ReaderModel: ObservableObject {
    @Published var publication: Publication?
    @Published var errorMessage: String?
    @Published var isOpening = false

    private let assetRetriever = ReadiumContext.assetRetriever
    private let opener = ReadiumContext.opener

    func open(pickedURL: URL) async {
        isOpening = true
        errorMessage = nil
        defer { isOpening = false }

        // Copy out of the security-scoped location so Readium can stream from
        // the file for the whole reading session.
        let accessing = pickedURL.startAccessingSecurityScopedResource()
        defer { if accessing { pickedURL.stopAccessingSecurityScopedResource() } }

        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(pickedURL.lastPathComponent)
        do {
            try? FileManager.default.removeItem(at: localURL)
            try FileManager.default.copyItem(at: pickedURL, to: localURL)
        } catch {
            errorMessage = "コピー失敗: \(error.localizedDescription)"
            return
        }

        guard let fileURL = FileURL(url: localURL) else {
            errorMessage = "FileURL に変換できません: \(localURL)"
            return
        }

        do {
            let asset = try await assetRetriever.retrieve(url: fileURL).get()
            let pub = try await opener.open(asset: asset, allowUserInteraction: false).get()
            publication = pub
        } catch {
            errorMessage = "開けませんでした: \(error)"
        }
    }
}
