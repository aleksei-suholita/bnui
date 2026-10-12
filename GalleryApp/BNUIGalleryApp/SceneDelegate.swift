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
}
