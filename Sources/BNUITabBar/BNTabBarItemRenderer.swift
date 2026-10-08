#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Which copy of an item this view is. The bar draws every item twice — once unselected,
    /// once selected — and the lens reveals the second copy through its own geometry.
    public enum BNTabBarItemLayer: Equatable, Sendable {
        case base
        case selected
    }

    /// Everything an item view needs to draw itself.
    public struct BNTabBarItemState {
        public var isSelected: Bool
        /// 0…1 — how far the lens has covered this item. Lets a renderer interpolate during a drag
        /// instead of flipping between two states.
        public var selectionProgress: CGFloat
        /// Labels are hidden — by `labelMode`, or because the bar ran out of room for them.
        public var isCompact: Bool
        /// Factor labels are drawn at: 1 at full size, below it when a crowded bar shrinks every
        /// label alike. Never under the theme's `minimumLabelScale` — past that `isCompact` is set.
        public var titleScale: CGFloat
        public var isPressed: Bool
        public var theme: BNTabBarTheme
        public var layer: BNTabBarItemLayer

        public init(
            isSelected: Bool,
            selectionProgress: CGFloat,
            isCompact: Bool,
            titleScale: CGFloat = 1,
            isPressed: Bool,
            theme: BNTabBarTheme,
            layer: BNTabBarItemLayer,
        ) {
            self.isSelected = isSelected
            self.selectionProgress = selectionProgress
            self.isCompact = isCompact
            self.titleScale = titleScale
            self.isPressed = isPressed
            self.theme = theme
            self.layer = layer
        }
    }

    /// Contract of an item view. Anything satisfying it can be a section — a ring of progress
    /// around a timer icon, a Lottie animation, whatever the host needs.
    public protocol BNTabBarItemRendering: UIView {
        func apply(state: BNTabBarItemState, transition: BNTransition)
        /// One-shot accent at the moment the item becomes selected.
        func playSelectionAnimation()
        /// What the content needs across — the layout solver's input. The label is reported apart
        /// from the icon, because a crowded bar shrinks labels and then drops them.
        func measure() -> BNTabBarLayoutSolver.ItemMeasure
    }

    /// Creates item views.
    ///
    /// This replaces adding cases to `BNTabBarItem.Icon`: a list of icon kinds is a dead end, because
    /// each new case has to be understood by the control. A renderer is understood by nobody but
    /// its author, and gets full item state in return.
    public protocol BNTabBarItemRenderer {
        func makeItemView(for item: BNTabBarItem, layer: BNTabBarItemLayer) -> any BNTabBarItemRendering
    }

    /// Default look: icon over an optional label, with an optional badge.
    public struct BNStandardTabBarItemRenderer: BNTabBarItemRenderer {
        private let theme: BNTabBarTheme
        private let labelMode: BNTabBarConfiguration.LabelMode

        public init(theme: BNTabBarTheme, labelMode: BNTabBarConfiguration.LabelMode) {
            self.theme = theme
            self.labelMode = labelMode
        }

        public func makeItemView(for item: BNTabBarItem, layer: BNTabBarItemLayer) -> any BNTabBarItemRendering {
            BNTabBarItemView(item: item, theme: theme, labelMode: labelMode, layer: layer)
        }
    }
#endif
