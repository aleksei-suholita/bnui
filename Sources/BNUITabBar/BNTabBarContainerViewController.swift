#if canImport(UIKit)
    import UIKit

    /// Replaces `UITabBarController`: it hosts the tab content controllers and floats a
    /// ``BNTabBarView`` capsule over them. The bar only draws and reports — this container owns the
    /// truth (which tab is visible) and swaps the child in response, the way `UITabBarController`
    /// does it itself.
    public final class BNTabBarContainerViewController: UIViewController {
        /// One tab: the bar item to draw and the controller shown when it is selected.
        public struct Tab {
            public let item: BNTabBarItem
            public let viewController: UIViewController

            public init(item: BNTabBarItem, viewController: UIViewController) {
                self.item = item
                self.viewController = viewController
            }
        }

        /// The user chose a different section, and the container has already put it on screen.
        ///
        /// Reported after the fact rather than asked beforehand: the container owns the switch.
        /// Not fired by ``select(tabID:animated:)`` — a host that moved the selection itself
        /// already knows, and hearing it back is how a SwiftUI binding ends up in a loop.
        public var onSelect: ((String) -> Void)?
        /// A run of taps on one section (its id and the position in the run: 1, 2, 3…). Left to the
        /// host to interpret — a hidden debug entry is the usual reader.
        public var onMultiTap: ((String, Int) -> Void)?
        /// The bar's action button was tapped. Never a selection — the container owns no flow of
        /// its own, so it hands this straight out.
        public var onAction: (() -> Void)?

        /// The bar's action button, swappable after the fact. A host whose action changes meaning
        /// with the app's state — add something, or deal with what is happening right now — has
        /// nowhere else to say so, and rebuilding the container would throw the tabs away with it.
        public var action: BNTabBarAction? {
            get { tabBar.action }
            set { tabBar.action = newValue }
        }

        /// The section currently on screen.
        public private(set) var selectedTabID: String?

        private var tabs: [Tab]
        private let tabBar: BNTabBarView
        private let barMargin: CGFloat
        private let barContentGap: CGFloat
        private var currentChild: UIViewController?
        private var latestBarHeight: CGFloat = 0

        /// - Parameters:
        ///   - tabs: the tabs in bar order, each a bar item and the controller shown when it is
        ///     selected. At least one; the first is on screen at start.
        ///   - action: the button beside the sections. Tapping it is reported through
        ///     ``onAction``, never selected.
        ///   - configuration: composition — where the capsule sits, whether labels show.
        ///   - theme: looks — colours, geometry, type and motion.
        ///   - margin: inset of the floating capsule from the safe-area edges.
        ///   - contentGap: distance kept between the bar and the content it must never cover.
        ///   - material: the bar's surface, as ``BNTabBarView/material``.
        ///   - lensRenderer: the selection lens, as ``BNTabBarView/lensRenderer``.
        ///   - itemRenderer: draws the sections, as ``BNTabBarView/itemRenderer``; `nil` keeps the
        ///     bar's own.
        ///   - haptics: the bar's haptics, as ``BNTabBarView/haptics``.
        public init(
            tabs: [Tab],
            action: BNTabBarAction? = nil,
            configuration: BNTabBarConfiguration = BNTabBarConfiguration(),
            theme: BNTabBarTheme = BNTabBarTheme(),
            margin: CGFloat = 16,
            contentGap: CGFloat = 16,
            material: any BNTabBarMaterial = BNTabBarView.standardMaterial,
            lensRenderer: any BNTabBarLensRenderer = BNMaskedLensRenderer(),
            itemRenderer: (any BNTabBarItemRenderer)? = nil,
            haptics: BNTabBarHaptics = BNTabBarHaptics(),
        ) {
            precondition(!tabs.isEmpty, "BNTabBarContainerViewController needs at least one tab")
            self.tabs = tabs
            barMargin = margin
            barContentGap = contentGap
            tabBar = BNTabBarView(
                items: tabs.map(\.item),
                configuration: configuration,
                theme: theme,
                material: material,
                lensRenderer: lensRenderer,
                haptics: haptics,
            )
            super.init(nibName: nil, bundle: nil)
            // Set after `super.init` rather than through the initialiser: an action fixes the bar's
            // composition (sections leading, action trailing), and the bar rebuilds itself for it.
            // The item renderer rebuilds it too, so an absent one is not set at all.
            if let itemRenderer {
                tabBar.itemRenderer = itemRenderer
            }
            tabBar.action = action
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override public func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground

            wireBar()
            tabBar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(tabBar)
            NSLayoutConstraint.activate([
                tabBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: barMargin),
                tabBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -barMargin),
                tabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            ])

            if let first = tabs.first {
                selectedTabID = first.item.id
                show(first.viewController)
            }
        }

        /// Moves to a section from the outside — after saving in a modal flow, say. Unknown ids are
        /// ignored rather than trapped: an id is data, and a stale one must not crash the app.
        public func select(tabID: String, animated: Bool = true) {
            guard let tab = tabs.first(where: { $0.item.id == tabID }) else { return }
            tabBar.setSelectedID(tabID, animated: animated)
            selectedTabID = tabID
            show(tab.viewController)
        }

        /// Redraws the sections — a badge that counts something, a title that follows the locale —
        /// without touching the content under them.
        ///
        /// The ids have to be the tabs' ids, in the same order: the content controllers are fixed
        /// at creation, so a different set of tabs is a different container. A mismatch is a
        /// programming error and changes nothing.
        public func updateItems(_ items: [BNTabBarItem]) {
            guard items.map(\.id) == tabs.map(\.item.id) else {
                assertionFailure("updateItems changes how the tabs look, not which tabs there are")
                return
            }
            guard items != tabs.map(\.item) else { return }
            tabs = zip(tabs, items).map { Tab(item: $1, viewController: $0.viewController) }
            // Every id survives, so the bar keeps its selection through the rebuild.
            tabBar.items = items
        }

        private func wireBar() {
            tabBar.onSelect = { [weak self] id in self?.selectTab(id: id) }
            tabBar.onMultiTap = { [weak self] id, count in self?.onMultiTap?(id, count) }
            tabBar.onAction = { [weak self] in self?.onAction?() }
            tabBar.onEffectiveHeightChange = { [weak self] height in
                self?.latestBarHeight = height
                self?.applyContentInsets()
            }
        }

        private func selectTab(id: String) {
            guard let tab = tabs.first(where: { $0.item.id == id }) else { return }
            selectedTabID = id
            show(tab.viewController)
            onSelect?(id)
        }

        /// Containment swap. The controllers are long-lived (owned by their coordinators), so
        /// detaching one never destroys its view — scroll position and navigation stack survive the
        /// round trip — and add/remove keeps the appearance callbacks correct.
        private func show(_ viewController: UIViewController) {
            guard viewController !== currentChild else { return }
            let previous = currentChild

            addChild(viewController)
            viewController.view.translatesAutoresizingMaskIntoConstraints = false
            // Below the capsule so the bar always floats on top of the content.
            view.insertSubview(viewController.view, belowSubview: tabBar)
            NSLayoutConstraint.activate([
                viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            viewController.didMove(toParent: self)

            previous?.willMove(toParent: nil)
            previous?.view.removeFromSuperview()
            previous?.removeFromParent()

            currentChild = viewController
            applyContentInsets()
        }

        /// Every child keeps its content clear of the floating bar. The inset tracks the bar's
        /// measured height, so it grows with Dynamic Type instead of guessing a fixed number.
        private func applyContentInsets() {
            let bottom = latestBarHeight + barContentGap
            for tab in tabs {
                tab.viewController.additionalSafeAreaInsets.bottom = bottom
            }
        }
    }
#endif
