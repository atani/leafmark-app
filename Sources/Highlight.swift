import SwiftUI
import UIKit

/// A saved highlight (optionally with a note) anchored to a Locator.
struct Highlight: Identifiable, Codable, Equatable {
    let id: String
    let bookID: String
    /// Position of the highlighted range, as a Readium Locator JSON string.
    var locatorJSON: String
    var colorRaw: String
    var note: String?
    var createdAt: Date
    /// Optional for decoding catalogs written before annotation sync existed.
    var updatedAt: Date? = nil
    /// A retained deletion marker used to propagate removals to other devices.
    var deletedAt: Date? = nil

    /// The highlighted text, extracted from the locator when created.
    var text: String

    var effectiveUpdatedAt: Date { updatedAt ?? createdAt }

    var color: HighlightColor {
        get { HighlightColor(rawValue: colorRaw) ?? .yellow }
        set { colorRaw = newValue.rawValue }
    }
}

enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow, green, blue, pink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .pink: return "Pink"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .pink: return .systemPink
        }
    }

    var color: Color { Color(uiColor) }
}
