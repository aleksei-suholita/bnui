#if canImport(UIKit)
    import UIKit

    /// Reports touch phases to the button without competing for them.
    ///
    /// `UIControl` tracking is not an option. It starts only for a touch that lands on the control
    /// itself: a touch that lands on a subview taking touches still climbs the responder chain to the
    /// control, but tracking never begins. Interactive glass answers a finger only when the touch
    /// lands inside it, so a glass button has to let the touch land there — and then tracking hears
    /// nothing. A recognizer hears every touch that lands on its view or anywhere beneath it, and the
    /// glass keeps its own response beside this one, which delays nothing and cancels nothing.
    ///
    /// A gesture above the button that takes the finger — a scroll view's pan, a sheet's drag, the
    /// back swipe — ends the press as cancelled. UIKit cancels the touch for the view under the
    /// finger, but not for a recognizer that recognizes alongside the one taking it; this one has
    /// to recognize alongside, or a press that begins on touch-down would keep the scroll view
    /// from scrolling. So it reports the cancel itself, by the rule UIKit applies to the view: a
    /// gesture that cancels touches in its view has begun.
    ///
    /// It reports; it decides nothing. Every rule about what a touch means stays in
    /// ``BNButtonInteraction``.
    public final class BNButtonPressRecognizer: UIGestureRecognizer {
        /// The landing touch's `tapCount`: above one, a quick second tap that `UIControl` reports
        /// as a repeat.
        private(set) var tapCount = 1

        override public init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            // The pressed state has to be on screen in the frame the finger lands, so nothing here
            // is allowed to hold a touch back and hand it over a frame later.
            delaysTouchesBegan = false
            delaysTouchesEnded = false
            cancelsTouchesInView = false
        }

        nonisolated deinit {}

        override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            tapCount = touches.first?.tapCount ?? 1
            // `.began` immediately rather than after a threshold: this is a button, and any delay
            // before the press appears reads as lag.
            state = .began
        }

        override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            state = isTaken(touches) ? .cancelled : .changed
        }

        override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesEnded(touches, with: event)
            // Checked again on the lift: the gesture may have begun on the last move, after this
            // recognizer had already heard it.
            state = isTaken(touches) ? .cancelled : .ended
        }

        /// Whether a gesture above the button has taken the finger.
        ///
        /// Only a gesture under way counts: `.began` or `.changed`, never a discrete one that
        /// recognized on the lift — a host's tap on the screen behind the button does not take
        /// the button's tap. Gestures on the button and inside it are its own parts — the glass
        /// response, the menu's interaction — and the menu ends the press on its own.
        private func isTaken(_ touches: Set<UITouch>) -> Bool {
            guard let view else { return false }
            return touches.contains { touch in
                (touch.gestureRecognizers ?? []).contains { other in
                    guard other !== self, other.cancelsTouchesInView,
                          other.state == .began || other.state == .changed
                    else { return false }
                    return other.view.map { !$0.isDescendant(of: view) } ?? true
                }
            }
        }

        override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)
            state = .cancelled
        }
    }
#endif
