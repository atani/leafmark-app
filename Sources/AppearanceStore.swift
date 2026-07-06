import Foundation
import SwiftUI
import ReadiumNavigator

/// Reader appearance settings, persisted across launches.
@MainActor
final class AppearanceStore: ObservableObject {
    enum ReaderTheme: String, CaseIterable, Identifiable {
        case light, sepia, dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .light: return "Light"
            case .sepia: return "Sepia"
            case .dark: return "Dark"
            }
        }

        var readiumTheme: Theme {
            switch self {
            case .light: return .light
            case .sepia: return .sepia
            case .dark: return .dark
            }
        }
    }

    enum ReaderFont: String, CaseIterable, Identifiable {
        case publisher = "Publisher"
        case serif = "Serif"
        case sansSerif = "Sans Serif"
        case georgia = "Georgia"
        case palatino = "Palatino"

        var id: String { rawValue }

        var fontFamily: FontFamily? {
            switch self {
            case .publisher: return nil
            case .serif: return .serif
            case .sansSerif: return .sansSerif
            case .georgia: return .georgia
            case .palatino: return .palatino
            }
        }
    }

    enum ReaderColumns: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case one = "1"
        case two = "2"

        var id: String { rawValue }

        var columnCount: ColumnCount {
            switch self {
            case .auto: return .auto
            case .one: return .one
            case .two: return .two
            }
        }
    }

    @AppStorage("reader.theme") var themeRaw: String = ReaderTheme.light.rawValue
    @AppStorage("reader.fontSize") var fontSize: Double = 1.0
    @AppStorage("reader.font") var fontRaw: String = ReaderFont.publisher.rawValue
    // 1.0 keeps the publisher's weight (sent as nil so publisher CSS wins).
    @AppStorage("reader.fontWeight") var fontWeight: Double = 1.0
    @AppStorage("reader.columns") var columnsRaw: String = ReaderColumns.auto.rawValue
    @AppStorage("reader.scroll") var scrollEnabled: Bool = false
    /// 0 keeps the publisher's line height; otherwise 1.0...2.0.
    @AppStorage("reader.lineHeight") var lineHeight: Double = 0
    /// Page margins factor, 0.5...2.0.
    @AppStorage("reader.pageMargins") var pageMargins: Double = 1.0

    var columns: ReaderColumns {
        ReaderColumns(rawValue: columnsRaw) ?? .auto
    }

    var theme: ReaderTheme {
        get { ReaderTheme(rawValue: themeRaw) ?? .light }
        set { themeRaw = newValue.rawValue; objectWillChange.send() }
    }

    var font: ReaderFont {
        get { ReaderFont(rawValue: fontRaw) ?? .publisher }
        set { fontRaw = newValue.rawValue; objectWillChange.send() }
    }

    /// Picker tag prefix for user-imported fonts (FontStore). The rest of
    /// the tag is the font's family name, used directly as the CSS family.
    static let customFontPrefix = "custom:"

    /// Resolves the selected font, whether built-in or user-imported.
    var selectedFontFamily: FontFamily? {
        if fontRaw.hasPrefix(Self.customFontPrefix) {
            return FontFamily(rawValue: String(fontRaw.dropFirst(Self.customFontPrefix.count)))
        }
        return font.fontFamily
    }

    static let fontSizeRange: ClosedRange<Double> = 0.7 ... 2.0
    static let fontSizeStep: Double = 0.1

    func adjustFontSize(by delta: Double) {
        fontSize = (fontSize + delta).clamped(to: Self.fontSizeRange)
        objectWillChange.send()
    }

    static let lineHeightRange: ClosedRange<Double> = 1.0 ... 2.0
    static let lineHeightStep: Double = 0.1
    static let pageMarginsRange: ClosedRange<Double> = 0.5 ... 2.0
    static let pageMarginsStep: Double = 0.25
    // Readium supports 0.0–2.5 (1.0 = publisher weight); below 0.5 is
    // illegibly thin, so the UI stops there.
    static let fontWeightRange: ClosedRange<Double> = 0.5 ... 2.5
    static let fontWeightStep: Double = 0.25

    var preferences: EPUBPreferences {
        EPUBPreferences(
            columnCount: columns.columnCount,
            fontFamily: selectedFontFamily,
            fontSize: fontSize,
            // nil keeps the publisher's font weight untouched.
            fontWeight: fontWeight != 1.0 ? fontWeight : nil,
            // Readium only honors lineHeight when publisher styles are off.
            lineHeight: lineHeight > 0 ? lineHeight : nil,
            pageMargins: pageMargins,
            publisherStyles: lineHeight > 0 ? false : nil,
            scroll: scrollEnabled,
            theme: theme.readiumTheme
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
