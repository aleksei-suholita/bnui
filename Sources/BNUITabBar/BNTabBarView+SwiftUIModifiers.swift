#if canImport(UIKit)
    import BNUICore
    import SwiftUI
    import UIKit

    /// What the `bnTabBar…` and `bnTabView…` modifiers have set for the bars beneath them.
    ///
    /// Every field is optional: unset means the bar's own default. A modifier nearer the bar
    /// writes over a farther one, and one applied to ``BN/TabBar`` or ``BN/TabView`` itself writes
    /// over both. The placement and the gap belong to ``BN/TabView`` alone.
    nonisolated struct BNTabBarEnvironment {
        var theme: BNTabBarTheme?
        var material: (any BNTabBarMaterial)?
        var lensRenderer: (any BNTabBarLensRenderer)?
        var itemRenderer: (any BNTabBarItemRenderer)?
        var haptics: BNTabBarHaptics?
        var alignment: BNTabBarConfiguration.Alignment?
        var width: BNTabBarConfiguration.Width?
        var labelMode: BNTabBarConfiguration.LabelMode?
        var moreItem: BNTabBarItem?
        var placement: BNTabBarController.Placement?
        var contentGap: CGFloat?

        /// The configuration the fields add up to, field by field over the kit's defaults.
        @MainActor var configuration: BNTabBarConfiguration {
            let defaults = BNTabBarConfiguration()
            return BNTabBarConfiguration(
                alignment: alignment ?? defaults.alignment,
                width: width ?? defaults.width,
                labelMode: labelMode ?? defaults.labelMode,
                moreItem: moreItem ?? defaults.moreItem,
            )
        }
    }

    private nonisolated struct BNTabBarEnvironmentKey: EnvironmentKey {
        static var defaultValue: BNTabBarEnvironment {
            BNTabBarEnvironment()
        }
    }

    extension EnvironmentValues {
        nonisolated var bnTabBar: BNTabBarEnvironment {
            get { self[BNTabBarEnvironmentKey.self] }
            set { self[BNTabBarEnvironmentKey.self] = newValue }
        }
    }

    /// The "More" section a modifier describes. Its id stays the kit's own, so the sections' ids
    /// never meet it.
    @MainActor private func moreItem(title: String, icon: BNTabBarItem.Icon) -> BNTabBarItem {
        BNTabBarItem(id: BNTabBarConfiguration().moreItem.id, icon: icon, title: title)
    }

    // MARK: - On any view: every bar beneath

    public extension View {
        /// The theme of every ``BN/TabBar`` and ``BN/TabView`` beneath — once, at the root, is the
        /// usual place.
        func bnTabBarTheme(_ theme: BNTabBarTheme) -> some View {
            transformEnvironment(\.bnTabBar) { $0.theme = theme }
        }

        /// The surface of every ``BN/TabBar`` and ``BN/TabView`` beneath. Read once, when a bar is
        /// made.
        func bnTabBarMaterial(_ material: any BNTabBarMaterial) -> some View {
            transformEnvironment(\.bnTabBar) { $0.material = material }
        }

        /// The selection lens of every ``BN/TabBar`` and ``BN/TabView`` beneath. Read once, when a
        /// bar is made.
        func bnTabBarLensRenderer(_ renderer: any BNTabBarLensRenderer) -> some View {
            transformEnvironment(\.bnTabBar) { $0.lensRenderer = renderer }
        }

        /// What draws the sections of every ``BN/TabBar`` and ``BN/TabView`` beneath. Read once,
        /// when a bar is made.
        func bnTabBarItemRenderer(_ renderer: any BNTabBarItemRenderer) -> some View {
            transformEnvironment(\.bnTabBar) { $0.itemRenderer = renderer }
        }

        /// The haptics of every ``BN/TabBar`` and ``BN/TabView`` beneath. Read once, when a bar is
        /// made.
        func bnTabBarHaptics(_ haptics: BNTabBarHaptics) -> some View {
            transformEnvironment(\.bnTabBar) { $0.haptics = haptics }
        }

        /// Where the capsule of every ``BN/TabBar`` and ``BN/TabView`` beneath sits once it is
        /// narrower than the bar.
        func bnTabBarAlignment(_ alignment: BNTabBarConfiguration.Alignment) -> some View {
            transformEnvironment(\.bnTabBar) { $0.alignment = alignment }
        }

        /// Whether the capsule of every ``BN/TabBar`` and ``BN/TabView`` beneath hugs its sections
        /// or fills the bar.
        func bnTabBarWidth(_ width: BNTabBarConfiguration.Width) -> some View {
            transformEnvironment(\.bnTabBar) { $0.width = width }
        }

        /// When the sections of every ``BN/TabBar`` and ``BN/TabView`` beneath show their titles.
        func bnTabBarLabelMode(_ mode: BNTabBarConfiguration.LabelMode) -> some View {
            transformEnvironment(\.bnTabBar) { $0.labelMode = mode }
        }

        /// The "More" section of every ``BN/TabBar`` and ``BN/TabView`` beneath, drawn with an
        /// SF Symbol.
        func bnTabBarMoreItem(_ title: String, systemImage: String) -> some View {
            let item = moreItem(title: title, icon: .symbol(systemImage))
            return transformEnvironment(\.bnTabBar) { $0.moreItem = item }
        }

        /// The "More" section of every ``BN/TabBar`` and ``BN/TabView`` beneath, drawn with an image.
        func bnTabBarMoreItem(_ title: String, image: UIImage) -> some View {
            let item = moreItem(title: title, icon: .image(image))
            return transformEnvironment(\.bnTabBar) { $0.moreItem = item }
        }

        /// Where the bar stands in every ``BN/TabView`` beneath — as the system's floating bar
        /// does, or off the safe area's edges. Read once, when the tab view is made.
        func bnTabViewPlacement(_ placement: BNTabBarController.Placement) -> some View {
            transformEnvironment(\.bnTabBar) { $0.placement = placement }
        }

        /// The distance kept between the bar and the content in every ``BN/TabView`` beneath. Read
        /// once, when the tab view is made.
        func bnTabViewContentGap(_ gap: CGFloat) -> some View {
            transformEnvironment(\.bnTabBar) { $0.contentGap = gap }
        }
    }

    // MARK: - On a bar: this one alone

    /// The same modifiers again, returning the bar itself, so that they and the events can come in
    /// any order — `Text.font` beside `View.font` is SwiftUI's own example. Set here, a value wins
    /// over the environment.
    public extension BN.TabBar {
        /// This bar's theme, over any `bnTabBarTheme` above it.
        func bnTabBarTheme(_ theme: BNTabBarTheme) -> Self {
            adjusting { $0.theme = theme }
        }

        /// This bar's surface, over any `bnTabBarMaterial` above it. Read once, when the bar is made.
        func bnTabBarMaterial(_ material: any BNTabBarMaterial) -> Self {
            adjusting { $0.material = material }
        }

        /// This bar's selection lens, over any `bnTabBarLensRenderer` above it. Read once.
        func bnTabBarLensRenderer(_ renderer: any BNTabBarLensRenderer) -> Self {
            adjusting { $0.lensRenderer = renderer }
        }

        /// What draws this bar's sections, over any `bnTabBarItemRenderer` above it. Read once.
        func bnTabBarItemRenderer(_ renderer: any BNTabBarItemRenderer) -> Self {
            adjusting { $0.itemRenderer = renderer }
        }

        /// This bar's haptics, over any `bnTabBarHaptics` above it. Read once.
        func bnTabBarHaptics(_ haptics: BNTabBarHaptics) -> Self {
            adjusting { $0.haptics = haptics }
        }

        /// Where this bar's capsule sits, over any `bnTabBarAlignment` above it.
        func bnTabBarAlignment(_ alignment: BNTabBarConfiguration.Alignment) -> Self {
            adjusting { $0.alignment = alignment }
        }

        /// Whether this bar's capsule hugs its sections or fills the bar, over any
        /// `bnTabBarWidth` above it.
        func bnTabBarWidth(_ width: BNTabBarConfiguration.Width) -> Self {
            adjusting { $0.width = width }
        }

        /// When this bar's sections show their titles, over any `bnTabBarLabelMode` above it.
        func bnTabBarLabelMode(_ mode: BNTabBarConfiguration.LabelMode) -> Self {
            adjusting { $0.labelMode = mode }
        }

        /// This bar's "More" section with an SF Symbol, over any `bnTabBarMoreItem` above it.
        func bnTabBarMoreItem(_ title: String, systemImage: String) -> Self {
            let item = moreItem(title: title, icon: .symbol(systemImage))
            return adjusting { $0.moreItem = item }
        }

        /// This bar's "More" section with an image, over any `bnTabBarMoreItem` above it.
        func bnTabBarMoreItem(_ title: String, image: UIImage) -> Self {
            let item = moreItem(title: title, icon: .image(image))
            return adjusting { $0.moreItem = item }
        }
    }

    public extension BN.TabView {
        /// This tab view's theme, over any `bnTabBarTheme` above it. Read once, when it is made.
        func bnTabBarTheme(_ theme: BNTabBarTheme) -> Self {
            adjusting { $0.theme = theme }
        }

        /// This tab view's bar surface, over any `bnTabBarMaterial` above it. Read once.
        func bnTabBarMaterial(_ material: any BNTabBarMaterial) -> Self {
            adjusting { $0.material = material }
        }

        /// This tab view's selection lens, over any `bnTabBarLensRenderer` above it. Read once.
        func bnTabBarLensRenderer(_ renderer: any BNTabBarLensRenderer) -> Self {
            adjusting { $0.lensRenderer = renderer }
        }

        /// What draws this tab view's sections, over any `bnTabBarItemRenderer` above it. Read once.
        func bnTabBarItemRenderer(_ renderer: any BNTabBarItemRenderer) -> Self {
            adjusting { $0.itemRenderer = renderer }
        }

        /// This tab view's bar haptics, over any `bnTabBarHaptics` above it. Read once.
        func bnTabBarHaptics(_ haptics: BNTabBarHaptics) -> Self {
            adjusting { $0.haptics = haptics }
        }

        /// Where this tab view's capsule sits, over any `bnTabBarAlignment` above it. Read once.
        func bnTabBarAlignment(_ alignment: BNTabBarConfiguration.Alignment) -> Self {
            adjusting { $0.alignment = alignment }
        }

        /// Whether this tab view's capsule hugs its sections or fills the bar, over any
        /// `bnTabBarWidth` above it. Read once.
        func bnTabBarWidth(_ width: BNTabBarConfiguration.Width) -> Self {
            adjusting { $0.width = width }
        }

        /// When this tab view's sections show their titles, over any `bnTabBarLabelMode` above it.
        /// Read once.
        func bnTabBarLabelMode(_ mode: BNTabBarConfiguration.LabelMode) -> Self {
            adjusting { $0.labelMode = mode }
        }

        /// This tab view's "More" section with an SF Symbol, over any `bnTabBarMoreItem` above it.
        /// Read once.
        func bnTabBarMoreItem(_ title: String, systemImage: String) -> Self {
            let item = moreItem(title: title, icon: .symbol(systemImage))
            return adjusting { $0.moreItem = item }
        }

        /// This tab view's "More" section with an image, over any `bnTabBarMoreItem` above it.
        /// Read once.
        func bnTabBarMoreItem(_ title: String, image: UIImage) -> Self {
            let item = moreItem(title: title, icon: .image(image))
            return adjusting { $0.moreItem = item }
        }

        /// Where this tab view's bar stands, over any `bnTabViewPlacement` above it. Read once.
        func bnTabViewPlacement(_ placement: BNTabBarController.Placement) -> Self {
            adjusting { $0.placement = placement }
        }

        /// This tab view's gap above the content, over any `bnTabViewContentGap` above it. Read once.
        func bnTabViewContentGap(_ gap: CGFloat) -> Self {
            adjusting { $0.contentGap = gap }
        }
    }
#endif
