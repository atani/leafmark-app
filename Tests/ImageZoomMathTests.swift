import XCTest
import UIKit
@testable import Leafmark

/// ImageZoomMath は UIScrollView に依存しない純粋なレイアウト計算なので、
/// 倍率と中央寄せ inset の境界条件をここで固定する。
final class ImageZoomMathTests: XCTestCase {

    // MARK: - fitScale

    func testFitScaleUsesWidthWhenWidthIsMoreConstrained() {
        // 横長画像を縦長画面に収める → 幅が律速。
        let scale = ImageZoomMath.fitScale(
            imageSize: CGSize(width: 1000, height: 500),
            boundsSize: CGSize(width: 400, height: 800)
        )
        XCTAssertEqual(scale, 0.4, accuracy: 0.0001, "min(400/1000, 800/500) = 0.4")
    }

    func testFitScaleUsesHeightWhenHeightIsMoreConstrained() {
        let scale = ImageZoomMath.fitScale(
            imageSize: CGSize(width: 500, height: 1000),
            boundsSize: CGSize(width: 400, height: 800)
        )
        XCTAssertEqual(scale, 0.8, accuracy: 0.0001, "min(400/500, 800/1000) = 0.8")
    }

    func testFitScaleUpscalesSmallImage() {
        // 画面より小さい画像は 1 を超える倍率で fit（拡大表示）される。
        let scale = ImageZoomMath.fitScale(
            imageSize: CGSize(width: 100, height: 100),
            boundsSize: CGSize(width: 400, height: 800)
        )
        XCTAssertEqual(scale, 4, accuracy: 0.0001)
    }

    func testFitScaleFallsBackToOneForDegenerateSizes() {
        XCTAssertEqual(ImageZoomMath.fitScale(imageSize: .zero, boundsSize: CGSize(width: 400, height: 800)), 1)
        XCTAssertEqual(ImageZoomMath.fitScale(imageSize: CGSize(width: 100, height: 100), boundsSize: .zero), 1)
    }

    // MARK: - maxScale

    func testMaxScaleIsFitTimesFactorForLargeImages() {
        // 大きい画像（fit < 1）は fit の factor 倍まで拡大できる。
        XCTAssertEqual(ImageZoomMath.maxScale(fitScale: 0.5, factor: 3), 1.5, accuracy: 0.0001)
    }

    func testMaxScaleNeverBelowNativeResolution() {
        // fit*factor が 1 未満でも、等倍（原寸）までは拡大できる。
        XCTAssertEqual(ImageZoomMath.maxScale(fitScale: 0.2, factor: 3), 1, accuracy: 0.0001)
    }

    // MARK: - centeringInsets

    func testCenteringInsetsCenterSmallContentOnBothAxes() {
        let insets = ImageZoomMath.centeringInsets(
            contentSize: CGSize(width: 200, height: 400),
            boundsSize: CGSize(width: 400, height: 800)
        )
        XCTAssertEqual(insets.left, 100, accuracy: 0.0001)
        XCTAssertEqual(insets.right, 100, accuracy: 0.0001)
        XCTAssertEqual(insets.top, 200, accuracy: 0.0001)
        XCTAssertEqual(insets.bottom, 200, accuracy: 0.0001)
    }

    func testCenteringInsetsAreZeroWhenContentFillsAxis() {
        // ズームでコンテンツが画面より大きくなった軸は inset 0（端までスクロール可）。
        let insets = ImageZoomMath.centeringInsets(
            contentSize: CGSize(width: 600, height: 400),
            boundsSize: CGSize(width: 400, height: 800)
        )
        XCTAssertEqual(insets.left, 0, accuracy: 0.0001)
        XCTAssertEqual(insets.right, 0, accuracy: 0.0001)
        XCTAssertEqual(insets.top, 200, accuracy: 0.0001, "縦はまだ余白があるので中央寄せ")
        XCTAssertEqual(insets.bottom, 200, accuracy: 0.0001)
    }
}

@MainActor
final class ImageZoomResizeTests: XCTestCase {
    func testFittedImageRefitsWhenViewportChangesSize() {
        let viewer = makeViewer()
        XCTAssertEqual(viewer.zoomScale, 0.3, accuracy: 0.001)

        viewer.frame.size = CGSize(width: 700, height: 550)
        viewer.layoutIfNeeded()

        XCTAssertEqual(viewer.minimumZoomScale, 0.55, accuracy: 0.001)
        XCTAssertEqual(viewer.zoomScale, 0.55, accuracy: 0.001)
        XCTAssertEqual(viewer.contentOffset.x, -75, accuracy: 0.5)
        XCTAssertEqual(viewer.contentOffset.y, 0, accuracy: 0.5)

        viewer.frame.size = CGSize(width: 300, height: 500)
        viewer.layoutIfNeeded()

        XCTAssertEqual(viewer.zoomScale, 0.3, accuracy: 0.001)
        XCTAssertEqual(viewer.contentOffset.y, -100, accuracy: 0.5)
    }

    func testZoomedImageKeepsMagnificationAndFocalPointOnResize() {
        let viewer = makeViewer()
        viewer.zoomScale = 0.6
        viewer.contentOffset = CGPoint(x: 210, y: 80)
        viewer.layoutIfNeeded()

        viewer.frame.size = CGSize(width: 700, height: 550)
        viewer.layoutIfNeeded()

        XCTAssertEqual(viewer.zoomScale, 1.1, accuracy: 0.001)
        // The original viewport was centered at image coordinates (600, 550).
        XCTAssertEqual(viewer.contentOffset.x, 310, accuracy: 0.5)
        XCTAssertEqual(viewer.contentOffset.y, 330, accuracy: 0.5)
    }

    private func makeViewer() -> ImageZoomScrollView {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1000), format: format)
            .image { _ in }
        let viewer = ImageZoomScrollView(
            image: image,
            onDismissDragChanged: { _ in },
            onDismissDragEnded: { _ in }
        )
        viewer.frame.size = CGSize(width: 300, height: 500)
        viewer.layoutIfNeeded()
        return viewer
    }
}
