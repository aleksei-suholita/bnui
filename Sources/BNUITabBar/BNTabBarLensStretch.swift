import CoreGraphics
import Foundation

/// How the glass under the lens is pulled by a finger that has left it — the way the system's
/// interactive glass stretches toward such a finger. The marker lies on that glass and goes with
/// it. Pure numbers, so the law is testable on macOS.
///
/// The glass — the lens' whole space — is scaled by `1 + scale` on each axis around its centre and
/// moved by `offset`. A pull along one axis stretches it along that axis and squeezes it across by
/// as much.
public nonisolated struct BNTabBarLensStretch: Equatable, Sendable {
    /// Added to the glass' scale: `dx` to its width's, `dy` to its height's.
    public var scale: CGVector
    /// How far the glass moves toward the finger, in points.
    public var offset: CGVector

    public init(scale: CGVector = .zero, offset: CGVector = .zero) {
        self.scale = scale
        self.offset = offset
    }

    /// No finger pulling.
    public static let none = BNTabBarLensStretch()

    /// The same stretch `strength` times as strong: 1 is the system's, 0 none.
    func scaled(by strength: CGFloat) -> BNTabBarLensStretch {
        BNTabBarLensStretch(components: components.map { $0 * strength })
    }

    fileprivate var components: [CGFloat] {
        [scale.dx, scale.dy, offset.dx, offset.dy]
    }

    fileprivate init(components: [CGFloat]) {
        self.init(
            scale: CGVector(dx: components[0], dy: components[1]),
            offset: CGVector(dx: components[2], dy: components[3]),
        )
    }

    // MARK: - The system's interactive glass

    /// The system's law for a piece of interactive glass of `size`, measured in its own space,
    /// where it spans `0…size`: `start` is where the finger came down on it, `touch` where the
    /// finger is now. Read from UIKit on iOS 26.5.
    ///
    /// Along each axis the finger's travel splits in two: the part inside the glass and the part
    /// past its edge. The part past the edge stretches the glass by itself over
    /// `glassDistance(for:)`, the part inside by a quarter of that — so a finger that stays on the
    /// glass barely moves it, and one that leaves pulls it along, linearly and without a ceiling.
    /// The glass follows the finger by the same share of its size.
    static func glass(touch: CGPoint, start: CGPoint, size: CGSize) -> BNTabBarLensStretch {
        guard size.width > 0, size.height > 0 else { return .none }
        let distance = glassDistance(for: size)
        let travel = CGVector(dx: touch.x - start.x, dy: touch.y - start.y)
        let inside = CGVector(
            dx: min(max(touch.x, 0), size.width) - start.x,
            dy: min(max(touch.y, 0), size.height) - start.y,
        )
        let alongX = pull(travel: travel.dx, inside: inside.dx, distance: distance)
        let alongY = pull(travel: travel.dy, inside: inside.dy, distance: distance)
        return BNTabBarLensStretch(
            scale: CGVector(dx: alongX - alongY, dy: alongY - alongX),
            offset: CGVector(
                dx: CGFloat(signOf: travel.dx, magnitudeOf: alongX) * size.width,
                dy: CGFloat(signOf: travel.dy, magnitudeOf: alongY) * size.height,
            ),
        )
    }

    /// How far a finger must go past glass of `size` for it to stretch by its own size. Glass
    /// under 120 pt on its longer side takes the smallest distance; larger glass runs from the next
    /// one to the largest as its shorter side goes from 44 to 160 pt — larger glass stretches less.
    static func glassDistance(for size: CGSize) -> CGFloat {
        guard max(size.width, size.height) >= 120 else { return 2000 }
        let progress = min(max((min(size.width, size.height) - 44) / (160 - 44), 0), 1)
        return 6000 + (24000 - 6000) * progress
    }

    private static func pull(travel: CGFloat, inside: CGFloat, distance: CGFloat) -> CGFloat {
        guard travel != 0 else { return 0 }
        return (abs(travel) - abs(inside)) / distance + abs(inside) / (4 * distance)
    }
}

/// The stretch as it is shown: carried toward the finger's pull on the spring the system's glass
/// follows a finger with, so the marker stretches in step with the glass under it rather than
/// ahead of it.
nonisolated struct BNTabBarStretchMotion: Equatable {
    /// UIKit's spring: `response` is its period, `dampingRatio` 1 the critical one.
    struct Spring: Equatable {
        var dampingRatio: CGFloat
        var response: CGFloat

        /// The spring the system's interactive glass of `size` follows a finger with while it is
        /// down. Glass under 120 pt on its longer side takes the small one; larger glass runs to the
        /// large one as its longer side goes from 44 to 160 pt. Read from UIKit on iOS 26.5.
        static func glassTracking(for size: CGSize) -> Spring {
            let longer = max(size.width, size.height)
            guard longer >= 120 else { return Spring(dampingRatio: 0.625, response: 0.262) }
            let progress = min(max((longer - 44) / (160 - 44), 0), 1)
            return Spring(dampingRatio: 0.625, response: 0.262 + (0.314 - 0.262) * progress)
        }
    }

    private(set) var value = BNTabBarLensStretch.none
    private var velocity = BNTabBarLensStretch.none

    /// Moves `time` seconds toward `target`, in steps short enough for the stiffest spring.
    mutating func advance(toward target: BNTabBarLensStretch, on spring: Spring, by time: TimeInterval) {
        let stiffness = pow(2 * .pi / spring.response, 2)
        let damping = 4 * .pi * spring.dampingRatio / spring.response
        var position = value.components
        var speed = velocity.components
        let goal = target.components
        var remaining = CGFloat(time)
        while remaining > 0 {
            let step = min(remaining, 1.0 / 480)
            for index in position.indices {
                speed[index] += (-stiffness * (position[index] - goal[index]) - damping * speed[index]) * step
                position[index] += speed[index] * step
            }
            remaining -= step
        }
        value = BNTabBarLensStretch(components: position)
        velocity = BNTabBarLensStretch(components: speed)
    }

    /// Close enough to `target`, and slow enough, that the rest of the spring cannot be seen: a
    /// ten-thousandth of the size, a hundredth of a point.
    func isSettled(at target: BNTabBarLensStretch) -> Bool {
        let tolerances: [CGFloat] = [1e-4, 1e-4, 0.01, 0.01]
        return zip(zip(value.components, velocity.components), zip(target.components, tolerances))
            .allSatisfy { motion, goal in
                abs(motion.0 - goal.0) < goal.1 && abs(motion.1) < goal.1 * 10
            }
    }

    /// Lands on `target` and stops there.
    mutating func settle(at target: BNTabBarLensStretch) {
        value = target
        velocity = .none
    }
}
