#if canImport(UIKit)
    import BNUICore
    import SwiftUI
    import UIKit

    public extension BN {
        /// ``BNTabBarView`` in a SwiftUI hierarchy — the bar alone, for a host that lays out its own
        /// screen. A host that wants tabs with content under them wants
        /// ``BN/TabView`` instead.
        ///
        /// Selection is a binding: the bar writes the section the user chose and draws whatever the
        /// binding holds, so the truth stays with the host exactly as it does in UIKit. The sections
        /// are ``BN/Tab`` values without a screen:
        ///
        /// ```swift
        /// content
        ///     .safeAreaInset(edge: .bottom) {
        ///         BN.TabBar(selection: $section) {
        ///             BN.Tab("Home", systemImage: "house", value: .home)
        ///             BN.Tab("Stats", systemImage: "chart.bar", value: .stats)
        ///         }
        ///         .onReselect { scrollToTop($0) }
        ///         .padding(.horizontal, 16)
        ///     }
        /// ```
        ///
        /// How it looks comes from the `bnTabBar…` modifiers, here or anywhere above it. Takes the
        /// offered width and its own height. The height does not collapse when the bar is hidden —
        /// the slide off screen needs the room — so a host that insets its content by the bar reads
        /// ``onEffectiveHeightChange(_:)``, which does drop to zero.
        ///
        /// The material, the lens, the item renderer and the haptics are read once, when the bar is
        /// made: none of them can be compared, and replacing one rebuilds the whole bar.
        struct TabBar<Value: Hashable>: UIViewRepresentable {
            @Binding var selection: Value
            let tabs: [BN.Tab<Value, Void>]
            let presentation: BNTabBarPresentation
            var adjustments: [(inout BNTabBarEnvironment) -> Void] = []

            var action: BNTabBarAction?
            var onAction: (() -> Void)?
            var onReselect: ((Value) -> Void)?
            var onMultiTap: ((Value, Int) -> Void)?
            var onLongPress: ((Value) -> Void)?
            var onEffectiveHeightChange: ((CGFloat) -> Void)?
            var onAccessoryTap: (() -> Void)?
            var accessory: Accessory?

            /// - Parameters:
            ///   - selection: the value of the chosen section. The bar writes it when the user
            ///     chooses, and writing it from outside moves the selection.
            ///   - presentation: driven by the host — a full-screen scene, a modal sheet. The
            ///     keyboard is handled by the bar itself.
            ///   - content: the sections in bar order.
            public init(
                selection: Binding<Value>,
                presentation: BNTabBarPresentation = .expanded,
                @BN.TabBarContentBuilder < Value> content: () -> [BN.Tab<Value, Void>],
            ) {
                _selection = selection
                tabs = content()
                self.presentation = presentation
            }

            // MARK: - Events and slots

            /// The button beside the sections and what a tap on it does. Never a selection. `nil`
            /// takes the button away.
            public func action(_ action: BNTabBarAction?, perform handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.action = action
                copy.onAction = handler
                return copy
            }

            /// The already-active section was chosen again.
            public func onReselect(_ handler: @escaping (Value) -> Void) -> Self {
                var copy = self
                copy.onReselect = handler
                return copy
            }

            /// A run of taps on one section: its value and the position in the run (1, 2, 3…).
            public func onMultiTap(_ handler: @escaping (Value, Int) -> Void) -> Self {
                var copy = self
                copy.onMultiTap = handler
                return copy
            }

            /// Long press on a section. Unlike UIKit's ``BNTabBarView/onLongPress``, no view comes with
            /// the value: a SwiftUI menu is not anchored to a `UIView`. Handled or not also decides
            /// whether VoiceOver offers the "Options" action.
            public func onLongPress(_ handler: @escaping (Value) -> Void) -> Self {
                var copy = self
                copy.onLongPress = handler
                return copy
            }

            /// Height the bar occupies, zero while hidden. Reported on the next turn of the main
            /// queue: it is measured during layout, and a SwiftUI state change made from inside layout
            /// is a change made during a view update.
            public func onEffectiveHeightChange(_ handler: @escaping (CGFloat) -> Void) -> Self {
                var copy = self
                copy.onEffectiveHeightChange = handler
                return copy
            }

            /// A SwiftUI view above the bar — a running session, a mini player.
            ///
            /// The content re-renders in place on every update; a change of `width` or `spacing`
            /// rebuilds the bar, the way setting ``BNTabBarView/accessory`` does.
            public func accessory(
                width: BNTabBarAccessory.Width = .matchBar,
                spacing: CGFloat = 8,
                @ViewBuilder content: () -> some View,
            ) -> Self {
                var copy = self
                copy.accessory = Accessory(width: width, spacing: spacing, content: AnyView(content()))
                return copy
            }

            /// The accessory was tapped. Reported without cancelling the accessory's own touches, so
            /// its SwiftUI content keeps its gestures.
            public func onAccessoryTap(_ handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.onAccessoryTap = handler
                return copy
            }

            /// Records a modifier set on this bar itself: it is applied over the environment.
            func adjusting(_ adjustment: @escaping (inout BNTabBarEnvironment) -> Void) -> Self {
                var copy = self
                copy.adjustments.append(adjustment)
                return copy
            }

            // MARK: - UIViewRepresentable

            public func makeCoordinator() -> Coordinator {
                Coordinator(parent: self)
            }

            public func makeUIView(context: Context) -> BNTabBarView {
                let settings = settings(in: context.environment)
                let ids = ids
                let bar = BNTabBarView(
                    items: items(ids),
                    selectedID: ids.id(for: selection),
                    configuration: settings.configuration,
                    theme: settings.theme ?? .standard,
                    material: settings.material ?? BNTabBarView.standardMaterial,
                    lensRenderer: settings.lensRenderer ?? BNMaskedLensRenderer(),
                    haptics: settings.haptics ?? BNTabBarHaptics(),
                )
                // Each of these setters rebuilds the bar, so an absent one is not set at all.
                if let itemRenderer = settings.itemRenderer {
                    bar.itemRenderer = itemRenderer
                }
                if let action {
                    bar.action = action
                }

                // Wired once, through the coordinator: it always holds the latest `BN.TabBar`, so
                // these never go stale and never need re-assigning. The bar speaks in ids, the host
                // in values, and the coordinator's bar translates.
                let coordinator = context.coordinator
                bar.onSelect = { id in
                    guard let value = coordinator.parent.ids.value(for: id) else { return }
                    coordinator.parent.selection = value
                }
                bar.onReselect = { id in
                    guard let value = coordinator.parent.ids.value(for: id) else { return }
                    coordinator.parent.onReselect?(value)
                }
                bar.onMultiTap = { id, count in
                    guard let value = coordinator.parent.ids.value(for: id) else { return }
                    coordinator.parent.onMultiTap?(value, count)
                }
                bar.onAction = { coordinator.parent.onAction?() }
                bar.onEffectiveHeightChange = { height in
                    DispatchQueue.main.async {
                        coordinator.parent.onEffectiveHeightChange?(height)
                    }
                }
                bar.setPresentation(presentation, animated: false)
                applyLongPress(to: bar, coordinator: coordinator)
                applyAccessory(to: bar, context: context)
                return bar
            }

            public func updateUIView(_ bar: BNTabBarView, context: Context) {
                let coordinator = context.coordinator
                coordinator.parent = self
                let settings = settings(in: context.environment)
                let ids = ids
                let animated = !context.transaction.disablesAnimations

                // The bar's setters rebuild without comparing, so each is guarded here. Items go
                // first: a section that disappears takes the selection with it, and the binding is
                // applied to what remains.
                let items = items(ids)
                if bar.items != items {
                    bar.items = items
                }
                let configuration = settings.configuration
                if bar.configuration != configuration {
                    bar.configuration = configuration
                }
                let theme = settings.theme ?? .standard
                if bar.theme != theme {
                    bar.theme = theme
                }
                if bar.action != action {
                    bar.action = action
                }
                if let id = ids.id(for: selection), bar.selectedID != id {
                    bar.setSelectedID(id, animated: animated)
                }
                bar.setPresentation(presentation, animated: animated)
                applyLongPress(to: bar, coordinator: coordinator)
                applyAccessory(to: bar, context: context)
                // The accessory's content may have changed size, and nothing else tells SwiftUI to
                // measure the bar again.
                bar.invalidateIntrinsicContentSize()
            }

            public func sizeThatFits(_ proposal: ProposedViewSize, uiView bar: BNTabBarView, context _: Context) -> CGSize? {
                let offered = proposal.width.flatMap { $0.isFinite ? $0 : nil }
                // Without a width, the bar's own: the capsule at its content width.
                let fitted = bar.systemLayoutSizeFitting(
                    CGSize(width: offered ?? 0, height: 0),
                    withHorizontalFittingPriority: offered == nil ? .fittingSizeLevel : .required,
                    verticalFittingPriority: .fittingSizeLevel,
                )
                // The same floor ``BNTabBarView/effectiveHeight`` keeps, for a bar measured before its
                // sections have a size of their own.
                let geometry = bar.activeTheme.geometry
                let height = max(fitted.height, geometry.effectiveItemHeight + 2 * geometry.capsulePadding)
                return CGSize(width: offered ?? fitted.width, height: height)
            }

            // MARK: - Internals

            /// The sections' ids for the bar. The "More" section's id is kept out of them.
            var ids: BNTabBarValueIDs<Value> {
                BNTabBarValueIDs(tabs.map(\.value), reserving: [BNTabBarConfiguration().moreItem.id])
            }

            private func items(_ ids: BNTabBarValueIDs<Value>) -> [BNTabBarItem] {
                zip(tabs, ids.ids).map { tab, id in tab.item(id: id) }
            }

            /// The environment's settings with this bar's own laid over them.
            private func settings(in environment: EnvironmentValues) -> BNTabBarEnvironment {
                var settings = environment.bnTabBar
                for adjustment in adjustments {
                    adjustment(&settings)
                }
                return settings
            }

            /// Set only when whether there is a handler changes: the setter republishes the VoiceOver
            /// action on every section.
            private func applyLongPress(to bar: BNTabBarView, coordinator: Coordinator) {
                let wantsLongPress = onLongPress != nil
                guard (bar.onLongPress != nil) != wantsLongPress else { return }
                bar.onLongPress = wantsLongPress ? { id, _ in
                    guard let value = coordinator.parent.ids.value(for: id) else { return }
                    coordinator.parent.onLongPress?(value)
                } : nil
            }

            private func applyAccessory(to bar: BNTabBarView, context: Context) {
                let coordinator = context.coordinator
                guard let accessory else {
                    if bar.accessory != nil {
                        bar.accessory = nil
                    }
                    coordinator.accessoryHost = nil
                    coordinator.accessoryShape = nil
                    return
                }
                let shape = AccessoryShape(width: accessory.width, spacing: accessory.spacing, isTappable: onAccessoryTap != nil)
                if let host = coordinator.accessoryHost, coordinator.accessoryShape == shape {
                    host.rootView = accessory.hosted(in: context.environment)
                    return
                }
                // The bar only listens for accessory taps if a handler exists when the accessory is
                // built — so whether there is one is part of the shape, and the handler goes in first.
                bar.onAccessoryTap = onAccessoryTap == nil ? nil : { coordinator.parent.onAccessoryTap?() }
                let host = BNHostingView(accessory.hosted(in: context.environment))
                coordinator.accessoryHost = host
                coordinator.accessoryShape = shape
                bar.accessory = BNTabBarAccessory(view: host, width: accessory.width, spacing: accessory.spacing)
            }
        }
    }

    extension BN.TabBar {
        /// Holds the latest bar for the closures wired once, and the hosted accessory between
        /// updates.
        public final class Coordinator {
            var parent: BN.TabBar<Value>
            var accessoryHost: BNHostingView<AnyView>?
            var accessoryShape: AccessoryShape?

            init(parent: BN.TabBar<Value>) {
                self.parent = parent
            }

            nonisolated deinit {}
        }

        struct Accessory {
            var width: BNTabBarAccessory.Width
            var spacing: CGFloat
            var content: AnyView

            /// The environment is handed across the hosting controller, which does not pass it on
            /// by itself — an accessory reading an observable model from the screen has to find it.
            func hosted(in environment: EnvironmentValues) -> AnyView {
                AnyView(content.environment(\.self, environment))
            }
        }

        /// What the bar is rebuilt for. The content is not part of it — that re-renders in place.
        struct AccessoryShape: Equatable {
            // periphery:ignore - read by the synthesized `==`
            var width: BNTabBarAccessory.Width
            // periphery:ignore - read by the synthesized `==`
            var spacing: CGFloat
            // periphery:ignore - read by the synthesized `==`
            var isTappable: Bool
        }
    }
#endif
