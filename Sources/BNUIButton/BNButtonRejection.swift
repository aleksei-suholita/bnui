import CoreGraphics
import Foundation

/// How the button refuses a touch it cannot accept.
///
/// A disabled button that simply ignores a finger is indistinguishable from a broken one — the
/// user is left deciding whether the tap missed. A short refusal answers that: yes, the touch
/// landed; no, it will not happen.
///
/// Pure numbers, so the shape of the refusal is testable and the colour is the theme's business.
public nonisolated struct BNButtonRejection: Equatable, Sendable {
    public var isEnabled: Bool
    /// How far the button travels sideways at the widest point of the shake.
    public var travel: CGFloat
    /// Sideways trips. Two is a head shake; more starts to look like an error dialog from 2003.
    public var cycles: Int
    public var duration: TimeInterval
    /// Peak opacity of the colour flash.
    public var flashAlpha: CGFloat
    /// How long the colour sits at full strength before it starts to go.
    ///
    /// Without a hold the flash is over before it registers: fading from the peak the instant it
    /// appears means the eye only ever catches the tail of it.
    public var flashHold: TimeInterval
    /// How long the fade back to nothing takes.
    public var flashFade: TimeInterval
    /// The spec asks for silence on a disabled tap. Kept as a switch rather than a decision:
    /// silence is one flag away, and a host that wants the buzz has it by default.
    public var isHapticEnabled: Bool

    public init(
        isEnabled: Bool = true,
        travel: CGFloat = 7,
        cycles: Int = 2,
        duration: TimeInterval = 0.36,
        flashAlpha: CGFloat = 0.45,
        flashHold: TimeInterval = 0.35,
        flashFade: TimeInterval = 0.5,
        isHapticEnabled: Bool = true,
    ) {
        self.isEnabled = isEnabled
        self.travel = travel
        self.cycles = cycles
        self.duration = duration
        self.flashAlpha = flashAlpha
        self.flashHold = flashHold
        self.flashFade = flashFade
        self.isHapticEnabled = isHapticEnabled
    }

    /// How long the colour is on screen in total.
    public var flashTotalDuration: TimeInterval {
        flashHold + flashFade
    }

    /// Sideways offsets of the shake, starting and ending at rest.
    ///
    /// Each trip is weaker than the last, the way a real head shake decays — a constant amplitude
    /// reads as a glitch rather than as a gesture.
    public var offsets: [CGFloat] {
        guard isEnabled, travel > 0, cycles > 0 else { return [] }
        var values: [CGFloat] = [0]
        for cycle in 0 ..< max(cycles, 0) {
            let decay = 1 - CGFloat(cycle) / CGFloat(max(cycles, 1)) * 0.45
            values.append(-travel * decay)
            values.append(travel * decay)
        }
        values.append(0)
        return values
    }

    /// Reduce Motion: the button stops moving but still refuses — the flash and the haptic carry
    /// the whole message, which is what "the function survives, the effect goes" means here.
    public func resolved(reduceMotion: Bool) -> BNButtonRejection {
        guard reduceMotion else { return self }
        var copy = self
        copy.travel = 0
        copy.cycles = 0
        return copy
    }

    public static let standard = BNButtonRejection()
    /// No refusal at all — the disabled button simply ignores the touch, as the spec's default.
    public static let none = BNButtonRejection(isEnabled: false, isHapticEnabled: false)
}
