import CoreText
import Foundation
import ReadiumNavigator
import ReadiumShared

/// A user-imported reader font (.ttf / .otf).
struct CustomFont: Codable, Identifiable, Equatable {
    let id: String
    /// File name inside the Fonts directory ("<id>.<ext>").
    let fileName: String
    /// Family name embedded in the font file; doubles as the CSS
    /// font-family and the label shown in the font picker.
    let familyName: String
}

/// Manages user-imported reader fonts.
///
/// Font files live in Documents/Fonts (backed up with the library) next to
/// a small JSON catalog. When a book is opened, every imported font is
/// declared to the Readium navigator as a CSS @font-face rule — so a font
/// imported while a book is open only becomes available the next time a
/// book is opened.
@MainActor
final class FontStore: ObservableObject {
    @Published private(set) var fonts: [CustomFont] = []

    private let fileManager = FileManager.default
    private let fontsDir: URL
    private let catalogURL: URL

    private static let allowedExtensions: Set<String> = ["ttf", "otf"]

    /// - Parameter directory: Base directory for storage. Defaults to the
    ///   user's Documents; tests inject a temporary directory.
    init(directory: URL? = nil) {
        let base = directory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fontsDir = base.appendingPathComponent("Fonts", isDirectory: true)
        catalogURL = fontsDir.appendingPathComponent("fonts.json")
        try? fileManager.createDirectory(at: fontsDir, withIntermediateDirectories: true)
        load()
    }

    /// Copies a .ttf/.otf into the store. Returns nil when the file type is
    /// unsupported or the copy fails.
    @discardableResult
    func importFont(from url: URL) -> CustomFont? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        guard Self.allowedExtensions.contains(ext) else { return nil }

        let id = UUID().uuidString
        let destination = fontsDir.appendingPathComponent("\(id).\(ext)")
        do {
            try fileManager.copyItem(at: url, to: destination)
        } catch {
            return nil
        }

        // Prefer the family name embedded in the font; fall back to the file
        // name so a broken font is still identifiable (and removable).
        let family = Self.familyName(of: destination)
            ?? url.deletingPathExtension().lastPathComponent
        let font = CustomFont(id: id, fileName: destination.lastPathComponent, familyName: family)
        fonts.append(font)
        save()
        return font
    }

    func remove(_ font: CustomFont) {
        try? fileManager.removeItem(at: fileURL(for: font))
        fonts.removeAll { $0.id == font.id }
        save()
    }

    func fileURL(for font: CustomFont) -> URL {
        fontsDir.appendingPathComponent(font.fileName)
    }

    /// CSS @font-face declarations for every imported font, grouped by
    /// family so multi-face families (separate regular/bold files sharing
    /// one family name) form a single declaration.
    ///
    /// The font bytes are embedded as data: URIs instead of served URLs.
    /// Readium 3.8+ serves font files from a different origin than the
    /// book's pages (readium://assets vs readium://{uuid}) without CORS
    /// headers, and font fetches — unlike stylesheets or images — are
    /// CORS-gated by WebKit, so a URL-based @font-face never loads
    /// (readium/swift-toolkit#802). Embedding the bytes avoids the
    /// cross-origin fetch entirely.
    var fontFamilyDeclarations: [AnyHTMLFontFamilyDeclaration] {
        Dictionary(grouping: fonts, by: \.familyName)
            .compactMap { family, fonts in
                let faces = fonts.compactMap { font -> DataURIFontFamilyDeclaration.Face? in
                    guard let data = try? Data(contentsOf: fileURL(for: font)) else { return nil }
                    let format = font.fileName.lowercased().hasSuffix(".otf") ? "font/otf" : "font/ttf"
                    return DataURIFontFamilyDeclaration.Face(
                        base64: data.base64EncodedString(),
                        format: format
                    )
                }
                guard !faces.isEmpty else { return nil }
                return DataURIFontFamilyDeclaration(
                    fontFamily: FontFamily(rawValue: family),
                    faces: faces
                )
                .eraseToAnyHTMLFontFamilyDeclaration()
            }
    }

    private static func familyName(of url: URL) -> String? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let first = descriptors.first,
              let name = CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String
        else { return nil }
        return name
    }

    private func load() {
        guard let data = try? Data(contentsOf: catalogURL),
              let decoded = try? JSONDecoder().decode([CustomFont].self, from: data)
        else { return }
        // Drop entries whose file vanished (e.g. a partial restore).
        fonts = decoded.filter {
            fileManager.fileExists(atPath: fontsDir.appendingPathComponent($0.fileName).path)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(fonts) else { return }
        try? data.write(to: catalogURL, options: .atomic)
    }
}

/// Declares a font family by embedding the font files as data: URIs in a
/// <style> tag (see FontStore.fontFamilyDeclarations for why).
struct DataURIFontFamilyDeclaration: HTMLFontFamilyDeclaration {
    struct Face {
        let base64: String
        /// IANA media type of the font file ("font/ttf" or "font/otf").
        let format: String
    }

    let fontFamily: FontFamily
    let alternates: [FontFamily] = []
    let faces: [Face]

    func inject(in html: String, servingFile: (FileURL) throws -> any AbsoluteURL) throws -> String {
        guard let head = html.range(of: "</head>", options: [.caseInsensitive]) else {
            return html
        }
        let css = faces
            .map {
                "@font-face { font-family: \"\(fontFamily.rawValue)\"; src: url(\"data:\($0.format);base64,\($0.base64)\"); }"
            }
            .joined(separator: "\n")
        var html = html
        html.insert(contentsOf: "<style type=\"text/css\">\(css)</style>", at: head.lowerBound)
        return html
    }
}
