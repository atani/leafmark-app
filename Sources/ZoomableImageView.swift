import SwiftUI
import UIKit
import ReadiumShared

// MARK: - Zoom math (pure, unit-tested)

/// 画像ズームビューアのレイアウト計算。UIScrollView 依存を持たない純粋関数に
/// 切り出してテスト可能にしている。
enum ImageZoomMath {
    /// `boundsSize` に `imageSize` をアスペクト比を保って収める倍率。
    /// これを最小ズーム倍率として使うと、画像が画面いっぱいに「fit」表示される。
    static func fitScale(imageSize: CGSize, boundsSize: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0,
              boundsSize.width > 0, boundsSize.height > 0
        else { return 1 }
        return min(boundsSize.width / imageSize.width,
                   boundsSize.height / imageSize.height)
    }

    /// 最大ズーム倍率。fit の `factor` 倍まで拡大できるが、少なくとも等倍
    /// （原寸ピクセル）までは拡大できるようにして、大きな画像の細部も見られる
    /// ようにする。
    static func maxScale(fitScale: CGFloat, factor: CGFloat = 3) -> CGFloat {
        max(fitScale * factor, 1)
    }

    /// スクロールビュー内でコンテンツを中央寄せするための contentInset。
    /// コンテンツが `boundsSize` より小さい軸では余白を均等に振り、大きい軸では
    /// 0 にする（＝端までスクロールできる）。
    static func centeringInsets(contentSize: CGSize, boundsSize: CGSize) -> UIEdgeInsets {
        let vertical = max(0, (boundsSize.height - contentSize.height) / 2)
        let horizontal = max(0, (boundsSize.width - contentSize.width) / 2)
        return UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

// MARK: - Full-screen viewer

/// 本文中の画像をタップしたときに開く全画面ビューア。
///
/// - ピンチズーム + パン（`UIScrollView` ベース）
/// - ダブルタップでズーム / 等倍をトグル
/// - 等倍時は下スワイプ、または右上のボタンで閉じる
struct ZoomableImageView: View {
    let publication: Publication
    let image: ImageContentElement

    @Environment(\.dismiss) private var dismiss
    @State private var uiImage: UIImage?
    @State private var didFail = false
    /// 下スワイプで閉じる操作中の縦オフセット（0 = 通常表示）。
    @State private var dragOffset: CGFloat = 0

    /// ドラッグ量に応じて背景を透過させ、閉じる操作を視覚的に伝える。
    private var backgroundOpacity: Double {
        let progress = min(Double(dragOffset) / 300, 0.6)
        return 1 - progress
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            content

            closeButton
        }
        .statusBarHidden()
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let uiImage {
            ZoomableScrollView(
                image: uiImage,
                onDismissDragChanged: { dragOffset = max(0, $0) },
                onDismissDragEnded: { shouldDismiss in
                    if shouldDismiss {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
                }
            )
            .ignoresSafeArea()
            .offset(y: dragOffset)
        } else if didFail {
            VStack(spacing: 12) {
                Image(systemName: "photo")
                    .font(.largeTitle)
                Text("This image could not be loaded.")
                    .font(.callout)
            }
            .foregroundStyle(.white.opacity(0.7))
        } else {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .accessibilityLabel("Close")
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
            Spacer()
        }
        // 閉じるボタンはドラッグに追従させず固定表示にする。
        .opacity(backgroundOpacity)
    }

    private func load() async {
        guard
            let resource = publication.get(image.embeddedLink),
            let data = try? await resource.read().get(),
            let loaded = UIImage(data: data)
        else {
            didFail = true
            return
        }
        uiImage = loaded
    }
}

// MARK: - UIScrollView-backed zoom container

/// `UIScrollView` によるピンチズーム + パンのコンテナ。ズーム倍率の管理・中央
/// 寄せ・ダブルタップズーム・等倍時の下スワイプ検出を担当する。
private struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage
    /// 下スワイプ中に縦移動量（>= 0）を通知する。
    let onDismissDragChanged: (CGFloat) -> Void
    /// 下スワイプ終了時に、閉じるべきか（しきい値超え or 速い）を通知する。
    let onDismissDragEnded: (Bool) -> Void

    func makeUIView(context: Context) -> ImageZoomScrollView {
        ImageZoomScrollView(
            image: image,
            onDismissDragChanged: onDismissDragChanged,
            onDismissDragEnded: onDismissDragEnded
        )
    }

    func updateUIView(_ uiView: ImageZoomScrollView, context: Context) {
        uiView.update(
            onDismissDragChanged: onDismissDragChanged,
            onDismissDragEnded: onDismissDragEnded
        )
    }
}

/// ズーム可能な単一画像を表示する `UIScrollView`。
final class ImageZoomScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private let imageView = UIImageView()
    private var onDismissDragChanged: (CGFloat) -> Void
    private var onDismissDragEnded: (Bool) -> Void
    private var hasConfiguredZoom = false

    init(
        image: UIImage,
        onDismissDragChanged: @escaping (CGFloat) -> Void,
        onDismissDragEnded: @escaping (Bool) -> Void
    ) {
        self.onDismissDragChanged = onDismissDragChanged
        self.onDismissDragEnded = onDismissDragEnded
        super.init(frame: .zero)

        delegate = self
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        backgroundColor = .clear
        bouncesZoom = true

        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let dismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        addGestureRecognizer(dismissPan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(
        onDismissDragChanged: @escaping (CGFloat) -> Void,
        onDismissDragEnded: @escaping (Bool) -> Void
    ) {
        self.onDismissDragChanged = onDismissDragChanged
        self.onDismissDragEnded = onDismissDragEnded
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 初回レイアウトで実寸が確定してから fit 倍率を計算する。
        if !hasConfiguredZoom, let image = imageView.image,
           bounds.width > 0, bounds.height > 0 {
            hasConfiguredZoom = true
            imageView.frame = CGRect(origin: .zero, size: image.size)
            contentSize = image.size
            let fit = ImageZoomMath.fitScale(imageSize: image.size, boundsSize: bounds.size)
            minimumZoomScale = fit
            maximumZoomScale = ImageZoomMath.maxScale(fitScale: fit)
            zoomScale = fit
        }
        centerImage()
    }

    /// 表示中の画像が等倍（fit）付近かどうか。下スワイプで閉じてよい状態の判定。
    private var isAtMinimumZoom: Bool {
        zoomScale <= minimumZoomScale * 1.05
    }

    private func centerImage() {
        contentInset = ImageZoomMath.centeringInsets(
            contentSize: imageView.frame.size,
            boundsSize: bounds.size
        )
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    // MARK: Gestures

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if isAtMinimumZoom {
            let target = min(minimumZoomScale * 3, maximumZoomScale)
            zoom(to: zoomRect(scale: target, center: gesture.location(in: imageView)), animated: true)
        } else {
            setZoomScale(minimumZoomScale, animated: true)
        }
    }

    /// 指定倍率・中心点でズームインするための矩形を求める。
    private func zoomRect(scale: CGFloat, center: CGPoint) -> CGRect {
        let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        // window 基準で指の移動量を測ることで、SwiftUI 側の .offset に追従しても
        // 座標フィードバックが起きないようにする。
        let translation = gesture.translation(in: nil)
        switch gesture.state {
        case .changed:
            onDismissDragChanged(max(0, translation.y))
        case .ended:
            let velocity = gesture.velocity(in: nil).y
            onDismissDragEnded(translation.y > 140 || velocity > 900)
        case .cancelled, .failed:
            onDismissDragEnded(false)
        default:
            break
        }
    }

    // MARK: UIGestureRecognizerDelegate

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 下スワイプでの dismiss は「等倍かつ縦方向優位のドラッグ」のときだけ開始。
        // ズーム中はスクロールビュー本来のパン（画像移動）を優先する。
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              pan.view === self, pan !== panGestureRecognizer
        else { return true }
        guard isAtMinimumZoom else { return false }
        let velocity = pan.velocity(in: self)
        return abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // dismiss 用パンとスクロールビュー標準ジェスチャの共存を許可する。
        true
    }
}
