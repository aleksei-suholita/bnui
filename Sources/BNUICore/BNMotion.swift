import CoreGraphics
import Foundation

/// A spring, described the way it is authored: how long it takes, how much it overshoots, and how
/// hard it is pushed at the start.
///
/// One type for the whole kit. Each control keeps its own *vocabulary* of springs — pressing,
/// committing a section, a toast arriving are different events and want different physics — but the
/// brick they are built from is shared, because three identical structs differing only by prefix is
/// three places to fix the same thing.
public nonisolated struct BNSpring: Equatable, Sendable {
    public var duration: TimeInterval
    /// 0 — no overshoot; higher values bounce more, and 1 never settles.
    ///
    /// Held between 0 and 1: a value outside is clamped. UIKit and SwiftUI also take a negative
    /// bounce — an overdamped spring — but all it adds over 0 is a slower arrival, and a longer
    /// `duration` says that already.
    public var bounce: CGFloat {
        didSet { bounce = Self.clamped(bounce) }
    }

    /// Speed the spring starts with. This is where a gesture's momentum is carried into the
    /// animation that follows it: a quick click gets a shove into the return, a thrown toast leaves
    /// at the speed it was thrown.
    public var initialVelocity: CGFloat

    public init(duration: TimeInterval, bounce: CGFloat, initialVelocity: CGFloat = 0) {
        self.duration = duration
        self.bounce = Self.clamped(bounce)
        self.initialVelocity = initialVelocity
    }

    private static func clamped(_ bounce: CGFloat) -> CGFloat {
        min(max(bounce, 0), 1)
    }

    public func withInitialVelocity(_ velocity: CGFloat) -> BNSpring {
        BNSpring(duration: duration, bounce: bounce, initialVelocity: velocity)
    }

    /// Blend used to place a release between the calm and the snappy end of a scale.
    public static func interpolated(from: BNSpring, to: BNSpring, t: CGFloat) -> BNSpring {
        let amount = min(max(t, 0), 1)
        return BNSpring(
            duration: from.duration + (to.duration - from.duration) * TimeInterval(amount),
            bounce: from.bounce + (to.bounce - from.bounce) * amount,
            initialVelocity: from.initialVelocity + (to.initialVelocity - from.initialVelocity) * amount,
        )
    }
}

/// A spring as mass, stiffness and damping — the form animation APIs before iOS 17 take.
nonisolated struct BNSpringPhysics: Equatable {
    var mass: CGFloat
    var stiffness: CGFloat
    var damping: CGFloat
}

nonisolated extension BNSpring {
    /// The same spring in its physical form.
    ///
    /// `duration` is the response and `bounce` sets the damping ratio, `1 − bounce`; mass is 1.
    /// That is how Core Animation reads a perceptual duration and a bounce, and the tests hold this
    /// conversion to it.
    var physics: BNSpringPhysics {
        let response = max(CGFloat(duration), 0.001)
        return BNSpringPhysics(
            mass: 1,
            stiffness: pow(2 * .pi / response, 2),
            damping: 4 * .pi * (1 - bounce) / response,
        )
    }
}

/// A timing curve for the things that are not springs: cross-fades and state changes.
public nonisolated struct BNCurve: Equatable, Sendable {
    public enum Timing: Equatable, Sendable {
        case easeInOut
        case controlPoints(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)
    }

    public var duration: TimeInterval
    public var timing: Timing

    public init(duration: TimeInterval, timing: Timing = .easeInOut) {
        self.duration = duration
        self.timing = timing
    }
}

/// How a change should reach the screen: instantly, or carried by a spring or a curve.
///
/// Passed down from a control into its material, lens or content renderer so that one decision —
/// this is a press, this is a commit, this is a drag frame — is made once at the top instead of
/// being re-guessed by every layer under it.
public nonisolated enum BNTransition: Equatable, Sendable {
    /// No animation. Used for every drag frame, where the finger is the animation.
    case immediate
    case spring(BNSpring)
    case curve(BNCurve)

    public var isAnimated: Bool {
        self != .immediate
    }

    public var duration: TimeInterval {
        switch self {
        case .immediate: 0
        case let .spring(spring): spring.duration
        case let .curve(curve): curve.duration
        }
    }
}

#if canImport(UIKit)
    import UIKit

    public extension BNSpring {
        /// The same spring as UIKit timing parameters.
        ///
        /// From iOS 17 in its duration-and-bounce form, before that in its physical form — one
        /// curve either way.
        var timingParameters: UISpringTimingParameters {
            // Both axes get the same push. Not symmetry for its own sake: UIKit uses `dx` alone for
            // animations of a single scalar property, so a velocity handed to `dy` only — the
            // obvious thing to write for a control that moves vertically — is silently ignored.
            let velocity = CGVector(dx: initialVelocity, dy: initialVelocity)
            guard #available(iOS 17.0, *) else {
                // Before iOS 17 a spring is given by its physics — the same curve, worked out here.
                let physics = physics
                return UISpringTimingParameters(
                    mass: physics.mass,
                    stiffness: physics.stiffness,
                    damping: physics.damping,
                    initialVelocity: velocity,
                )
            }
            return UISpringTimingParameters(duration: duration, bounce: bounce, initialVelocity: velocity)
        }
    }

    public extension BNCurve {
        /// The same curve as UIKit timing parameters.
        var timingParameters: any UITimingCurveProvider {
            switch timing {
            case .easeInOut:
                UICubicTimingParameters(animationCurve: .easeInOut)
            case let .controlPoints(x1, y1, x2, y2):
                UICubicTimingParameters(
                    controlPoint1: CGPoint(x: x1, y: y1),
                    controlPoint2: CGPoint(x: x2, y: y2),
                )
            }
        }
    }

    public extension BNTransition {
        /// The transition's UIKit timing; `nil` for `.immediate`, which has none.
        var timingParameters: (any UITimingCurveProvider)? {
            switch self {
            case .immediate: nil
            case let .spring(spring): spring.timingParameters
            case let .curve(curve): curve.timingParameters
            }
        }

        /// Runs `changes` under this transition and hands back the running animation.
        ///
        /// Handed back rather than fired and forgotten because animations in this kit are
        /// interruptible: a new touch has to be able to take one over on whatever frame it lands
        /// on, through ``BNAnimation/interrupt()``. `completion` is called once — `true` when the
        /// animation reached its end, `false` when it was interrupted — and callers that rebuild on
        /// completion need to tell the two apart.
        ///
        /// `.immediate` applies `changes` at once, reports `true` and hands back `nil`. It ignores
        /// the delay: a jump that waits is no longer immediate.
        ///
        /// - Parameters:
        ///   - delay: How long to wait before the animation starts, in seconds.
        ///   - changes: The property changes to animate.
        ///   - completion: Called once, with whether the animation reached its end.
        @discardableResult
        func run(
            afterDelay delay: TimeInterval = 0,
            _ changes: @escaping () -> Void,
            completion: ((Bool) -> Void)? = nil,
        ) -> BNAnimation? {
            guard let timingParameters else {
                changes()
                completion?(true)
                return nil
            }
            let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timingParameters)
            animator.addAnimations(changes)
            if let completion {
                animator.addCompletion { position in
                    completion(position == .end)
                }
            }
            if delay > 0 {
                animator.startAnimation(afterDelay: delay)
            } else {
                animator.startAnimation()
            }
            return BNAnimation(animator)
        }
    }

    /// An animation on its way to the screen — what ``BNTransition/run(afterDelay:_:completion:)``
    /// hands back.
    ///
    /// Kept by whoever may need to take the movement over: a new touch lands on whatever frame the
    /// animation is on, and ``interrupt()`` stops it right there. That is the one way to stop it,
    /// and it always reports — the completion hears `false`. The system animator underneath stays
    /// inside, because its own `stopAnimation(true)` stops without a word, and a caller waiting on
    /// the completion would wait forever.
    public final class BNAnimation {
        private let animator: UIViewPropertyAnimator

        init(_ animator: UIViewPropertyAnimator) {
            self.animator = animator
        }

        /// Whether it is still under way: started, or waiting out its delay.
        public var isRunning: Bool {
            animator.state == .active
        }

        /// Stops the animation on the frame it is on.
        ///
        /// The views keep the values they had reached, and the completion is called with `false`.
        /// Does nothing once the animation has ended.
        public func interrupt() {
            guard animator.state == .active else { return }
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
    }
#endif
