import Foundation
import ReadiumShared

/// Pure page-number math for the optional reader header/footer.
///
/// Readium's positions API yields synthetic ~1024-character "pages" — the
/// standard approximation of ADE (RMSDK) page numbers used by Readium-based
/// readers. This value type turns the flat position list plus the current
/// reading locator into the two figures the UI shows: pages left in the
/// current chapter (header) and "Page X of Y" (footer).
///
/// It carries no SwiftUI or navigator dependency so the boundary cases
/// (first/last page, single-page chapter, missing position, empty positions)
/// can be unit-tested directly.
struct PagePositionInfo: Equatable {
    /// Total number of synthetic pages in the book (1-based count).
    let totalPages: Int
    /// 1-based index of the current page within the whole book.
    let currentPage: Int
    /// Pages remaining after the current one within the current chapter (the
    /// reading-order resource). 0 on the last page of a chapter.
    let pagesLeftInChapter: Int

    /// Builds the page figures, or nil when there is nothing to show: the
    /// positions service was unavailable (empty list) or there is no current
    /// locator yet.
    init?(positions: [Locator], current: Locator?) {
        guard !positions.isEmpty, let current else { return nil }
        guard let index = Self.currentIndex(in: positions, for: current) else {
            return nil
        }

        totalPages = positions.count
        currentPage = index + 1

        // Positions are grouped by reading-order resource and laid out in
        // order, so a chapter is the contiguous run sharing one href.
        let chapterHref = positions[index].href
        let chapterIndices = positions.indices.filter { positions[$0].href == chapterHref }
        let offset = chapterIndices.firstIndex(of: index) ?? 0
        pagesLeftInChapter = max(0, chapterIndices.count - offset - 1)
    }

    /// Resolves the 0-based index of `current` within `positions`.
    ///
    /// Prefers the locator's explicit 1-based `position` (present when a
    /// positions service backs the navigator); falls back to the nearest
    /// position by `totalProgression` when it is missing.
    private static func currentIndex(in positions: [Locator], for current: Locator) -> Int? {
        if let position = current.locations.position,
           let index = positions.firstIndex(where: { $0.locations.position == position }) {
            return index
        }
        guard let target = current.locations.totalProgression else { return nil }
        var best: (index: Int, distance: Double)?
        for (index, locator) in positions.enumerated() {
            guard let progression = locator.locations.totalProgression else { continue }
            let distance = abs(progression - target)
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }
        return best?.index
    }

    /// Footer text, e.g. "Page 12 of 340".
    var footerText: String {
        "Page \(currentPage) of \(totalPages)"
    }

    /// Header text describing the pages left in the chapter, e.g.
    /// "8 pages left in this chapter", "1 page left in this chapter", or
    /// "Last page of this chapter" on the final page of the chapter.
    var chapterHeaderText: String {
        switch pagesLeftInChapter {
        case 0: return "Last page of this chapter"
        case 1: return "1 page left in this chapter"
        default: return "\(pagesLeftInChapter) pages left in this chapter"
        }
    }
}
