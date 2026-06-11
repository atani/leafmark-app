import SwiftUI
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

    func submit(_ preferences: EPUBPreferences) {
        navigator?.submitPreferences(preferences)
    }
}

struct ReaderView: UIViewControllerRepresentable {
    let publication: Publication
    let initialLocation: Locator?
    let preferences: EPUBPreferences
    let bridge: NavigatorBridge
    let onLocatorChange: (Locator) -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLocatorChange: onLocatorChange, onTap: onTap)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            var config = EPUBNavigatorViewController.Configuration()
            config.preferences = preferences
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: initialLocation,
                config: config
            )
            navigator.delegate = context.coordinator
            bridge.navigator = navigator
            return navigator
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
