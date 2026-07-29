import SwiftUI
import UIKit
import ReadiumShared
// ExperimentalTargetElement は Readium 3.9 が公開する SPI。タップされた要素
// （画像など）を `PointerEvent.targetElement` として受け取るために必要で、
// 公式 TestApp と同じ利用方法（フォーク不要）。
@_spi(ExperimentalTargetElement) import ReadiumNavigator

/// Bridges Readium's EPUB navigator into SwiftUI and exposes it to the
/// surrounding chrome through `NavigatorBridge`.
@MainActor
final class NavigatorBridge: ObservableObject {
    fileprivate(set) weak var navigator: EPUBNavigatorViewController?

    func go(to link: ReadiumShared.Link) {
        Task { _ = await navigator?.go(to: link) }
    }

    func go(to locator: Locator) {
        Task { _ = await navigator?.go(to: locator) }
    }

    func submit(_ preferences: EPUBPreferences) {
        navigator?.submitPreferences(preferences)
    }

    /// Applies the synthetic weight stroke to the pages already on screen.
    ///
    /// The serve-time declaration only reaches resources loaded after it is
    /// registered, so on its own the Font Weight control appears dead until
    /// the native `font-weight` happens to snap to a real Bold face — which is
    /// the behaviour reported on MobileRead. Rewriting the rule in the live
    /// document makes every step of the control visible immediately.
    func applySyntheticWeight(_ weight: Double) {
        guard let navigator else { return }
        let script = SyntheticWeight.liveUpdateScript(forWeight: weight)
        Task { _ = await navigator.evaluateJavaScript(script) }
    }

    /// Current text selection, if any.
    var selectionLocator: Locator? {
        navigator?.currentSelection?.locator
    }

    func clearSelection() {
        navigator?.clearSelection()
    }

    /// Declares the full set of highlight decorations for the open book.
    func applyHighlights(_ highlights: [Highlight], store: HighlightStore) {
        let decorations = highlights.compactMap { highlight -> Decoration? in
            guard let locator = store.locator(of: highlight) else { return nil }
            return Decoration(
                id: highlight.id,
                locator: locator,
                style: .highlight(tint: highlight.color.uiColor)
            )
        }
        navigator?.apply(decorations: decorations, in: "highlights")
    }
}

struct ReaderView: UIViewControllerRepresentable {
    let publication: Publication
    let initialLocation: Locator?
    let preferences: EPUBPreferences
    /// Builds the @font-face declarations for user-imported fonts
    /// (FontStore). Called once when the navigator is created — reading
    /// and base64-encoding font files is too expensive to run on every
    /// SwiftUI body evaluation. Fixed for the lifetime of the navigator:
    /// fonts imported while a book is open apply the next time a book is
    /// opened.
    let makeFontFamilyDeclarations: () -> [AnyHTMLFontFamilyDeclaration]
    let bridge: NavigatorBridge
    let onLocatorChange: (Locator) -> Void
    let onTap: () -> Void
    /// Called when the user taps a content image (`<img>` / `<svg>`), so the
    /// host can present a full-screen zoomable viewer. A plain tap that is not
    /// on an image falls through to `onTap` (chrome toggle) instead.
    let onImageTap: (ImageContentElement) -> Void
    /// Called when the user picks "Highlight" in the selection menu.
    let onHighlightSelection: () -> Void
    /// Called when the user picks "Add Note" in the selection menu.
    let onNoteSelection: () -> Void
    /// Called when the user taps an existing highlight decoration.
    let onHighlightActivated: (Decoration.Id) -> Void

    /// Vertical space kept above and below the page (pt).
    ///
    /// These are Readium's own defaults. Do not shrink them: the reservation
    /// is what makes a paginated column end cleanly at the page boundary.
    /// Cutting it to 20pt (for the landscape bands in issue #20) left the
    /// column taller than the space the pagination accounts for, so the next
    /// page's first line bled in under the current one — the "split page"
    /// report on MobileRead and the 1-star App Store review that called the
    /// app unusable. The effect scales with font size, which is why it looked
    /// intermittent. Landscape white space has to be solved another way.
    static let verticalContentInsetCompact: CGFloat = 34
    static let verticalContentInsetRegular: CGFloat = 62
    /// Text-block line-length cap (rem) fed to Readium CSS. Set high enough to
    /// never bind on the widest iPad so Auto / 2-column layouts fill the width.
    static let maxLineLength: Double = 120
    /// Gap between columns (px). Must stay 0, which is Readium's default.
    ///
    /// Readium turns pages by scrolling the web view in `window.innerWidth`
    /// steps and snapping to multiples of that width (`utils.js`
    /// `scrollRight` / `snapOffset`). CSS lays the columns out with a pitch of
    /// `columnWidth + columnGap`, and with one column per screen the column
    /// width already fills the viewport. Any non-zero gap therefore makes the
    /// columns advance faster than the scroll does, and the page lands short
    /// by one gap more on every turn: the text creeps sideways until two pages
    /// share the screen, then resets at the next chapter because each resource
    /// gets a fresh scroll container. A 30px gap drifts 300px — a quarter of an
    /// iPad screen — within ten page turns (MobileRead t=374295, post #37).
    ///
    /// The gap was added to keep the two columns apart in 2-column mode. That
    /// job belongs to `--RS__pageGutter`, which readium-css applies as body
    /// padding and which does not enter the pagination arithmetic.
    static let columnGap: Double = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(onLocatorChange: onLocatorChange)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            var config = EPUBNavigatorViewController.Configuration()
            config.preferences = preferences
            // Keep Readium's default vertical reservation. See the constants
            // above: shrinking it to reclaim the landscape bands (issue #20)
            // broke pagination, so correctness wins over the white space.
            config.contentInset = [
                .compact: (
                    top: Self.verticalContentInsetCompact,
                    bottom: Self.verticalContentInsetCompact
                ),
                .regular: (
                    top: Self.verticalContentInsetRegular,
                    bottom: Self.verticalContentInsetRegular
                ),
            ]
            // Let the text block span the full landscape width. Readium CSS
            // caps the body at `--RS__maxLineLength` (40rem ≈ 640pt) and
            // centres it with `margin: 0 auto`, which is what leaves the wide
            // white margins on the left/right of a landscape iPad. Raising the
            // cap lets Auto / 2-column layouts fill the screen; the existing
            // Margins setting (`--USER__pageMargins`) then controls the L/R
            // inset live. The column gap stays at Readium's 0 — see the
            // constant above for why. These are Reading System properties,
            // fixed for the navigator's lifetime — Readium exposes them only
            // through `readiumCSSRSProperties`, not the per-user
            // `EPUBPreferences` — so they are constants here, not live
            // settings. (readium-css ReadiumCSS-after.css:84,152.)
            config.readiumCSSRSProperties = CSSRSProperties(
                colGap: CSSPxLength(Self.columnGap),
                maxLineLength: CSSRemLength(Self.maxLineLength)
            )
            config.fontFamilyDeclarations += makeFontFamilyDeclarations()
            config.editingActions = EditingAction.defaultActions + [
                EditingAction(
                    title: "Highlight",
                    action: #selector(ReaderContainerViewController.highlightSelection)
                ),
                EditingAction(
                    title: "Add Note",
                    action: #selector(ReaderContainerViewController.annotateSelection)
                ),
            ]
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: initialLocation,
                config: config
            )
            navigator.delegate = context.coordinator
            bridge.navigator = navigator

            navigator.observeDecorationInteractions(inGroup: "highlights") { event in
                onHighlightActivated(event.decoration.id)
            }

            // Tap handling runs through Readium's InputObservable pipeline so
            // that a tap on a content image can be told apart from a tap on
            // plain text. Observers are consulted in registration order and the
            // first one that returns `true` consumes the event.
            let handleImageTap = onImageTap
            let handleTap = onTap
            // 1. Content image → open the zoom viewer and consume the tap.
            _ = navigator.addObserver(.activate { event in
                #if DEBUG
                NSLog("[ImageZoom] activate: targetElement=%@ content=%@",
                      String(describing: event.targetElement),
                      String(describing: event.targetElement?.content))
                #endif
                guard
                    let target = event.targetElement,
                    let image = target.content as? ImageContentElement
                else {
                    return false
                }
                #if DEBUG
                NSLog("[ImageZoom] IMAGE href=%@", image.embeddedLink.href)
                #endif
                handleImageTap(image)
                return true
            })
            // 2. Otherwise toggle the reading chrome (previous behaviour).
            _ = navigator.addObserver(.activate { _ in
                #if DEBUG
                NSLog("[ImageZoom] toggling chrome")
                #endif
                handleTap()
                return true
            })

            let container = ReaderContainerViewController(navigator: navigator)
            container.onHighlight = onHighlightSelection
            container.onNote = onNoteSelection
            return container
        } catch {
            return UIHostingController(
                rootView: Text("Could not open this book: \(String(describing: error))")
                    .padding()
            )
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, EPUBNavigatorDelegate {
        let onLocatorChange: (Locator) -> Void

        init(onLocatorChange: @escaping (Locator) -> Void) {
            self.onLocatorChange = onLocatorChange
        }

        func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
            onLocatorChange(locator)
        }

        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
            // Surfaced through the reading view itself; nothing actionable here.
        }

        // Note: tap handling (chrome toggle / image zoom) is wired through the
        // navigator's InputObservable observers in `makeUIViewController`, not
        // `didTapAt`, because that pipeline also exposes the tapped element.
    }
}

/// Hosts the navigator and receives custom editing-action selectors through
/// the responder chain (see ADR-0004).
final class ReaderContainerViewController: UIViewController {
    private let navigator: EPUBNavigatorViewController
    var onHighlight: (() -> Void)?
    var onNote: (() -> Void)?

    init(navigator: EPUBNavigatorViewController) {
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(navigator)
        navigator.view.frame = view.bounds
        navigator.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigator.view)
        navigator.didMove(toParent: self)
    }

    @objc func highlightSelection() {
        onHighlight?()
    }

    @objc func annotateSelection() {
        onNote?()
    }
}
