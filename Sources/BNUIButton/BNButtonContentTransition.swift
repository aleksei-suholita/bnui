/// How a button's old content gives way to the new one when ``BNButton/setContent(_:animated:)``
/// animates the change.
///
/// Whatever the style, a change that keeps the title changes only the icons, in place: a symbol
/// replaced by its relative morphs into it, an icon that comes grows in where it will stand, one
/// that goes shrinks away. Under Reduce Motion every style becomes a short fade.
///
/// ``blur`` and ``roll`` draw the change over the content, so they need content centred in the
/// button; content aligned to an edge fades through instead. ``roll`` turns one line of text into
/// another: a change to or from an icon alone, a title on two lines or a custom renderer blurs
/// instead.
public nonisolated enum BNButtonContentTransition: Hashable, Sendable {
    /// Which way ``BNButtonContentTransition/slide(_:)`` carries the content.
    public nonisolated enum Direction: Hashable, Sendable {
        /// The old content rises out and the new one rises in from below.
        case up
        /// The old content sinks out and the new one sinks in from above.
        case down
    }

    /// The old content blurs away and the new one comes into focus, as the system's bars change
    /// theirs. The default.
    case blur
    /// The old content fades out fast and the new one grows in from slightly smaller.
    case fadeThrough
    /// The old content slides out and the new one slides in after it, the way the direction goes.
    case slide(Direction)
    /// The characters that change roll into their new ones while the rest slide to their new
    /// places, as SwiftUI's numeric text transition does — for counters, prices and titles that
    /// differ by a few letters. A number that goes down rolls down.
    case roll
}
