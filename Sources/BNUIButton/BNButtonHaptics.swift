#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// The button's haptic contract, written down rather than picked in code.
    ///
    /// | Event | Response |
    /// |---|---|
    /// | touch-down | light and short — the touch was caught |
    /// | fired after a quick tap | silence: the press tick already answered for the whole tap |
    /// | fired after a held press | a confirmation |
    /// | fired, destructive style | heavier than an ordinary confirmation |
    /// | released outside (cancel) | silence |
    /// | tap on a disabled button | a refusal — see ``BNButtonRejection`` |
    /// | tap swallowed by the cooldown | silence |
    /// | a style of ``BNButtonHapticEmphasis/silent`` | no press tick, no confirmation |
    ///
    /// One tap, one tick. A tap short enough that the press and the confirmation land within
    /// ``BNButtonMotion/hapticMergeWindow`` of each other is a single event to the finger; playing
    /// both smears them into a rattle rather than reading as two beats.
    ///
    /// The refusal is this kit's one departure from the spec, which asks for silence on a disabled
    /// tap. It is a switch rather than a decision: ``BNButtonRejection/isHapticEnabled``.
    ///
    /// The system button gives no haptics at all, so this is a cheap and noticeable win. Everything
    /// is muted by `isEnabled` — the host's global switch — and by system-level limits such as Low
    /// Power Mode. Reduce Motion does *not* mute it: they are different axes of accessibility, and
    /// a user who turned off animation still wants to feel the button.
    ///
    /// The ticks themselves are played by ``BNHaptics``, not by generators of the button's own. The
    /// button's "one tap, one tick" rule turned out to have a second half it could not see: a
    /// refusal here and the toast the host raises to explain it are two impulses for one event. The
    /// merge window that fixes that has to sit below both controls, so it does.
    public final class BNButtonHaptics {
        public var isEnabled: Bool

        private let engine: BNHaptics

        public init(isEnabled: Bool = true, engine: BNHaptics = .shared) {
            self.isEnabled = isEnabled
            self.engine = engine
        }

        /// Called on touch-down so the generators are warm by the time the finger lifts.
        public func prepare() {
            guard isEnabled else { return }
            engine.prepare(.impact(.light))
            engine.prepare(.impact(.medium))
        }

        public func pressed() {
            guard isEnabled else { return }
            // Not merged: this is the *first* impulse of a tap, and dropping it because something
            // else happened to play a moment ago would leave the touch unanswered. The second
            // impulse of the same tap is what the window is for.
            engine.play(.impact(.light, intensity: 0.6), merging: false)
        }

        /// The touch was refused. `.error` rather than a heavier impact: the finger should read
        /// this as "no", not as a louder version of "yes".
        public func rejected() {
            guard isEnabled else { return }
            engine.play(.notification(.error), merging: false)
        }

        public func triggered(emphasis: BNButtonHapticEmphasis) {
            guard isEnabled else { return }
            switch emphasis {
            case .standard:
                engine.play(.impact(.medium))
            case .pronounced:
                // A different shape, not merely a stronger one: destroying something should not
                // feel like an ordinary confirmation with the volume turned up.
                engine.play(.notification(.warning))
            case .silent:
                break
            }
        }
    }
#endif
