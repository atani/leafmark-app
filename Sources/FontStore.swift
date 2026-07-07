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
    /// font-family and the label shown in the font picker. Sanitized at
    /// import time so it is safe to interpolate into CSS.
    let familyName: String
    /// CSS font-weight (100–900) derived from the font's traits, when the
    /// file carries them. Optional for catalogs written by older builds.
    let cssWeight: Int?
    /// Whether the face is italic, when the file says so.
    let italic: Bool?
}

/// Manages user-imported reader fonts.
///
/// Font files live in Documents/Fonts (backed up with the library) next to
/// a small JSON catalog. When a book is opened, the selected family is
/// declared to the Readium navigator as a CSS @font-face rule — so a font
/// imported or selected while a book is open only takes effect the next
/// time a book is opened.
@MainActor
final class FontStore: ObservableObject {
    @Published private(set) var fonts: [CustomFont] = []

    private let fileManager = FileManager.default
    private let fontsDir: URL
    private let catalogURL: URL

    private static let allowedExtensions: Set<String> = ["ttf", "otf"]

    /// Embedding cost is paid per chapter (the face is inlined as a data:
    /// URI), so unbounded files would exhaust memory on big CJK fonts.
    static let maxFontFileSize = 10 * 1024 * 1024

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
    /// unsupported, too large, or unreadable. Importing a file identical to
    /// an already imported one returns the existing entry instead of
    /// duplicating it.
    @discardableResult
    func importFont(from url: URL) -> CustomFont? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        guard Self.allowedExtensions.contains(ext),
              let data = try? Data(contentsOf: url),
              data.count <= Self.maxFontFileSize
        else { return nil }

        let id = UUID().uuidString
        let destination = fontsDir.appendingPathComponent("\(id).\(ext)")
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            return nil
        }

        // Prefer the metadata embedded in the font; fall back to the file
        // name so a broken font is still identifiable (and removable). The
        // family name ends up inside CSS, so both paths are sanitized.
        let traits = Self.traits(of: destination)
        guard let family = Self.sanitizedFamilyName(
            traits?.familyName ?? url.deletingPathExtension().lastPathComponent
        ) else {
            try? fileManager.removeItem(at: destination)
            return nil
        }

        // Same family + identical bytes: this exact face is already in the
        // store, so hand back the existing entry.
        if let existing = fonts.first(where: {
            $0.familyName == family
                && (try? Data(contentsOf: fileURL(for: $0))) == data
        }) {
            try? fileManager.removeItem(at: destination)
            return existing
        }

        let font = CustomFont(
            id: id,
            fileName: destination.lastPathComponent,
            familyName: family,
            cssWeight: traits?.cssWeight,
            italic: traits?.italic
        )
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

    /// CSS @font-face declarations for the given family, covering all of
    /// its imported faces (regular/bold/italic files sharing one family
    /// name). Only the selected family is declared because the bytes are
    /// inlined into every chapter — embedding unselected fonts would
    /// multiply the cost for nothing.
    ///
    /// The font bytes are embedded as data: URIs instead of served URLs.
    /// Readium 3.8+ serves font files from a different origin than the
    /// book's pages (readium://assets vs readium://{uuid}) without CORS
    /// headers, and font fetches — unlike stylesheets or images — are
    /// CORS-gated by WebKit, so a URL-based @font-face never loads
    /// (readium/swift-toolkit#802). Embedding the bytes avoids the
    /// cross-origin fetch entirely.
    func fontFamilyDeclarations(for familyName: String?) -> [AnyHTMLFontFamilyDeclaration] {
        guard let familyName else { return [] }
        let faces = fonts
            .filter { $0.familyName == familyName }
            .compactMap { font -> DataURIFontFamilyDeclaration.Face? in
                guard let data = try? Data(contentsOf: fileURL(for: font)) else { return nil }
                return DataURIFontFamilyDeclaration.Face(
                    base64: data.base64EncodedString(),
                    format: font.fileName.lowercased().hasSuffix(".otf") ? "font/otf" : "font/ttf",
                    cssWeight: font.cssWeight,
                    italic: font.italic
                )
            }
        guard !faces.isEmpty else { return [] }
        return [
            DataURIFontFamilyDeclaration(
                fontFamily: FontFamily(rawValue: familyName),
                faces: faces
            )
            .eraseToAnyHTMLFontFamilyDeclaration(),
        ]
    }

    /// Family name and face traits read from the font file via CoreText.
    private static func traits(of url: URL) -> (familyName: String?, cssWeight: Int?, italic: Bool?)? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let first = descriptors.first
        else { return nil }

        let familyName = CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String

        var cssWeight: Int?
        var italic: Bool?
        if let traits = CTFontDescriptorCopyAttribute(first, kCTFontTraitsAttribute) as? [CFString: Any] {
            if let weight = traits[kCTFontWeightTrait] as? Double {
                cssWeight = Self.cssWeight(fromNormalizedWeight: weight)
            }
            if let symbolic = traits[kCTFontSymbolicTrait] as? UInt32 {
                italic = CTFontSymbolicTraits(rawValue: symbolic).contains(.traitItalic)
            }
        }
        return (familyName, cssWeight, italic)
    }

    /// Maps CoreText's normalized weight (-1.0 ... 1.0, 0 = regular) to the
    /// CSS 100–900 scale, using the documented AppKit/UIKit anchor points.
    private static func cssWeight(fromNormalizedWeight weight: Double) -> Int {
        switch weight {
        case ..<(-0.7): return 100
        case ..<(-0.5): return 200
        case ..<(-0.25): return 300
        case ..<0.115: return 400
        case ..<0.265: return 500
        case ..<0.35: return 600
        case ..<0.48: return 700
        case ..<0.59: return 800
        default: return 900
        }
    }

    /// Keeps only characters that are safe to interpolate into CSS and to
    /// show in the picker: letters and digits of any script (so CJK family
    /// names survive), whitespace, and a few name punctuation marks.
    /// Everything else — quotes, angle brackets, slashes, backslashes —
    /// is dropped so a hostile name table cannot break out of the injected
    /// <style> tag.
    static func sanitizedFamilyName(_ name: String) -> String? {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_.()&+,"))
        let cleaned = String(String.UnicodeScalarView(name.unicodeScalars.filter { allowed.contains($0) }))
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func load() {
        guard let data = try? Data(contentsOf: catalogURL),
              let decoded = try? JSONDecoder().decode([CustomFont].self, from: data)
        else { return }
        // Drop entries whose file vanished (e.g. a partial restore) and
        // entries whose file name is not a plain base name — the catalog
        // lives in a user-writable directory (Files app), so a tampered
        // fileName must not escape the Fonts directory.
        fonts = decoded.filter {
            !$0.fileName.contains("/")
                && !$0.fileName.contains("..")
                && fileManager.fileExists(atPath: fontsDir.appendingPathComponent($0.fileName).path)
        }
        if fonts.count != decoded.count {
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(fonts) else { return }
        try? data.write(to: catalogURL, options: .atomic)
    }
}

/// Declares a font family by embedding the font files as data: URIs in a
/// <style> tag (see FontStore.fontFamilyDeclarations(for:) for why).
struct DataURIFontFamilyDeclaration: HTMLFontFamilyDeclaration {
    struct Face {
        let base64: String
        /// IANA media type of the font file ("font/ttf" or "font/otf").
        let format: String
        /// CSS font-weight descriptor (100–900), when known.
        let cssWeight: Int?
        /// CSS font-style descriptor, when known.
        let italic: Bool?
    }

    let fontFamily: FontFamily
    let alternates: [FontFamily] = []
    let faces: [Face]

    func inject(in html: String, servingFile: (FileURL) throws -> any AbsoluteURL) throws -> String {
        guard let head = html.range(of: "</head>", options: [.caseInsensitive]) else {
            return html
        }
        // The family name is sanitized at import time; escaping here is
        // defense in depth for callers constructing declarations directly.
        let family = fontFamily.rawValue
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let css = faces
            .map { face in
                var descriptors = "font-family: \"\(family)\"; src: url(\"data:\(face.format);base64,\(face.base64)\");"
                if let weight = face.cssWeight {
                    descriptors += " font-weight: \(weight);"
                }
                if face.italic == true {
                    descriptors += " font-style: italic;"
                }
                return "@font-face { \(descriptors) }"
            }
            .joined(separator: "\n")
        var html = html
        html.insert(contentsOf: "<style type=\"text/css\">\(css)</style>", at: head.lowerBound)
        return html
    }
}
