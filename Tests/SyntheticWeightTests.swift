import XCTest
import ReadiumNavigator
import ReadiumShared
@testable import Leafmark

final class SyntheticWeightTests: XCTestCase {
    // MARK: - strokeWidthEm mapping

    func testNoStrokeAtOrBelowDefault() {
        XCTAssertEqual(SyntheticWeight.strokeWidthEm(forWeight: 1.0), 0, "既定 (1.0) はストロークなし")
        XCTAssertEqual(SyntheticWeight.strokeWidthEm(forWeight: 0.5), 0, "細くする用途は対象外なので 1.0 未満もストロークなし")
    }

    func testStrokeGrowsAboveDefault() {
        let justAbove = SyntheticWeight.strokeWidthEm(forWeight: 1.05)
        XCTAssertGreaterThan(justAbove, 0, "1.0 を少しでも超えたらストロークが出る")
        XCTAssertLessThan(justAbove, SyntheticWeight.maxStrokeEm)

        let mid = SyntheticWeight.strokeWidthEm(forWeight: 1.5)
        XCTAssertGreaterThan(mid, justAbove, "ウェイトが増えるほど太くなる")
    }

    func testMaxWeightReachesMaxStroke() {
        XCTAssertEqual(
            SyntheticWeight.strokeWidthEm(forWeight: 2.5),
            SyntheticWeight.maxStrokeEm,
            accuracy: 1e-9,
            "上限 (2.5) で最大ストローク"
        )
    }

    func testLinearScaleAtMidpoint() {
        // 1.75 is the midpoint of 1.0...2.5, so the stroke is half of the max.
        XCTAssertEqual(
            SyntheticWeight.strokeWidthEm(forWeight: 1.75),
            SyntheticWeight.maxStrokeEm / 2,
            accuracy: 1e-9,
            "中間ウェイトは最大の半分に線形補間される"
        )
    }

    func testOutOfRangeWeightsAreClamped() {
        XCTAssertEqual(
            SyntheticWeight.strokeWidthEm(forWeight: 99),
            SyntheticWeight.maxStrokeEm,
            accuracy: 1e-9,
            "上限超えは上限に丸める"
        )
        XCTAssertEqual(SyntheticWeight.strokeWidthEm(forWeight: -5), 0, "下限未満は 0 に丸める")
    }

    // MARK: - css

    func testCSSIsNilAtDefault() {
        XCTAssertNil(SyntheticWeight.css(forWeight: 1.0), "既定では CSS を出さない")
        XCTAssertNil(SyntheticWeight.css(forWeight: 0.7))
    }

    func testCSSCarriesStrokeRuleAboveDefault() throws {
        let css = try XCTUnwrap(SyntheticWeight.css(forWeight: 2.5))
        XCTAssertTrue(css.contains("-webkit-text-stroke"), "合成ウェイトは text-stroke で表現する")
        XCTAssertTrue(css.contains("currentColor"), "テーマに追従するよう currentColor を使う")
        XCTAssertTrue(css.contains("em"), "フォントサイズに追従するよう em 単位")
        XCTAssertTrue(css.contains("body"), "全フォントを覆うよう body に適用する")
    }

    // MARK: - declaration injection

    /// Applies the declaration to a document and returns the resulting HTML.
    private func inject(
        _ declaration: AnyHTMLFontFamilyDeclaration,
        into html: String = "<html><head></head><body>x</body></html>"
    ) throws -> String {
        try declaration.inject(in: html) { _ in
            throw URLError(.badURL) // ストロークはフォントファイルを参照しない
        }
    }

    func testNoDeclarationAtDefault() {
        XCTAssertNil(SyntheticWeight.declaration(forWeight: 1.0), "既定では注入しない")
    }

    func testDeclarationInjectsStrokeBeforeHeadClose() throws {
        let declaration = try XCTUnwrap(SyntheticWeight.declaration(forWeight: 1.5))
        let html = try inject(declaration)

        XCTAssertTrue(html.contains("-webkit-text-stroke"), "ストローク規則が注入される")

        let styleRange = try XCTUnwrap(html.range(of: "<style"), "style タグが注入される")
        let headCloseRange = try XCTUnwrap(html.range(of: "</head>"))
        XCTAssertLessThan(
            styleRange.lowerBound,
            headCloseRange.lowerBound,
            "style は </head> の直前に入る"
        )
    }

    func testDeclarationUsesSentinelFamily() {
        let declaration = SyntheticWeight.declaration(forWeight: 2.0)
        XCTAssertEqual(
            declaration?.fontFamily,
            SyntheticWeight.sentinelFamily,
            "選択され得ないセンチネルファミリーで登録される"
        )
        XCTAssertEqual(declaration?.alternates.isEmpty, true, "フォントスタックに影響しないよう alternates は空")
    }

    func testDeclarationLeavesHTMLUnchangedWithoutHead() throws {
        let declaration = try XCTUnwrap(SyntheticWeight.declaration(forWeight: 2.0))
        let html = "<html><body>no head</body></html>"
        XCTAssertEqual(try inject(declaration, into: html), html, "head が無ければ何も注入しない")
    }
}
