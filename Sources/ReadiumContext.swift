import Foundation
import ReadiumShared
import ReadiumStreamer
import ReadiumAdapterGCDWebServer

// Shared Readium dependencies (single instances for the whole app).
enum ReadiumContext {
    static let httpClient = DefaultHTTPClient()
    static let assetRetriever = AssetRetriever(httpClient: httpClient)
    static let httpServer = GCDHTTPServer(assetRetriever: assetRetriever)
    static let opener = PublicationOpener(
        parser: DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        ),
        contentProtections: []
    )
}
