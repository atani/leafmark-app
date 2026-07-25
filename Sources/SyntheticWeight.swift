import Foundation
import ReadiumNavigator
import ReadiumShared

/// Synthetic font weight applied on top of Readium's native `fontWeight`.
///
/// Readium maps the `fontWeight` preference to the CSS `font-weight` property.
/// WebKit can only satisfy `font-weight` by picking a heavier *face*, so a
/// font shipped with a single (Regular) face shows no change at all — WebKit
/// does not synthesize bolding. Multi-face fonts (e.g. Georgia) do bold, but
/// only by snapping to their real Bold face. MobileRead readers expect a
/// gradual, programmatic weight that applies to *any* font (issue #22).
///
/// To provide that, this adds a `-webkit-text-stroke` outline around the
/// glyphs, which thickens every face uniformly and continuously. It sits on
/// top of the native `fontWeight` preference (which is left untouched, so real
/// Bold faces still engage).
///
/// Constraints:
/// - A stroke can only *add* ink, so it thickens but never thins. Weights at
///   or below the 1.0 default therefore produce no stroke; thinning is out of
///   scope.
/// - The width is expressed in `em` so it tracks the font size.
/// - The stroke color is `currentColor`, so it matches each element's own text
///   color and stays correct across the light / sepia / dark themes without
///   knowing the palette.
enum SyntheticWeight {
    /// Weight at or below which no stroke is applied (the publisher default).
    static let neutralWeight = 1.0
    /// Upper bound of the weight multiplier (`AppearanceStore.fontWeightRange`).
    static let maxWeight = 2.5
    /// Stroke width, in em, reached at `maxWeight`. Tuned so 2.5x reads as a
    /// firm bold without the hollow, outlined look that heavier strokes give.
    static let maxStrokeEm = 0.035

    /// Stroke width in em for the given weight multiplier.
    ///
    /// Returns 0 at or below `neutralWeight`; above it, scales linearly to
    /// `maxStrokeEm` at `maxWeight`. The input is clamped so out-of-range
    /// values are handled defensively.
    static func strokeWidthEm(forWeight weight: Double) -> Double {
        let clamped = min(max(weight, neutralWeight), maxWeight)
        guard clamped > neutralWeight else { return 0 }
        let t = (clamped - neutralWeight) / (maxWeight - neutralWeight)
        return t * maxStrokeEm
    }

    /// The CSS rule that applies the synthetic stroke to all text, or `nil`
    /// when the weight is neutral (no stroke needed).
    ///
    /// The rule targets `body` and every descendant so it covers all fonts
    /// (publisher default, built-in, system, imported) regardless of which
    /// family is selected — it is a global text style, not a per-family one.
    static func css(forWeight weight: Double) -> String? {
        let em = strokeWidthEm(forWeight: weight)
        guard em > 0 else { return nil }
        let value = String(format: "%.4f", em)
        return "body, body * { -webkit-text-stroke: \(value)em currentColor; }"
    }

    /// Font-family name that carries the injector through Readium's
    /// per-resource declaration channel without ever entering the font stack.
    ///
    /// Readium only consults a declaration's `fontFamily` / `alternates` when
    /// that family is the selected one (`resolveFontStack`), but it calls
    /// `inject(in:servingFile:)` on *every* registered declaration for *every*
    /// HTML resource. A sentinel family that no user can select therefore
    /// rides that channel to inject the stroke into all resources while
    /// leaving font selection untouched.
    static let sentinelFamily = FontFamily(rawValue: "-leafmark-synthetic-weight")

    /// A declaration that injects the synthetic-weight stroke, or `nil` when
    /// the weight is neutral. Registered on the navigator alongside the
    /// imported-font declarations; the stroke is baked into each resource as
    /// it is served, so a weight change affecting the stroke takes effect the
    /// next time a book is opened (matching the imported-font lifecycle).
    static func declaration(forWeight weight: Double) -> AnyHTMLFontFamilyDeclaration? {
        guard let css = css(forWeight: weight) else { return nil }
        return Declaration(css: css).eraseToAnyHTMLFontFamilyDeclaration()
    }

    /// `id` of the `<style>` element the live updater owns.
    static let liveStyleElementID = "leafmark-synthetic-weight"

    /// JavaScript that creates or rewrites the stroke rule in the document that
    /// is already displayed.
    ///
    /// The serve-time declaration is baked in when a resource loads, so it
    /// cannot change the pages currently on screen. Every EPUB spread lives in
    /// its own document, so the script runs against each of them via the
    /// navigator, and an empty rule (neutral weight) is written rather than
    /// removing the element, which keeps the update idempotent.
    static func liveUpdateScript(forWeight weight: Double) -> String {
        let rule = css(forWeight: weight) ?? ""
        // The rule is app-controlled (a formatted number and static text), but
        // it still crosses into JS as a string literal, so encode it as JSON.
        let encoded = String(
            data: (try? JSONSerialization.data(withJSONObject: [rule], options: []))
                ?? Data("[\"\"]".utf8),
            encoding: .utf8
        ) ?? "[\"\"]"
        return """
        (function() {
          var rule = \(encoded)[0];
          var id = "\(liveStyleElementID)";
          var el = document.getElementById(id);
          if (!el) {
            el = document.createElement("style");
            el.id = id;
            el.type = "text/css";
            document.head.appendChild(el);
          }
          el.textContent = rule;
        })();
        """
    }

    private struct Declaration: HTMLFontFamilyDeclaration {
        let css: String
        var fontFamily: FontFamily { SyntheticWeight.sentinelFamily }
        var alternates: [FontFamily] { [] }

        /// Inserts a `<style>` carrying the stroke rule immediately before
        /// `</head>`, so it lands after Readium's stylesheets and wins. The
        /// CSS is entirely app-controlled (a formatted number and static
        /// text), so there is nothing to escape. `servingFile` is unused: the
        /// stroke references no font files.
        func inject(in html: String, servingFile: (FileURL) throws -> any AbsoluteURL) throws -> String {
            guard let range = html.range(of: "</head>", options: .caseInsensitive) else {
                return html
            }
            var result = html
            result.insert(
                contentsOf: "<style type=\"text/css\">\(css)</style>",
                at: range.lowerBound
            )
            return result
        }
    }
}
