import CoreGraphics

/// Pure rules of ``BNTabBarController``: how far a tab's content keeps clear of the bar, which tab
/// stays on screen when the tabs change. Kept out of the
/// controller (and out of `canImport(UIKit)`) so they are tested without a simulator.
nonisolated enum BNTabBarControllerRules {
    /// What a tab adds to the bottom of its safe area: enough to reach the bar's top from what it
    /// inherits, never less than nothing; nothing at all while the bar is hidden.
    static func bottomInset(barTop: CGFloat, inherited: CGFloat, hidesBar: Bool) -> CGFloat {
        hidesBar ? 0 : max(0, barTop - inherited)
    }

    /// The tab on screen once the tabs are `ids`: the one on screen while it is still among them,
    /// the first otherwise; `nil` for no tabs.
    static func selection(keeping selected: String?, in ids: [String]) -> String? {
        if let selected, ids.contains(selected) {
            return selected
        }
        return ids.first
    }
}
