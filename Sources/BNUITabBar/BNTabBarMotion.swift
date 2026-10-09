import BNUICore
import Foundation

/// The bar's whole motion vocabulary in one place.
///
/// Separate entries rather than one shared spring: committing a selection, reacting to a finger
/// landing and collapsing the bar are different gestures of the same control and want different
/// physics. Pure by design — no UIKit — so the reduce-motion resolution is testable on macOS.
public nonisolated struct BNTabBarMotion: Equatable, Sendable {
    /// Commit: the lens travels to the chosen section.
    public var selection: BNSpring
    /// The finger landed on the bar: the lens darts to the section under it and swells.
    public var lift: BNSpring
    /// The finger left the bar: the lens settles onto the section it lands on.
    ///
    /// Its own spring, slower and calmer than `lift`: the system's lens reaches the finger fast
    /// and settles slow, and that asymmetry is what reads as a surface reacting rather than a
    /// switch flipping. The marker here never lifts, but its travel keeps the same two tempos.
    public var unlift: BNSpring
    /// Showing and hiding the whole bar.
    public var visibility: BNCurve
    /// Alpha and blur inside an item, the sections fading to the glass's light or dark look, and
    /// a badge's number changing.
    public var crossFade: BNCurve
    /// The accent an item plays at the moment it becomes selected, and a badge popping in or out.
    public var itemAccent: BNSpring

    public init(
        selection: BNSpring,
        lift: BNSpring,
        unlift: BNSpring,
        visibility: BNCurve,
        crossFade: BNCurve,
        itemAccent: BNSpring,
    ) {
        self.selection = selection
        self.lift = lift
        self.unlift = unlift
        self.visibility = visibility
        self.crossFade = crossFade
        self.itemAccent = itemAccent
    }

    public static let standard = BNTabBarMotion(
        selection: BNSpring(duration: 0.40, bounce: 0.25),
        // Travel to the finger: 0.4 s without overshoot is how the reference implementation moves
        // its lens on touch-down (a 0.4 s UIKit system-curve spring), and it is what the system bar
        // reads like next to it. The lens' own lift spec (0.27 s, 0.375 bounce) was tried and felt
        // as a jerk on tap: with a flat marker the travel is the whole event. Settling keeps the
        // system's slower tempo (damping 0.7 over 0.5 s, as bounce = 1 − damping).
        lift: BNSpring(duration: 0.40, bounce: 0),
        unlift: BNSpring(duration: 0.50, bounce: 0.30),
        visibility: BNCurve(duration: 0.40, timing: .controlPoints(x1: 0.33, y1: 0.52, x2: 0.25, y2: 0.99)),
        crossFade: BNCurve(duration: 0.25, timing: .easeInOut),
        itemAccent: BNSpring(duration: 0.30, bounce: 0.45),
    )

    /// Reduce Motion: springs collapse into a short easeInOut and stop overshooting.
    /// Movement still happens — the lens travelling is navigation, not decoration.
    public static let reduced = BNTabBarMotion(
        selection: BNSpring(duration: 0.15, bounce: 0),
        lift: BNSpring(duration: 0.15, bounce: 0),
        unlift: BNSpring(duration: 0.15, bounce: 0),
        visibility: BNCurve(duration: 0.15, timing: .easeInOut),
        crossFade: BNCurve(duration: 0.15, timing: .easeInOut),
        itemAccent: BNSpring(duration: 0.15, bounce: 0),
    )

    public func resolved(reduceMotion: Bool) -> BNTabBarMotion {
        reduceMotion ? .reduced : self
    }
}
