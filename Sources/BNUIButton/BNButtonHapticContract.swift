import Foundation

/// What the finger is told at a given moment.
///
/// Kept UIKit-free because the decision is made in ``BNButtonInteraction`` — the rule "a cancel is
/// silent" is worth a test, and a test cannot reach a feedback generator. ``BNButtonHaptics`` turns
/// these into actual vibrations.
public nonisolated enum BNButtonHapticEvent: Equatable, Sendable {
    /// The touch was caught.
    case press
    /// The action fired after a press long enough for a second tick to be felt as its own beat.
    case trigger
    /// The touch landed on a disabled button and was refused.
    case rejected
    /// Deliberate silence: a cancel, a tap the cooldown swallowed, or a tap quick enough that the
    /// press tick already stood for the whole thing.
    case silent
}

/// How loud the confirmation is. Styles pick this; the control only relays it.
public nonisolated enum BNButtonHapticEmphasis: Equatable, Sendable {
    case standard
    /// Destructive actions, which have to feel different from an ordinary confirmation.
    case pronounced
    /// A style that wants no haptics at all, regardless of the host's global switch.
    case silent
}
