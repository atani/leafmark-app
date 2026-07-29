import XCTest
@testable import Leafmark

/// Readium はページ送りをビューポート幅ぴったりの scroll で行い、着地点も
/// ビューポート幅の倍数へ snap する（swift-toolkit `utils.js` の `scrollRight`
/// / `snapOffset`）。一方 CSS の段組みは「段の幅 + 段間」ずつ進む。段間を
/// 0 以外にすると 1 ページ送るたびに段間ぶんだけ本文が先へ行き、ずれが
/// 累積して 2 ページ分が同時に見える。章が変わると resource が変わって
/// scroll がリセットされるので、症状は「章の頭で直り、読み進めると再発する」
/// という形になる（MobileRead t=374295 post #37）。
///
/// Chromium で実測した値: ビューポート 1280px・段間 30px のとき段のピッチは
/// 1310px になり、10 ページで 300px ずれる。段間 0 なら 0px のまま。
final class ReaderPaginationTests: XCTestCase {

    /// 1 ページ送るごとに生じる本文のずれ（px）。
    private func drift(afterPageTurns turns: Int, columnGap: Double) -> Double {
        Double(turns) * columnGap
    }

    func testColumnGapIsZeroSoPagesDoNotDrift() {
        XCTAssertEqual(
            ReaderView.columnGap, 0,
            "段間を 0 以外にすると Readium のページ送りと段組みのピッチがずれる"
        )
    }

    func testNoDriftAccumulatesOverAChapter() {
        // 1 章ぶん読み進めても本文の左端は動かない。
        XCTAssertEqual(drift(afterPageTurns: 30, columnGap: ReaderView.columnGap), 0)
    }

    func testDriftFormulaCatchesANonZeroGap() {
        // 回帰したときにどれだけ壊れるかを固定しておく（30px 段間 = 10 ページで
        // iPad の画面 1/4 ぶん）。
        XCTAssertEqual(drift(afterPageTurns: 10, columnGap: 30), 300)
    }
}
