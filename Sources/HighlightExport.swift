import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
