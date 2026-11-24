import BNUICore
import CoreGraphics
import Foundation

/// What the next layout pass owes a change made before it.
nonisolated struct BNButtonPendingLayout: Equatable {
    /// The next intrinsic size is solved without the current width as a ceiling: new content has
    /// to be measured at its own width, not squeezed into the frame the old one had.
    var naturalWidth = false
    /// A style, size or material set just before rebuilt the views, and nothing has laid them out:
    /// until then they stand in the button's corner, at no size.
    var afterRebuild = false
    /// Where the outline stood before new content changed its size, while the frame for that size
    /// is still the host's to give.
    var outlineMove: BNButtonOutlineMove?
}

/// A content change whose new frame the host gives — SwiftUI, or a screen with
/// `animatesSizeChanges` off: where the outline stood, so that it moves from there once the frame
/// arrives instead of jumping to it.
nonisolated struct BNButtonOutlineMove: Equatable {
    /// The button's size before the change.
    var size: CGSize
    /// The button's centre before the change, in the window.
    var centreInWindow: CGPoint
    /// What the outline moves on: the change's own spring.
    var transition: BNTransition
    /// Past this moment a new frame is the host's own change rather than this one's.
    var deadline: TimeInterval

    /// Whether a layout pass at `time` comes too late to bring this change's frame.
    func hasExpired(at time: TimeInterval) -> Bool {
        time > deadline
    }

    /// Whether a layout pass that gives the button `newSize` brings the change's frame. The old
    /// size does not: a pass may come before the host has had its say.
    func isDue(forSize newSize: CGSize) -> Bool {
        newSize != size
    }

    /// Where the outline's centre starts, in the button's own coordinates.
    ///
    /// - Parameters:
    ///   - converted: The old centre, brought from the window into the button as it is placed now.
    ///   - isCarried: Whether an animation carries the button, or a view it is in, to its new
    ///     frame. The button is then still drawn where it stood, and the outline starts where it
    ///     stood inside it.
    func startCentre(converted: CGPoint, isCarried: Bool) -> CGPoint {
        isCarried ? CGPoint(x: size.width / 2, y: size.height / 2) : converted
    }
}
