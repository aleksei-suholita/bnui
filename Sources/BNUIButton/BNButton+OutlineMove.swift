#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        // MARK: - The frame the host gives

        /// Where the outline stands before a change of content, and what it is to move on once the
        /// host gives the frame for the new size.
        func outlineMove(for timing: BNButtonContentTiming) -> BNButtonOutlineMove {
            let transition: BNTransition = switch timing {
            case let .inherited(duration): .spring(BNSpring(duration: duration, bounce: 0))
            case .own, .immediate: .spring(sizeSpring)
            }
            return BNButtonOutlineMove(
                size: bounds.size,
                centreInWindow: convert(CGPoint(x: bounds.midX, y: bounds.midY), to: nil),
                transition: transition,
                deadline: CACurrentMediaTime() + settlingTime(of: timing),
            )
        }

        /// Moves the outline from where it stood to the frame the host has just given, when new
        /// content asked for that frame and it came without an animation around this pass —
        /// SwiftUI's frame for a representable, a screen's next pass with ``animatesSizeChanges``
        /// off. Without this the outline, held to the button's edges, would jump to the new size.
        ///
        /// Called right after the button's own layout put its views at the new size, and before
        /// their insides are laid out: they go back to where they stood and are laid out in place
        /// under the change's spring, the content within them included.
        func followNewFrame() {
            guard let move = pendingLayout.outlineMove else { return }
            // Inside the host's animation the outline already moves with it.
            guard UIView.inheritedAnimationDuration == 0, !move.hasExpired(at: CACurrentMediaTime()) else {
                pendingLayout.outlineMove = nil
                return
            }
            guard move.isDue(forSize: bounds.size) else { return }
            pendingLayout.outlineMove = nil

            let views = [surface?.view, badgeHost].compactMap(\.self)
            let landing = views.map { (bounds: $0.bounds, center: $0.center) }
            let start = move.startCentre(converted: convert(move.centreInWindow, from: nil), isCarried: isCarriedToNewFrame)
            UIView.performWithoutAnimation {
                for view in views {
                    view.bounds.size = move.size
                    view.center = start
                }
            }
            move.transition.run {
                for (view, place) in zip(views, landing) {
                    view.bounds = place.bounds
                    view.center = place.center
                    view.layoutIfNeeded()
                }
            }
        }

        /// Whether an animation carries the button, or a view it is in, to its new frame: the
        /// frame was set inside the host's animation and the layout came after it. The button is
        /// then still drawn where it stood.
        private var isCarriedToNewFrame: Bool {
            sequence(first: layer) { $0.superlayer }.contains { layer in
                layer.animationKeys()?.contains { $0.hasPrefix("position") || $0.hasPrefix("bounds") } ?? false
            }
        }
    }
#endif
