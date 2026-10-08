#if canImport(UIKit)
    import UIKit

    /// Recogniser built for the bar rather than borrowed from UIKit.
    ///
    /// `UILongPressGestureRecognizer(minimumPressDuration: 0)` almost works, but it reports
    /// absolute positions only. The bar needs the *translation* since touch-down: the lens has to
    /// travel by exactly as much as the finger did, instead of jumping under it.
    ///
    /// It also stays out of the way of the system glass response: it never delays touches and
    /// recognises alongside other gestures, so the material still gets its own under-finger effect.
    public final class BNTabBarDragRecognizer: UIGestureRecognizer {
        private struct Sample {
            let location: CGPoint
            let time: TimeInterval
        }

        /// Samples older than this no longer describe the finger. A pause before lifting means
        /// the finger left at rest, however fast it moved before the pause.
        private static let velocityWindow: TimeInterval = 0.1

        private var initialLocation: CGPoint?
        private var currentLocation: CGPoint?
        private var samples: [Sample] = []

        override public init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        /// Movement since touch-down. The lens is positioned from this delta, never from the
        /// absolute touch position.
        public func translation(in _: UIView?) -> CGPoint {
            guard let initialLocation, let currentLocation else { return .zero }
            return CGPoint(
                x: currentLocation.x - initialLocation.x,
                y: currentLocation.y - initialLocation.y,
            )
        }

        /// Speed of the finger over its last moments, in points per second of the recogniser's
        /// view. Zero when the finger paused before lifting or has not moved at all.
        ///
        /// Averaged over a short window rather than taken from the last two events: two touch
        /// samples a few milliseconds apart give a noisy figure, and a spring started with noise
        /// jerks visibly.
        public func velocity(in _: UIView?) -> CGPoint {
            guard let last = samples.last,
                  let first = samples.first(where: { last.time - $0.time <= Self.velocityWindow }),
                  last.time - first.time > 0
            else { return .zero }
            let elapsed = last.time - first.time
            return CGPoint(
                x: (last.location.x - first.location.x) / elapsed,
                y: (last.location.y - first.location.y) / elapsed,
            )
        }

        override public func reset() {
            super.reset()
            initialLocation = nil
            currentLocation = nil
            samples.removeAll()
        }

        override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            if initialLocation == nil {
                initialLocation = touches.first?.location(in: view)
            }
            currentLocation = initialLocation
            record(touches.first)
            // Recognise immediately: the response has to be visible within the frame of the touch,
            // not a frame later.
            state = .began
        }

        override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            currentLocation = touches.first?.location(in: view)
            record(touches.first)
            state = .changed
        }

        override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesEnded(touches, with: event)
            // The lift itself is a sample: a finger that stopped and then lifted contributes a
            // late, unmoved point, which is exactly what drives the velocity back to zero.
            record(touches.first)
            state = .ended
        }

        override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)
            state = .cancelled
        }

        private func record(_ touch: UITouch?) {
            guard let touch else { return }
            samples.append(Sample(location: touch.location(in: view), time: touch.timestamp))
            // Only the window is kept; older samples could never be read again.
            let cutoff = touch.timestamp - Self.velocityWindow
            samples.removeAll { $0.time < cutoff }
        }
    }
#endif
