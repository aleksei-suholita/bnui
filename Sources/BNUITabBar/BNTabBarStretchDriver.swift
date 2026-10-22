#if canImport(UIKit)
    import UIKit

    /// Carries the lens' stretch to the finger's pull frame by frame, on the spring the glass under
    /// the lens follows the finger with. Lives as long as one drag: when the drag goes, so does it,
    /// and its display link stops on the next frame.
    final class BNTabBarStretchDriver {
        /// The stretch on screen now.
        var stretch: BNTabBarLensStretch {
            motion.value
        }

        private var motion = BNTabBarStretchMotion()
        private var target = BNTabBarLensStretch.none
        private var spring = BNTabBarStretchMotion.Spring(dampingRatio: 1, response: 0.3)
        private var link: CADisplayLink?
        private var lastFrame: CFTimeInterval?
        private let onFrame: (BNTabBarLensStretch) -> Void

        /// `onFrame` draws each frame of the stretch while the spring runs.
        init(onFrame: @escaping (BNTabBarLensStretch) -> Void) {
            self.onFrame = onFrame
        }

        nonisolated deinit {}

        /// Aims the stretch at the finger's new pull. The spring carries on from where the stretch
        /// is and how fast it moves, so a pull that changes mid-way does not restart it.
        func pull(to target: BNTabBarLensStretch, on spring: BNTabBarStretchMotion.Spring) {
            self.target = target
            self.spring = spring
            guard link == nil, !motion.isSettled(at: target) else { return }
            let link = CADisplayLink(target: StretchFrameTarget(driver: self), selector: #selector(StretchFrameTarget.tick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            self.link = link
            lastFrame = nil
        }

        fileprivate func tick(_ link: CADisplayLink) {
            // The first frame has no previous one; a frame long after the last — the app paused —
            // moves by one frame, not by the whole gap.
            let time = lastFrame.map { link.targetTimestamp - $0 } ?? (link.targetTimestamp - link.timestamp)
            lastFrame = link.targetTimestamp
            motion.advance(toward: target, on: spring, by: min(max(time, 0), 1.0 / 30))
            if motion.isSettled(at: target) {
                motion.settle(at: target)
                link.invalidate()
                self.link = nil
            }
            onFrame(motion.value)
        }
    }

    /// Display-link target that does not retain the driver: a drag that ends takes the driver with
    /// it, and the next tick finds it gone and stops the link.
    private final class StretchFrameTarget {
        private weak var driver: BNTabBarStretchDriver?

        init(driver: BNTabBarStretchDriver) {
            self.driver = driver
        }

        nonisolated deinit {}

        @objc func tick(_ link: CADisplayLink) {
            guard let driver else {
                link.invalidate()
                return
            }
            driver.tick(link)
        }
    }
#endif
