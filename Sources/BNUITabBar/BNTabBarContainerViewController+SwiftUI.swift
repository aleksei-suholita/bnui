#if canImport(UIKit)
    import BNUICore
    import SwiftUI
    import UIKit

    public extension BN {
        /// ``BNTabBarContainerViewController`` in a SwiftUI hierarchy — the kit's replacement for
        /// `TabView`.
        ///
        /// ```swift
        /// BN.TabView(selection: $tab, tabs: [
        ///     .init(item: BNTabBarItem(id: "home", icon: .symbol("house"), title: "Home")) { HomeView() },
        ///     .init(item: BNTabBarItem(id: "stats", icon: .symbol("chart.bar"), title: "Stats")) { StatsView() },
        /// ])
        /// .onAction { startSomething() }
        /// ```
        ///
        /// Each tab's content lives in a hosting controller of its own, kept for the container's life:
        /// switching tabs detaches a view, it does not destroy it, so scroll positions and navigation
        /// stacks survive the round trip. The content keeps clear of the floating bar through its
        /// safe area, which the container grows by the bar's measured height.
        ///
        /// The set of tabs is fixed per container. A different list of ids makes a new container —
        /// the content state of every tab goes with the old one — while a changed badge or title
        /// only redraws the bar. The configuration, theme, margin and gap are read when the
        /// container is made.
        ///
        /// The SwiftUI environment reaches the tabs: it is handed across the hosting controllers,
        /// which do not pass it on by themselves.
        struct TabView: View {
            @Binding public var selection: String
            public let tabs: [Tab]
            /// Swappable while the container lives, as in UIKit: an action that changes meaning with
            /// the app's state does not throw the tabs away.
            public var action: BNTabBarAction?
            let configuration: BNTabBarConfiguration
            let theme: BNTabBarTheme
            let margin: CGFloat
            let contentGap: CGFloat
            var onAction: (() -> Void)?
            var onMultiTap: ((String, Int) -> Void)?

            /// - Parameters:
            ///   - selection: the ID of the tab on screen. The bar writes it when the user switches,
            ///     and writing it from outside switches the tab.
            ///   - tabs: the tabs in bar order, each a bar item and the view shown when it is selected.
            ///   - action: the button beside the sections. Tapping it is reported, never selected.
            ///   - configuration: composition — where the capsule sits, whether labels show.
            ///   - theme: looks — colours, geometry, type and motion.
            ///   - margin: inset of the floating capsule from the safe-area edges.
            ///   - contentGap: distance kept between the bar and the content it must never cover.
            public init(
                selection: Binding<String>,
                tabs: [Tab],
                action: BNTabBarAction? = nil,
                configuration: BNTabBarConfiguration = BNTabBarConfiguration(),
                theme: BNTabBarTheme = .standard,
                margin: CGFloat = 16,
                contentGap: CGFloat = 16,
            ) {
                _selection = selection
                self.tabs = tabs
                self.action = action
                self.configuration = configuration
                self.theme = theme
                self.margin = margin
                self.contentGap = contentGap
            }

            /// The bar's action button was tapped. Never a selection.
            public func onAction(_ handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.onAction = handler
                return copy
            }

            /// A run of taps on one section: its id and the position in the run (1, 2, 3…).
            public func onMultiTap(_ handler: @escaping (String, Int) -> Void) -> Self {
                var copy = self
                copy.onMultiTap = handler
                return copy
            }

            public var body: some View {
                BNTabViewBridge(container: self)
                    .id(tabs.map(\.item.id))
                    // Full screen, as `TabView` is: the bar pins itself to the safe area, and the tabs'
                    // content reads its own.
                    .ignoresSafeArea()
            }
        }
    }

    public extension BN.TabView {
        /// One tab: the bar item to draw and the SwiftUI content shown when it is selected.
        struct Tab {
            public let item: BNTabBarItem
            let content: AnyView

            public init(item: BNTabBarItem, @ViewBuilder content: () -> some View) {
                self.item = item
                self.content = AnyView(content())
            }
        }
    }

    /// The UIKit bridge under ``BN/TabView``. Kept apart so the public type can
    /// be an ordinary view — the `.id` that rebuilds it for a new set of tabs has to sit outside.
    struct BNTabViewBridge: UIViewControllerRepresentable {
        let container: BN.TabView

        func makeCoordinator() -> Coordinator {
            Coordinator(container: container)
        }

        func makeUIViewController(context: Context) -> BNTabBarContainerViewController {
            let coordinator = context.coordinator
            let tabs = container.tabs.map { tab in
                let host = UIHostingController(rootView: hosted(tab, in: context))
                coordinator.hosts[tab.item.id] = host
                return BNTabBarContainerViewController.Tab(item: tab.item, viewController: host)
            }
            let controller = BNTabBarContainerViewController(
                tabs: tabs,
                action: container.action,
                configuration: container.configuration,
                theme: container.theme,
                margin: container.margin,
                contentGap: container.contentGap,
            )
            controller.onSelect = { coordinator.container.selection = $0 }
            controller.onAction = { coordinator.container.onAction?() }
            controller.onMultiTap = { coordinator.container.onMultiTap?($0, $1) }
            // The container shows its first tab when its view loads; loading it now lets the
            // binding's tab replace that before anything reaches the screen.
            controller.loadViewIfNeeded()
            if controller.selectedTabID != container.selection {
                controller.select(tabID: container.selection, animated: false)
            }
            return controller
        }

        func updateUIViewController(_ controller: BNTabBarContainerViewController, context: Context) {
            let coordinator = context.coordinator
            coordinator.container = container
            for tab in container.tabs {
                coordinator.hosts[tab.item.id]?.rootView = hosted(tab, in: context)
            }
            // Guaranteed the same ids by the `.id` above; redraws only if a badge or title moved.
            controller.updateItems(container.tabs.map(\.item))
            if controller.action != container.action {
                controller.action = container.action
            }
            if controller.selectedTabID != container.selection {
                controller.select(tabID: container.selection, animated: !context.transaction.disablesAnimations)
            }
        }

        private func hosted(_ tab: BN.TabView.Tab, in context: Context) -> AnyView {
            AnyView(tab.content.environment(\.self, context.environment))
        }

        final class Coordinator {
            var container: BN.TabView
            var hosts: [String: UIHostingController<AnyView>] = [:]

            init(container: BN.TabView) {
                self.container = container
            }
        }
    }
#endif
