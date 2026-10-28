#if canImport(UIKit)
    import UIKit

    // MARK: - Appearance callbacks

    // Every tab is a child, on screen or not, so UIKit is not left to forward the controller's
    // appearance to its children: a tab out of sight would hear that it appears too. The controller
    // hands the callbacks to the tab on screen alone, and to the two a swap exchanges.

    public extension BNTabBarController {
        /// Where the controller itself is.
        internal enum Appearance {
            case off
            case appearing
            case on
            case disappearing
        }

        override var shouldAutomaticallyForwardAppearanceMethods: Bool {
            false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            appearance = .appearing
            childInTransition = currentChild
            currentChild?.beginAppearanceTransition(true, animated: animated)
        }

        /// Laid out again once on screen, too: a presentation lays the controller out before the
        /// system has put its bars where they stay.
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            appearance = .on
            childInTransition?.endAppearanceTransition()
            childInTransition = nil
            view.setNeedsLayout()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            appearance = .disappearing
            childInTransition = currentChild
            currentChild?.beginAppearanceTransition(false, animated: animated)
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            appearance = .off
            childInTransition?.endAppearanceTransition()
            childInTransition = nil
        }

        /// Runs `swap` with the callbacks of the tab leaving and the tab arriving around it, as far
        /// as the controller itself is on screen.
        internal func forwardAppearance(from previous: UIViewController?, to next: UIViewController, around swap: () -> Void) {
            switch appearance {
            case .on:
                previous?.beginAppearanceTransition(false, animated: false)
                next.beginAppearanceTransition(true, animated: false)
                swap()
                previous?.endAppearanceTransition()
                next.endAppearanceTransition()
            case .appearing:
                // The tab leaving turns back on its way in; the one arriving finishes appearing
                // with the controller.
                previous?.beginAppearanceTransition(false, animated: false)
                next.beginAppearanceTransition(true, animated: false)
                swap()
                previous?.endAppearanceTransition()
                childInTransition = next
            case .disappearing:
                // The controller is leaving: the tab leaving finishes now, and the one arriving is
                // never seen.
                swap()
                childInTransition?.endAppearanceTransition()
                childInTransition = nil
            case .off:
                swap()
            }
        }

        /// Runs `removal` of the tab on screen — a tab the host took away — with its callbacks
        /// around it, so it hears that it is gone.
        internal func forwardDisappearance(of controller: UIViewController, around removal: () -> Void) {
            switch appearance {
            case .on:
                controller.beginAppearanceTransition(false, animated: false)
                removal()
                controller.endAppearanceTransition()
            case .appearing where childInTransition === controller:
                controller.beginAppearanceTransition(false, animated: false)
                removal()
                controller.endAppearanceTransition()
                childInTransition = nil
            case .disappearing where childInTransition === controller:
                removal()
                controller.endAppearanceTransition()
                childInTransition = nil
            default:
                removal()
            }
        }
    }
#endif
