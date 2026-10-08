import BNUICore
import Foundation

/// The button's whole motion vocabulary in one place.
///
/// Separate entries rather than one shared spring: a finger landing, a finger leaving quickly and a
/// button going grey are different events and want different physics. Pure by design — no UIKit —
/// so the speed reward and the reduce-motion resolution are testable without a simulator.
public nonisolated struct BNButtonMotion: Equatable, Sendable {
    /// Compression under the finger. No overshoot: the press has to be there in the first frame,
    /// and a bouncing press reads as lag.
    public var press: BNSpring
    /// Return after an unhurried press.
    public var releaseSlow: BNSpring
    /// Return after an instant click — the springy end of the scale.
    public var releaseFast: BNSpring
    /// Initial velocity handed to the return spring, interpolated by the same snap.
    public var releaseVelocityRange: ClosedRange<CGFloat>
    /// How long a press has to last before it stops counting as instant.
    public var snapWindow: TimeInterval
    /// Below this hold the press tick and the confirmation merge into one: a tap that quick is a
    /// single event to the finger, and two ticks inside it blur into a rattle instead of two beats.
    /// A rule about feedback rather than about movement, so Reduce Motion leaves it alone.
    public var hapticMergeWindow: TimeInterval
    /// enabled/disabled colour changes. A curve, not a spring: nothing is moving.
    public var stateChange: BNCurve
    /// Entering and leaving `loading`.
    public var loading: BNCurve
    public var focus: BNCurve
    /// Optional double-tap barrier. 0 — off, which is the default: by contract the host guards
    /// against double taps, and the theme may only add a short barrier on top.
    public var cooldown: TimeInterval
    /// How a disabled button refuses a touch.
    public var rejection: BNButtonRejection

    /// How instant a press was: 1 for a click with no dwell, 0 for anything at or past the window.
    ///
    /// The one place this formula lives. Everything else — bounce, initial velocity — is derived
    /// from the number it returns.
    public static func snap(heldFor held: TimeInterval, window: TimeInterval) -> CGFloat {
        guard window > 0 else { return 0 }
        return 1 - min(max(CGFloat(held / window), 0), 1)
    }

    /// The return spring for a press of a given snap: bounce and initial velocity in one step.
    public func releaseSpring(snap: CGFloat) -> BNSpring {
        let amount = min(max(snap, 0), 1)
        let base = BNSpring.interpolated(from: releaseSlow, to: releaseFast, t: amount)
        let low = releaseVelocityRange.lowerBound
        let high = releaseVelocityRange.upperBound
        return base.withInitialVelocity(low + (high - low) * amount)
    }

    public init(
        press: BNSpring = BNSpring(duration: 0.16, bounce: 0),
        releaseSlow: BNSpring = BNSpring(duration: 0.30, bounce: 0.10),
        releaseFast: BNSpring = BNSpring(duration: 0.45, bounce: 0.45),
        releaseVelocityRange: ClosedRange<CGFloat> = 0 ... 6,
        snapWindow: TimeInterval = 0.25,
        hapticMergeWindow: TimeInterval = 0.15,
        stateChange: BNCurve = BNCurve(duration: 0.20),
        loading: BNCurve = BNCurve(duration: 0.22),
        focus: BNCurve = BNCurve(duration: 0.20),
        cooldown: TimeInterval = 0,
        rejection: BNButtonRejection = .standard,
    ) {
        self.press = press
        self.releaseSlow = releaseSlow
        self.releaseFast = releaseFast
        self.releaseVelocityRange = releaseVelocityRange
        self.snapWindow = snapWindow
        self.hapticMergeWindow = hapticMergeWindow
        self.stateChange = stateChange
        self.loading = loading
        self.focus = focus
        self.cooldown = cooldown
        self.rejection = rejection
    }

    public static let standard = BNButtonMotion()

    /// Reduce Motion: springs collapse and stop overshooting, and the speed reward flattens — a
    /// reward expressed purely as bounce has nothing left to say once bounce is gone. The button
    /// keeps working; only the movement goes.
    public static let reduced = BNButtonMotion(
        press: BNSpring(duration: 0.10, bounce: 0),
        releaseSlow: BNSpring(duration: 0.10, bounce: 0),
        releaseFast: BNSpring(duration: 0.10, bounce: 0),
        releaseVelocityRange: 0 ... 0,
        stateChange: BNCurve(duration: 0.10),
        loading: BNCurve(duration: 0.10),
        focus: BNCurve(duration: 0.10),
        rejection: BNButtonRejection.standard.resolved(reduceMotion: true),
    )

    /// Reduce Motion keeps the rules that are not effects — the cooldown, the haptic merge window,
    /// and whether a disabled button refuses at all. What it takes away is the movement of that
    /// refusal.
    public func resolved(reduceMotion: Bool) -> BNButtonMotion {
        guard reduceMotion else { return self }
        var reduced = Self.reduced
        reduced.snapWindow = snapWindow
        reduced.hapticMergeWindow = hapticMergeWindow
        reduced.cooldown = cooldown
        reduced.rejection = rejection.resolved(reduceMotion: true)
        return reduced
    }
}
