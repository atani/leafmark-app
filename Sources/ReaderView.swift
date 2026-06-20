import SwiftUI
import UIKit
import ReadiumShared
import ReadiumNavigator

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
    let bridge: NavigatorBridge
    let onLocatorChange: (Locator) -> Void
    let onTap: () -> Void
    /// Called when the user picks "Highlight" in the selection menu.
    let onHighlightSelection: () -> Void
    /// Called when the user picks "Add Note" in the selection menu.
    let onNoteSelection: () -> Void
    /// Called when the user taps an existing highlight decoration.
    let onHighlightActivated: (Decoration.Id) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLocatorChange: onLocatorChange, onTap: onTap)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            var config = EPUBNavigatorViewController.Configuration()
            config.preferences = preferences
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
        let onTap: () -> Void

        init(onLocatorChange: @escaping (Locator) -> Void, onTap: @escaping () -> Void) {
            self.onLocatorChange = onLocatorChange
            self.onTap = onTap
        }

        func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
            onLocatorChange(locator)
        }

        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
            // Surfaced through the reading view itself; nothing actionable here.
        }

        func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
            onTap()
        }
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
