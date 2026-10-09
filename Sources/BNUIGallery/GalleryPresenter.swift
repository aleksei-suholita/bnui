#if (DEBUG || GalleryInRelease) && canImport(UIKit)
    import BNUI
    import UIKit

    /// The stage of a page whose demo is presented rather than shown: a Present button, and the
    /// controller the page builds, presented over the gallery on every tap.
    ///
    /// The stage's appearance, text size and direction are overrides on the stage, and a presented
    /// controller hangs off the window, not the stage — so they are copied onto the controller
    /// before it goes up, or an alert would be judged in the app's look rather than the stage's.
    final class GalleryPresenterController: UIViewController {
        private let make: () -> UIViewController
        /// Carries the page's props for its knobs and reports to the stage's feed.
        private let carrier: GalleryCarrierView
        private let button = UIButton(configuration: .filled())

        init(subject: AnyObject, make: @escaping () -> UIViewController) {
            self.make = make
            carrier = GalleryCarrierView(subjects: [subject])
            super.init(nibName: nil, bundle: nil)
            var configuration = UIButton.Configuration.filled()
            configuration.title = "Present"
            configuration.image = UIImage(systemName: "arrow.up.forward.app")
            configuration.imagePadding = BNGallerySpacing.xs
            configuration.baseBackgroundColor = BNGalleryColor.accent
            configuration.cornerStyle = .capsule
            configuration.buttonSize = .large
            button.configuration = configuration
            button.addAction(UIAction { [weak self] _ in self?.presentDemo() }, for: .primaryActionTriggered)
            carrier.embed(button)
            carrier.onReset = { [weak self] in self?.dismissDemo() }
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func loadView() {
            view = carrier
        }

        private func presentDemo() {
            guard presentedViewController == nil else { return }
            let controller = make()
            applyEnvironment(to: controller)
            // A popover, or an action sheet on a regular-width screen, points at the button.
            if let popover = controller.popoverPresentationController {
                popover.sourceView = button
                popover.sourceRect = button.bounds
            }
            present(controller, animated: true) { [weak self, weak controller] in
                guard let self, let controller else { return }
                // Watched from inside: whichever way it leaves — a button, a swipe, its own
                // dismiss — its view leaves the window.
                GalleryDismissalWatch.attach(to: controller.view) { [weak self] in
                    self?.carrier.onGalleryEvent?("dismissed")
                }
            }
            carrier.onGalleryEvent?("presented")
        }

        private func dismissDemo() {
            guard presentedViewController != nil else { return }
            dismiss(animated: true)
        }

        private func applyEnvironment(to controller: UIViewController) {
            let environment = GalleryEnvironment.current
            guard #available(iOS 17.0, *) else {
                controller.overrideUserInterfaceStyle = environment.appearance.style ?? .unspecified
                return
            }
            environment.apply(to: &controller.traitOverrides)
        }
    }

    /// An invisible view left inside a presented controller's view, calling back once that view
    /// leaves the window. The presenting side cannot see every way out: an alert's button and a
    /// controller dismissing itself go through whichever controller UIKit picked to present from,
    /// and only a swipe reaches a presentation delegate.
    private final class GalleryDismissalWatch: UIView {
        private var onGone: (() -> Void)?

        static func attach(to view: UIView, onGone: @escaping () -> Void) {
            let watch = GalleryDismissalWatch(frame: .zero)
            watch.isHidden = true
            watch.isUserInteractionEnabled = false
            watch.onGone = onGone
            view.addSubview(watch)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window == nil, let onGone else { return }
            self.onGone = nil
            onGone()
        }
    }
#endif
