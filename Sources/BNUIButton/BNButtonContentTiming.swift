import BNUICore
import CoreGraphics
import Foundation

/// How a change of the button's content reaches the screen, worked out from the call and from
/// the moment it is made in.
///
/// The order is the point: an explicit "no" wins, then an animation the host is already running,
/// and only then the button's own spring. A host takes the timing over by making the call inside
/// its own animation, the way nested animation blocks inherit in UIKit. Pure, so the order is
/// tested without a simulator.
nonisolated enum BNButtonContentTiming: Equatable {
    /// At once: the call asked for no animation, the button is not on screen, or animations are
    /// off for the moment (`UIView.performWithoutAnimation`).
    case immediate
    /// Inside an animation the host is running: the button's changes join it and take its curve.
    case inherited(duration: TimeInterval)
    /// The button's own springs, from ``BNButtonContentTransitionTuning``.
    case own

    static func resolve(
        animated: Bool,
        isInWindow: Bool,
        animationsEnabled: Bool,
        inheritedDuration: TimeInterval,
    ) -> BNButtonContentTiming {
        guard animated, isInWindow, animationsEnabled else { return .immediate }
        guard inheritedDuration > 0 else { return .own }
        return .inherited(duration: inheritedDuration)
    }
}

/// The springs and shares a content change is drawn with: the kit's own, kept in one place.
nonisolated struct BNButtonContentTransitionTuning: Equatable {
    /// The arriving content: its fade and its scale up to full size. No bounce: text that
    /// overshoots reads as a wobble.
    var content = BNSpring(duration: 0.35, bounce: 0)
    /// The outline and everything the new size moves.
    var size = BNSpring(duration: 0.40, bounce: 0.12)
    /// The part of the content's duration the leaving content takes to fade out. Short, so the
    /// two never stand on top of each other half-faded.
    var outgoingShare: Double = 0.35
    /// How far into the content's duration the arriving content starts.
    var incomingDelayShare: Double = 0.15
    /// The scale the arriving content grows from.
    var incomingScale: CGFloat = 0.92
    /// How far the blur style blurs the content on its way out and in.
    var blurRadius: CGFloat = 8

    /// The same motion at another speed: the longer of the two springs takes `duration`, and the
    /// other keeps its share of it, so a slower change is the same change, only slower. `nil` —
    /// the tuning as it is.
    func scaled(toDuration duration: TimeInterval?) -> Self {
        let longest = max(content.duration, size.duration)
        guard let duration, duration > 0, longest > 0 else { return self }
        let factor = duration / longest
        var scaled = self
        scaled.content.duration *= factor
        scaled.size.duration *= factor
        return scaled
    }
}

/// Which way a roll goes: down when both titles hold a number and the new one is smaller, up
/// otherwise — the system's own default. A counter going from 3 to 2 rolls back.
nonisolated enum BNButtonRollDirection {
    static func countsDown(from old: String?, to new: String?) -> Bool {
        guard let old = number(in: old), let new = number(in: new) else { return false }
        return new < old
    }

    /// The first number in a title, read as its digits alone: the separators between them —
    /// grouping or decimal — are skipped, which orders two numbers written the same way, as a
    /// title's numbers are, by one formatter.
    static func number(in text: String?) -> Decimal? {
        guard let text else { return nil }
        var digits = ""
        var pendingSeparator = false
        for character in text {
            if character.isASCII, character.isNumber {
                digits.append(character)
                pendingSeparator = false
            } else if !digits.isEmpty, !pendingSeparator, Self.separators.contains(character) {
                // A separator counts only between two digits: "1,5" goes on, "1, 5" ends at 1.
                pendingSeparator = true
            } else if !digits.isEmpty {
                break
            }
        }
        return digits.isEmpty ? nil : Decimal(string: digits)
    }

    private static let separators: Set<Character> = [",", ".", "\u{2009}", "\u{202F}", "\u{00A0}"]
}

/// Where the old content goes and the new one comes from, and when — one style worked out.
nonisolated struct BNButtonContentMoves {
    var leavesTo = CGAffineTransform.identity
    var arrivesFrom = CGAffineTransform.identity
    /// The part of the content's duration the old content takes to leave.
    var leavingShare: Double
    /// How far into the content's duration the new one starts.
    var arrivalDelayShare: Double
}

nonisolated extension BNButtonContentMoves {
    /// The slide style's moves: the old content leaves `travel` points the way `direction` goes,
    /// and the new one arrives from as far the other way.
    init(
        sliding direction: BNButtonContentTransition.Direction,
        travel: CGFloat,
        leavingShare: Double,
        arrivalDelayShare: Double,
    ) {
        let offset = direction == .up ? -travel : travel
        self.init(
            leavesTo: CGAffineTransform(translationX: 0, y: offset),
            arrivesFrom: CGAffineTransform(translationX: 0, y: -offset),
            leavingShare: leavingShare,
            arrivalDelayShare: arrivalDelayShare,
        )
    }
}
