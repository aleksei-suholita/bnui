/// The one-shot SF Symbol effect an item plays the moment it becomes selected.
///
/// Carried per item rather than per bar: a running-timer section can breathe while the rest bounce.
/// Pure and UIKit-free — it only names the effect; the item view maps it to a real `SymbolEffect`
/// at the point of use. Whatever is chosen, Reduce Motion suppresses it.
///
/// The animation is a one-shot accent and fires only when a *different* section is chosen — never on
/// reselect. To silence a section entirely, use ``none``.
public nonisolated enum BNTabBarSymbolAnimation: Equatable, Sendable {
    /// No effect: the icon still changes weight and colour, it just does not animate.
    case none
    /// The default — a single bounce. Matches the control's original behaviour.
    case bounce
    /// One pulse of the symbol's opacity.
    case pulse
    /// A single side-to-side wiggle.
    case wiggle
    /// One full rotation of the symbol's rotatable layers.
    case rotate
    /// A single breathe — the symbol scales up and back down once.
    case breathe
}
