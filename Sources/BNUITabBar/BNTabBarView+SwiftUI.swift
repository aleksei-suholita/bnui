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
        /// binding holds, so the truth stays with the host exactly as it does in UIKit.
        ///
        /// ```swift
        /// content
        ///     .safeAreaInset(edge: .bottom) {
        ///         BN.TabBar(selection: $tab, items: items)
        ///             .onReselect { scrollToTop($0) }
        ///             .padding(.horizontal, 16)
        ///     }
        /// ```
        ///
        /// Takes the offered width and its own height. The height does not collapse when the bar is
        /// hidden — the slide off screen needs the room — so a host that insets its content by the bar
        /// reads ``onEffectiveHeightChange(_:)``, which does drop to zero.
        ///
        /// The material, the lens, the item renderer and the haptics are read once, when the bar is
        /// made: none of them can be compared, and replacing one rebuilds the whole bar.
        struct TabBar: UIViewRepresentable {
            @Binding public var selection: String
            public var items: [BNTabBarItem]
            public var action: BNTabBarAction?
            /// Driven by the host — a full-screen scene, a modal sheet. The keyboard is handled by the
            /// bar itself.
            public var presentation: BNTabBarPresentation
            public var configuration: BNTabBarConfiguration
            public var theme: BNTabBarTheme

            let material: any BNTabBarMaterial
            let lensRenderer: any BNTabBarLensRenderer
            let itemRenderer: (any BNTabBarItemRenderer)?
            let haptics: BNTabBarHaptics

            var onReselect: ((String) -> Void)?
            var onMultiTap: ((String, Int) -> Void)?
            var onAction: (() -> Void)?
            var onLongPress: ((String) -> Void)?
            var onEffectiveHeightChange: ((CGFloat) -> Void)?
            var onAccessoryTap: (() -> Void)?
            var accessory: Accessory?

            public init(
                selection: Binding<String>,
                items: [BNTabBarItem],
                action: BNTabBarAction? = nil,
                presentation: BNTabBarPresentation = .expanded,
                configuration: BNTabBarConfiguration = BNTabBarConfiguration(),
                theme: BNTabBarTheme = .standard,
                material: any BNTabBarMaterial = BNTabBarView.standardMaterial,
                lensRenderer: any BNTabBarLensRenderer = BNMaskedLensRenderer(),
                itemRenderer: (any BNTabBarItemRenderer)? = nil,
                haptics: BNTabBarHaptics = BNTabBarHaptics(),
            ) {
                _selection = selection
                self.items = items
                self.action = action
                self.presentation = presentation
                self.configuration = configuration
                self.theme = theme
                self.material = material
                self.lensRenderer = lensRenderer
                self.itemRenderer = itemRenderer
                self.haptics = haptics
            }

            // MARK: - Events and slots

            /// The already-active section was chosen again.
            public func onReselect(_ handler: @escaping (String) -> Void) -> Self {
                var copy = self
                copy.onReselect = handler
                return copy
            }

            /// A run of taps on one section: its id and the position in the run (1, 2, 3…).
            public func onMultiTap(_ handler: @escaping (String, Int) -> Void) -> Self {
                var copy = self
                copy.onMultiTap = handler
                return copy
            }

            public func onAction(_ handler: @escaping () -> Void) -> Self {
                var copy = self
                copy.onAction = handler
                return copy
            }

            /// Long press on a section. Unlike UIKit's ``BNTabBarView/onLongPress``, no view comes with
            /// the id: a SwiftUI menu is not anchored to a `UIView`. Handled or not also decides whether
            /// VoiceOver offers the "Options" action.
            public func onLongPress(_ handler: @escaping (String) -> Void) -> Self {
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

            // MARK: - UIViewRepresentable

            public func makeCoordinator() -> Coordinator {
                Coordinator(parent: self)
            }

            public func makeUIView(context: Context) -> BNTabBarView {
                let bar = BNTabBarView(
                    items: items,
                    selectedID: selection,
                    configuration: configuration,
                    theme: theme,
                    material: material,
                    lensRenderer: lensRenderer,
                    haptics: haptics,
                )
                // Each of these setters rebuilds the bar, so an absent one is not set at all.
                if let itemRenderer {
                    bar.itemRenderer = itemRenderer
                }
                if let action {
                    bar.action = action
                }

                // Wired once, through the coordinator: it always holds the latest `BN.TabBar`, so
                // these never go stale and never need re-assigning.
                let coordinator = context.coordinator
                bar.onSelect = { coordinator.parent.selection = $0 }
                bar.onReselect = { coordinator.parent.onReselect?($0) }
                bar.onMultiTap = { coordinator.parent.onMultiTap?($0, $1) }
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
                let animated = !context.transaction.disablesAnimations

                // The bar's setters rebuild without comparing, so each is guarded here. Items go
                // first: a section that disappears takes the selection with it, and the binding is
                // applied to what remains.
                if bar.items != items {
                    bar.items = items
                }
                if bar.configuration != configuration {
                    bar.configuration = configuration
                }
                if bar.theme != theme {
                    bar.theme = theme
                }
                if bar.action != action {
                    bar.action = action
                }
                if bar.selectedID != selection {
                    bar.setSelectedID(selection, animated: animated)
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

            /// Set only when whether there is a handler changes: the setter republishes the VoiceOver
            /// action on every section.
            private func applyLongPress(to bar: BNTabBarView, coordinator: Coordinator) {
                let wantsLongPress = onLongPress != nil
                guard (bar.onLongPress != nil) != wantsLongPress else { return }
                bar.onLongPress = wantsLongPress ? { id, _ in coordinator.parent.onLongPress?(id) } : nil
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
        public final class Coordinator {
            var parent: BN.TabBar
            var accessoryHost: BNHostingView<AnyView>?
            var accessoryShape: AccessoryShape?

            init(parent: BN.TabBar) {
                self.parent = parent
            }
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
