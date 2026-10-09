#if (DEBUG || GalleryInRelease) && canImport(UIKit)
    import UIKit

    /// The gallery from a host app's side: opening it, and writing to the page on screen.
    ///
    /// ```swift
    /// // From the app's debug menu:
    /// BNGallery.present(pages, from: self)
    ///
    /// // Straight to a page at launch, with -OpenGallery "Reaction Pill":
    /// if let title = BNGallery.launchPageTitle {
    ///     BNGallery.present(pages, from: root, openingPageTitled: title, animated: false)
    /// }
    /// ```
    ///
    /// The app picks its own way in — a debug menu, a gesture of its own. To push the catalogue
    /// onto a navigation stack the app already has, it pushes ``BNGalleryViewController`` instead.
    public enum BNGallery {
        /// The page asked for at launch with `-OpenGallery <Title>`, or `nil`.
        ///
        /// ```
        /// xcrun simctl launch <device> <bundle id> -OpenGallery "Reaction Pill"
        /// ```
        public static var launchPageTitle: String? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let flag = arguments.firstIndex(of: "-OpenGallery"),
                  arguments.indices.contains(flag + 1)
            else { return nil }
            return arguments[flag + 1]
        }

        /// Presents the catalogue full screen, with a Close button that dismisses it.
        ///
        /// Full screen rather than a sheet: a sheet's swipe to dismiss would take the drags the
        /// demos are tested with. A page also switches the swipe back off while it is on screen.
        ///
        /// - Parameters:
        ///   - pages: The pages, in the order the catalogue lists them.
        ///   - presenter: The view controller to present from.
        ///   - title: A page to open straight away — usually ``launchPageTitle``. A title no page
        ///     has opens the catalogue.
        ///   - animated: Whether the presentation animates.
        public static func present(
            _ pages: [any BNGalleryPage],
            from presenter: UIViewController,
            openingPageTitled title: String? = nil,
            animated: Bool = true,
        ) {
            let catalogue = BNGalleryViewController(pages: pages)
            let navigation = UINavigationController(rootViewController: catalogue)
            // The catalogue asks for a large title; the bar has to allow one.
            navigation.navigationBar.prefersLargeTitles = true
            navigation.modalPresentationStyle = .fullScreen
            catalogue.onClose = { [weak navigation] in
                navigation?.dismiss(animated: true)
            }
            if let title {
                catalogue.openPage(titled: title)
            }
            presenter.present(navigation, animated: animated)
        }

        /// Writes a line to the event feed of the page on screen, and does nothing when no page
        /// is — so a demo's callbacks can report without knowing where they are shown.
        ///
        /// ```swift
        /// pill.onTap = { BNGallery.post("tap") }
        /// ```
        public static func post(_ event: String) {
            BNGalleryPageViewController.postToPageOnScreen(event)
        }
    }
#endif
