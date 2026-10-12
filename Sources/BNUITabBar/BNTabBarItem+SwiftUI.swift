#if canImport(UIKit)
    import BNUICore
    import SwiftUI
    import UIKit

    public extension BN {
        /// One tab of ``BN/TabView`` or one section of ``BN/TabBar``: the title and icon the bar
        /// draws, the value the selection holds, and — in a tab view — the screen it shows.
        ///
        /// SwiftUI's `Tab`, from iOS 16. The value is any `Hashable`, usually a case of the host's
        /// own enum, so a selection that names a tab that is not there does not compile:
        ///
        /// ```swift
        /// enum Section { case home, stats }
        ///
        /// BN.TabView(selection: $section) {
        ///     BN.Tab("Home", systemImage: "house", value: .home) { HomeView() }
        ///         .badge(2)
        ///     BN.Tab("Stats", systemImage: "chart.bar", value: .stats) { StatsView() }
        /// }
        /// ```
        ///
        /// A section of a bar alone has no screen and is written without one; its `Content` is
        /// `Void`, which is not a view, so a section without a screen cannot reach a tab view and a
        /// tab with one cannot reach a bar alone.
        struct Tab<Value: Hashable, Content> {
            let title: String
            let icon: BNTabBarItem.Icon
            let value: Value
            /// `nil` for a section of a bar alone, whose content is `Void`.
            let content: Content?
            var badge: BNTabBarBadge?
            var selectionAnimation: BNTabBarSymbolAnimation = .bounce
            var accessibilityLabel: String?

            /// The bar item under the given id: the bar knows its sections by id, the host by value.
            func item(id: String) -> BNTabBarItem {
                BNTabBarItem(
                    id: id,
                    icon: icon,
                    title: title,
                    badge: badge,
                    selectionAnimation: selectionAnimation,
                    accessibilityLabel: accessibilityLabel,
                )
            }
        }
    }

    public extension BN.Tab where Content: View {
        /// A tab of ``BN/TabView`` drawn with an SF Symbol.
        ///
        /// - Parameters:
        ///   - title: what the section says.
        ///   - systemImage: the symbol's name, in its outline form; the bar draws it as given.
        ///   - value: what the selection holds while this tab is on screen.
        ///   - content: the screen shown when the tab is selected.
        init(_ title: String, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {
            self.init(title: title, icon: .symbol(systemImage), value: value, content: content())
        }

        /// A tab of ``BN/TabView`` drawn with an image.
        ///
        /// - Parameters:
        ///   - title: what the section says.
        ///   - image: the section's icon.
        ///   - size: the box the image is fitted into; `nil` for the square of a round symbol.
        ///   - rendering: a glyph tinted by the state, or a picture in its own colours.
        ///   - value: what the selection holds while this tab is on screen.
        ///   - content: the screen shown when the tab is selected.
        init(
            _ title: String,
            image: UIImage,
            size: CGSize? = nil,
            rendering: BNTabBarItem.ImageRendering = .template,
            value: Value,
            @ViewBuilder content: () -> Content,
        ) {
            self.init(title: title, icon: .image(image, size: size, rendering: rendering), value: value, content: content())
        }
    }

    public extension BN.Tab {
        /// A badge with a count, as SwiftUI's `badge(_:)` takes one: zero or less shows none, and
        /// past the theme's limit it reads "99+".
        func badge(_ count: Int) -> Self {
            badge(.count(count))
        }

        /// A badge with a short word or sign — "New", "!".
        func badge(_ text: String) -> Self {
            badge(.text(text))
        }

        /// Any badge — a dot, or a count or text with its own words for VoiceOver. `nil` shows
        /// none.
        func badge(_ badge: BNTabBarBadge?) -> Self {
            var copy = self
            copy.badge = badge
            return copy
        }

        /// How the symbol moves when the section is chosen. `.bounce` unless set.
        func selectionAnimation(_ animation: BNTabBarSymbolAnimation) -> Self {
            var copy = self
            copy.selectionAnimation = animation
            return copy
        }

        /// What VoiceOver says for the section, when the title alone is not enough.
        func accessibilityLabel(_ label: String) -> Self {
            var copy = self
            copy.accessibilityLabel = label
            return copy
        }
    }

    public extension BN.Tab where Content == Void {
        /// A section of ``BN/TabBar`` drawn with an SF Symbol.
        ///
        /// - Parameters:
        ///   - title: what the section says.
        ///   - systemImage: the symbol's name, in its outline form.
        ///   - value: what the selection holds while this section is chosen.
        init(_ title: String, systemImage: String, value: Value) {
            self.init(title: title, icon: .symbol(systemImage), value: value, content: nil)
        }

        /// A section of ``BN/TabBar`` drawn with an image.
        ///
        /// - Parameters:
        ///   - title: what the section says.
        ///   - image: the section's icon.
        ///   - size: the box the image is fitted into; `nil` for the square of a round symbol.
        ///   - rendering: a glyph tinted by the state, or a picture in its own colours.
        ///   - value: what the selection holds while this section is chosen.
        init(
            _ title: String,
            image: UIImage,
            size: CGSize? = nil,
            rendering: BNTabBarItem.ImageRendering = .template,
            value: Value,
        ) {
            self.init(title: title, icon: .image(image, size: size, rendering: rendering), value: value, content: nil)
        }
    }

    extension BN.Tab where Content: View {
        /// The same tab with its screen behind `AnyView`, so that tabs of different screens can
        /// stand in one list.
        func erased() -> BN.Tab<Value, AnyView> {
            BN.Tab<Value, AnyView>(
                title: title,
                icon: icon,
                value: value,
                content: content.map { AnyView($0) },
                badge: badge,
                selectionAnimation: selectionAnimation,
                accessibilityLabel: accessibilityLabel,
            )
        }
    }

    public extension BN {
        /// Collects the tabs of a ``BN/TabView``, each with its screen. SwiftUI's
        /// `TabContentBuilder`.
        @resultBuilder
        enum TabContentBuilder<Value: Hashable> {
            /// A tab with its screen.
            public static func buildExpression(_ tab: BN.Tab<Value, some View>) -> [BN.Tab<Value, AnyView>] {
                [tab.erased()]
            }

            /// A section of a bar alone has no screen to show.
            @available(*, unavailable, message: "A tab of BN.TabView shows a screen: add one with BN.Tab(_:systemImage:value:content:)")
            public static func buildExpression(_: BN.Tab<Value, Void>) -> [BN.Tab<Value, AnyView>] {
                []
            }

            /// The tabs in the order written.
            public static func buildBlock(_ parts: [BN.Tab<Value, AnyView>]...) -> [BN.Tab<Value, AnyView>] {
                parts.flatMap(\.self)
            }

            /// A tab behind an `if`.
            public static func buildOptional(_ part: [BN.Tab<Value, AnyView>]?) -> [BN.Tab<Value, AnyView>] {
                part ?? []
            }

            /// The first branch of an `if`–`else`.
            public static func buildEither(first part: [BN.Tab<Value, AnyView>]) -> [BN.Tab<Value, AnyView>] {
                part
            }

            /// The second branch of an `if`–`else`.
            public static func buildEither(second part: [BN.Tab<Value, AnyView>]) -> [BN.Tab<Value, AnyView>] {
                part
            }

            /// The tabs of a `for` loop.
            public static func buildArray(_ parts: [[BN.Tab<Value, AnyView>]]) -> [BN.Tab<Value, AnyView>] {
                parts.flatMap(\.self)
            }
        }

        /// Collects the sections of a ``BN/TabBar``, which has no screens to show.
        @resultBuilder
        enum TabBarContentBuilder<Value: Hashable> {
            /// A section.
            public static func buildExpression(_ tab: BN.Tab<Value, Void>) -> [BN.Tab<Value, Void>] {
                [tab]
            }

            /// A tab with a screen belongs in ``BN/TabView``.
            @available(*, unavailable, message: "BN.TabBar draws sections, not screens: drop the content, or use BN.TabView")
            public static func buildExpression(_: BN.Tab<Value, some View>) -> [BN.Tab<Value, Void>] {
                []
            }

            /// The sections in the order written.
            public static func buildBlock(_ parts: [BN.Tab<Value, Void>]...) -> [BN.Tab<Value, Void>] {
                parts.flatMap(\.self)
            }

            /// A section behind an `if`.
            public static func buildOptional(_ part: [BN.Tab<Value, Void>]?) -> [BN.Tab<Value, Void>] {
                part ?? []
            }

            /// The first branch of an `if`–`else`.
            public static func buildEither(first part: [BN.Tab<Value, Void>]) -> [BN.Tab<Value, Void>] {
                part
            }

            /// The second branch of an `if`–`else`.
            public static func buildEither(second part: [BN.Tab<Value, Void>]) -> [BN.Tab<Value, Void>] {
                part
            }

            /// The sections of a `for` loop.
            public static func buildArray(_ parts: [[BN.Tab<Value, Void>]]) -> [BN.Tab<Value, Void>] {
                parts.flatMap(\.self)
            }
        }
    }
#endif
