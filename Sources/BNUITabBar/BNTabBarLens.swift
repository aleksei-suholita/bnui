#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Everything a lens needs to know about where it should be right now.
    ///
    /// Grouped into a value rather than passed as loose arguments: these always travel
    /// together, and a renderer that ignores one of them should not have to restate it.
    public struct BNTabBarLensState: Equatable {
        /// Size of the lens' own coordinate space (the bar's content area).
        public var size: CGSize
        /// Where the marker should be, in that same space.
        public var selection: CGRect
        /// A finger is on the bar. The marker grows while it is.
        public var isLifted: Bool
        /// Horizontal speed the marker should start with, in points per second of the lens' space.
        ///
        /// Non-zero only when a finger just let go: its momentum carries into the spring that
        /// takes over, so a release feels like a throw rather than a stop and a restart. Handed
        /// over as an absolute speed because only the lens knows how far the marker still has
        /// to travel, which is the unit its spring actually wants.
        public var velocity: CGFloat

        public init(size: CGSize, selection: CGRect, isLifted: Bool = false, velocity: CGFloat = 0) {
            self.size = size
            self.selection = selection
            self.isLifted = isLifted
            self.velocity = velocity
        }
    }

    /// The selection marker, as a replaceable component.
    ///
    /// The key idea, borrowed from a shipping implementation: a lens does not *tint* the selected
    /// section, it **reveals** a second copy of it. The bar hands the lens two content layers —
    /// the same items drawn unselected and selected — and the lens decides what shows through its
    /// own geometry. That is why the colour change lands exactly on the lens edge and flows through
    /// the icon during a drag, which a cross-fade of the whole item can never do.
    ///
    /// A lens that cannot do two layers simply leaves `selectedContentView` empty and reports
    /// `revealsSelectedContent == false`; the bar then colours the items directly.
    public protocol BNTabBarLens: UIView {
        /// Items drawn in their unselected state.
        var contentView: UIView { get }
        /// The same items drawn selected. Visible only where the lens says so.
        var selectedContentView: UIView { get }
        /// False when the lens has no second layer, so the bar knows to colour items itself.
        var revealsSelectedContent: Bool { get }

        func update(state: BNTabBarLensState, theme: BNTabBarTheme, transition: BNTransition)
    }

    /// Creates lenses. Swapping the renderer changes how selection looks and moves without the
    /// control knowing whether it got a mask, a flat capsule or something of the host's own.
    public protocol BNTabBarLensRenderer {
        func makeLens() -> any BNTabBarLens
    }
#endif
