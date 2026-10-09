import BNUIGallery
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions,
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = makeRootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    #if DEBUG
        /// The kit's own pages and nothing else: a host app shows its pages in its own gallery.
        private func makeRootViewController() -> UIViewController {
            let gallery = BNGalleryViewController(pages: BNUIGalleryPages.all())
            let navigationController = UINavigationController(rootViewController: gallery)
            // The catalogue asks for a large title; the bar has to allow one.
            navigationController.navigationBar.prefersLargeTitles = true
            // Straight to a page: simctl launch <UDID> com.oleksii-sukholita.bnui-gallery -OpenGallery Button
            if let title = BNGallery.launchPageTitle {
                gallery.openPage(titled: title)
            }
            return navigationController
        }
    #else
        /// `BNUIGallery` is Debug only unless an app enables its `GalleryInRelease` trait, and
        /// this app does not: a Release build has nothing to show.
        /// A plain label rather than a content-unavailable configuration, which arrives with iOS 17.
        private func makeRootViewController() -> UIViewController {
            let placeholder = UIViewController()
            placeholder.view.backgroundColor = .systemBackground
            let label = UILabel()
            label.text = "The gallery is Debug-only.\nRun the Debug configuration."
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            placeholder.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: placeholder.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: placeholder.view.centerYAnchor),
            ])
            return placeholder
        }
    #endif
}
