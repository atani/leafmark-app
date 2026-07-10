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

    /// Vertical space kept above and below the page (pt). Small enough to
    /// remove Readium's default 34/62pt bands, large enough to breathe on
    /// edge-to-edge iPads; the device safe area still wins where it is larger.
    static let verticalContentInset: CGFloat = 20
    /// Text-block line-length cap (rem) fed to Readium CSS. Set high enough to
    /// never bind on the widest iPad so Auto / 2-column layouts fill the width.
    static let maxLineLength: Double = 120
    /// Gap between columns in 2-column mode (px), so the columns don't touch
    /// (Readium's default `--RS__colGap` is 0).
    static let columnGap: Double = 30

    func makeCoordinator() -> Coordinator {
        Coordinator(onLocatorChange: onLocatorChange)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            var config = EPUBNavigatorViewController.Configuration()
            config.preferences = preferences
            // Trim the vertical space Readium reserves above and below the
            // page. Its defaults (34pt compact / 62pt regular) exist to clear
            // an app's own top/bottom bars, but Leafmark draws its chrome as a
            // transient overlay and lets the web view ignore the safe area, so
            // that reservation only shows up as dead white bands — the bottom
            // gap in portrait and the top/bottom bands in landscape (issue
            // #20). Readium still keeps the device safe area (notch / home
            // indicator) because it applies `max(safeArea, inset)`, so a small
            // inset removes the excess without letting text slip under the
            // notch.
            config.contentInset = [
                .compact: (top: Self.verticalContentInset, bottom: Self.verticalContentInset),
                .regular: (top: Self.verticalContentInset, bottom: Self.verticalContentInset),
            ]
            // Let the text block span the full landscape width. Readium CSS
            // caps the body at `--RS__maxLineLength` (40rem ≈ 640pt) and
            // centres it with `margin: 0 auto`, which is what leaves the wide
            // white margins on the left/right of a landscape iPad. Raising the
            // cap lets Auto / 2-column layouts fill the screen; the existing
            // Margins setting (`--USER__pageMargins`) then controls the L/R
            // inset live. A non-zero column gap keeps the two columns from
            // touching in 2-column mode. These are Reading System properties,
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
