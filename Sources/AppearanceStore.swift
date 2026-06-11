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

    @AppStorage("reader.theme") var themeRaw: String = ReaderTheme.light.rawValue
    @AppStorage("reader.fontSize") var fontSize: Double = 1.0
    @AppStorage("reader.font") var fontRaw: String = ReaderFont.publisher.rawValue

    var theme: ReaderTheme {
        get { ReaderTheme(rawValue: themeRaw) ?? .light }
        set { themeRaw = newValue.rawValue; objectWillChange.send() }
    }

    var font: ReaderFont {
        get { ReaderFont(rawValue: fontRaw) ?? .publisher }
        set { fontRaw = newValue.rawValue; objectWillChange.send() }
    }

    static let fontSizeRange: ClosedRange<Double> = 0.7 ... 2.0
    static let fontSizeStep: Double = 0.1

    func adjustFontSize(by delta: Double) {
        fontSize = (fontSize + delta).clamped(to: Self.fontSizeRange)
        objectWillChange.send()
    }

    var preferences: EPUBPreferences {
        EPUBPreferences(
            fontFamily: font.fontFamily,
            fontSize: fontSize,
            theme: theme.readiumTheme
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
