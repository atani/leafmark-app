import SwiftUI
import ReadiumShared
import ReadiumNavigator
import ReadiumAdapterGCDWebServer

struct ReaderView: UIViewControllerRepresentable {
    let publication: Publication

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: nil,
                config: EPUBNavigatorViewController.Configuration(),
                httpServer: ReadiumContext.httpServer
            )
            return navigator
        } catch {
            let fallback = UIHostingController(
                rootView: Text("Navigator 初期化失敗: \(String(describing: error))")
                    .padding()
            )
            return fallback
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
