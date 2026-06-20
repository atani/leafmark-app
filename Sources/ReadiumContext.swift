import Foundation
import ReadiumShared
import ReadiumStreamer

// Shared Readium dependencies (single instances for the whole app).
enum ReadiumContext {
    static let httpClient = DefaultHTTPClient()
    static let assetRetriever = AssetRetriever(httpClient: httpClient)
    static let opener = PublicationOpener(
        parser: DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        ),
        contentProtections: []
    )

    static func openPublication(at url: URL) async throws -> Publication {
        guard let fileURL = FileURL(url: url) else {
            throw ReaderError.invalidURL(url)
        }
        let asset = try await assetRetriever.retrieve(url: fileURL).get()
        return try await opener.open(asset: asset, allowUserInteraction: false).get()
    }
}

enum ReaderError: LocalizedError {
    case invalidURL(URL)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Not a readable file URL: \(url.lastPathComponent)"
        }
    }
}
