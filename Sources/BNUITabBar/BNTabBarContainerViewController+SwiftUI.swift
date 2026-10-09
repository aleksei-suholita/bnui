#if canImport(UIKit)
    import BNUICore
    import SwiftUI
    import UIKit

    public extension BN {
        /// ``BNTabBarContainerViewController`` in a SwiftUI hierarchy — the kit's replacement for
        /// `TabView`.
        ///
        /// ```swift
        /// enum Section { case home, stats }
        /// @State private var section = Section.home
        ///
        /// BN.TabView(selection: $section) {
        ///     BN.Tab("Home", systemImage: "house", value: .home) { HomeView() }
        ///         .badge(2)
        ///     BN.Tab("Stats", systemImage: "chart.bar", value: .stats) { StatsView() }
        /// }
        /// .action(BNTabBarAction(icon: .symbol("plus"), accessibilityLabel: "New")) { startSomething() }
        /// ```
        ///
        /// Each tab's content lives in a hosting controller of its own, kept for the container's life:
        /// switching tabs detaches a view, it does not destroy it, so scroll positions and navigation
        /// stacks survive the round trip. The content keeps clear of the floating bar through its
        /// safe area, which the container grows by the bar's measured height.
        ///
        /// The set of tabs is fixed per container. A different list of values makes a new container —
        /// the content state of every tab goes with the old one — while a changed badge or title
        /// only redraws the bar. Whatever the `bnTabBar…` and `bnTabView…` modifiers set is read
        /// when the container is made.
        ///
        /// The SwiftUI environment reaches the tabs: it is handed across the hosting controllers,
        /// which do not pass it on by themselves.
        struct TabView<Value: Hashable>: View {
            @Binding var selection: Value
            let tabs: [BN.Tab<Value, AnyView>]
            var adjustments: [(inout BNTabBarEnvironment) -> Void] = []
            var action: BNTabBarAction?
            var onAction: (() -> Void)?
            var onMultiTap: ((Value, Int) -> Void)?

            /// - Parameters:
            ///   - selection: the value of the tab on screen. The bar writes it when the user
            ///     switches, and writing it from outside switches the tab.
            ///   - content: the tabs in bar order, each with the screen it shows.
            public init(
                selection: Binding<Value>,
                @BN.TabContentBuilder < Value> content: () -> [BN.Tab<Value, AnyView>],
            ) {
                _selection = selection
                tabs = content()
            }

            /// The button beside the sections and what a tap on it does. Never a selection.
            /// Swappable while the container lives, as in UIKit: an action that changes meaning with
            /// the app's state does not throw the tabs away. `nil` takes the button away.
            public func action(_ action: BNTabBarAction?, perform handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.action = action
                copy.onAction = handler
                return copy
            }

            /// A run of taps on one section: its value and the position in the run (1, 2, 3…).
            public func onMultiTap(_ handler: @escaping (Value, Int) -> Void) -> Self {
                var copy = self
                copy.onMultiTap = handler
                return copy
            }

            /// Records a modifier set on this tab view itself: it is applied over the environment.
            func adjusting(_ adjustment: @escaping (inout BNTabBarEnvironment) -> Void) -> Self {
                var copy = self
                copy.adjustments.append(adjustment)
                return copy
            }

            /// The tabs' ids for the bar. The "More" section's id is kept out of them.
            var ids: BNTabBarValueIDs<Value> {
                BNTabBarValueIDs(tabs.map(\.value), reserving: [BNTabBarConfiguration().moreItem.id])
            }

            public var body: some View {
                BNTabViewBridge(container: self)
                    .id(tabs.map(\.value))
                    // Full screen, as `TabView` is: the bar pins itself to the safe area, and the tabs'
                    // content reads its own.
                    .ignoresSafeArea()
            }
        }
    }

    /// The UIKit bridge under ``BN/TabView``. Kept apart so the public type can
    /// be an ordinary view — the `.id` that rebuilds it for a new set of tabs has to sit outside.
    struct BNTabViewBridge<Value: Hashable>: UIViewControllerRepresentable {
        let container: BN.TabView<Value>

        func makeCoordinator() -> Coordinator {
            Coordinator(container: container)
        }

        func makeUIViewController(context: Context) -> BNTabBarContainerViewController {
            let coordinator = context.coordinator
            var settings = context.environment.bnTabBar
            for adjustment in container.adjustments {
                adjustment(&settings)
            }
            let ids = container.ids
            let tabs = zip(container.tabs, ids.ids).map { tab, id in
                let host = UIHostingController(rootView: hosted(tab, in: context))
                coordinator.hosts[id] = host
                return BNTabBarContainerViewController.Tab(item: tab.item(id: id), viewController: host)
            }
            let controller = BNTabBarContainerViewController(
                tabs: tabs,
                action: container.action,
                configuration: settings.configuration,
                theme: settings.theme ?? .standard,
                margin: settings.margin ?? 16,
                contentGap: settings.contentGap ?? 16,
                material: settings.material ?? BNTabBarView.standardMaterial,
                lensRenderer: settings.lensRenderer ?? BNMaskedLensRenderer(),
                itemRenderer: settings.itemRenderer,
                haptics: settings.haptics ?? BNTabBarHaptics(),
            )
            // The container speaks in ids, the host in values, and the coordinator's tab view
            // translates.
            controller.onSelect = { id in
                guard let value = coordinator.container.ids.value(for: id) else { return }
                coordinator.container.selection = value
            }
            controller.onAction = { coordinator.container.onAction?() }
            controller.onMultiTap = { id, count in
                guard let value = coordinator.container.ids.value(for: id) else { return }
                coordinator.container.onMultiTap?(value, count)
            }
            // The container shows its first tab when its view loads; loading it now lets the
            // binding's tab replace that before anything reaches the screen.
            controller.loadViewIfNeeded()
            if let id = ids.id(for: container.selection), controller.selectedTabID != id {
                controller.select(tabID: id, animated: false)
            }
            return controller
        }

        func updateUIViewController(_ controller: BNTabBarContainerViewController, context: Context) {
            let coordinator = context.coordinator
            coordinator.container = container
            let ids = container.ids
            for (tab, id) in zip(container.tabs, ids.ids) {
                coordinator.hosts[id]?.rootView = hosted(tab, in: context)
            }
            // Guaranteed the same values by the `.id` above; redraws only if a badge or title moved.
            controller.updateItems(zip(container.tabs, ids.ids).map { tab, id in tab.item(id: id) })
            if controller.action != container.action {
                controller.action = container.action
            }
            if let id = ids.id(for: container.selection), controller.selectedTabID != id {
                controller.select(tabID: id, animated: !context.transaction.disablesAnimations)
            }
        }

        private func hosted(_ tab: BN.Tab<Value, AnyView>, in context: Context) -> AnyView {
            AnyView((tab.content ?? AnyView(EmptyView())).environment(\.self, context.environment))
        }

        final class Coordinator {
            var container: BN.TabView<Value>
            var hosts: [String: UIHostingController<AnyView>] = [:]

            init(container: BN.TabView<Value>) {
                self.container = container
            }
        }
    }
#endif
