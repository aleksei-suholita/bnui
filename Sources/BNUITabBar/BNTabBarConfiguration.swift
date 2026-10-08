#if canImport(UIKit)
    import UIKit

    /// Layout choices the host makes. Kept apart from `BNTabBarTheme`: this is composition
    /// (where the capsule sits, whether labels show), the theme is looks (colours, geometry).
    public struct BNTabBarConfiguration: Equatable {
        /// Where the capsule sits in the available width. Mirrored automatically in RTL,
        /// because the control lays out against leading/trailing anchors.
        public enum Alignment {
            case leading
            case center
            case trailing
        }

        /// `selectedOnly` shows the label of the active section only; `never` is an icon-only bar.
        /// VoiceOver names the section in every mode.
        public enum LabelMode {
            case always
            case selectedOnly
            case never
        }

        public var alignment: Alignment
        public var labelMode: LabelMode
        /// The last slot once there are more sections than the capsule holds; it opens the rest
        /// in a system menu. Only its look is used — its id is never reported, since choosing in
        /// the menu reports the section chosen. The host supplies it so the title is localised.
        public var moreItem: BNTabBarItem

        public init(
            alignment: Alignment = .center,
            labelMode: LabelMode = .always,
            moreItem: BNTabBarItem = BNTabBarItem(id: "BNTabBar.more", icon: .symbol("ellipsis"), title: "More"),
        ) {
            self.alignment = alignment
            self.labelMode = labelMode
            self.moreItem = moreItem
        }
    }
#endif
