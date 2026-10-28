#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// Replaces `UITabBarController`: it holds a controller per tab and floats a ``BNTabBarView``
    /// capsule over them. The bar only draws and reports — this controller owns the truth (which
    /// tab is on screen) and swaps the content in response, the way `UITabBarController` does it.
    ///
    /// It speaks UIKit's words where they mean the same thing. A screen in a tab finds it as
    /// `bnTabBarController`, as it would find `tabBarController`, and ``setTabBarHidden(_:animated:)``
    /// hides the bar — a screen that is to be without it calls it as it appears. A second tap on the
    /// tab on screen takes its stack back to the root. Every tab keeps its content clear of the bar
    /// through its safe area: up to the bar's top, or down to the bottom edge while the bar is hidden.
    /// The tabs' stacks are plain `UINavigationController`s.
    ///
    /// Where the system moves its own bars into a strip beside the content — iPhone Duo, with the
    /// app built against the iOS 27.1 SDK — the bar stands in that strip as a column of icons, at
    /// its bottom, where the system keeps its own tab bar. A tab's controller opts out the way it
    /// does under `UITabBarController`: its `preferredVerticalBarBehavior` is `.disabled`, and the
    /// bar goes back to the bottom with the system's.
    public final class BNTabBarController: UIViewController {
        /// One tab: the bar item to draw and the controller shown when it is selected.
        public struct Tab {
            public let item: BNTabBarItem
            public let viewController: UIViewController

            public init(item: BNTabBarItem, viewController: UIViewController) {
                self.item = item
                self.viewController = viewController
            }
        }

        /// Where the bar stands as a row along the bottom. A column in iPhone Duo's strip stands
        /// where the strip puts it, whatever this says.
        public nonisolated enum Placement: Equatable, Sendable {
            /// Where the system's floating tab bar stands on iOS 26: 21 pt off the sides of the
            /// safe area and off the bottom edge of the screen, home indicator or not. The same on
            /// every version — the kit's bar floats on all of them.
            case system
            /// `margin` off the sides of the safe area, standing on its bottom edge — above the home
            /// indicator, where there is one.
            case safeArea(margin: CGFloat)
        }

        /// Asked before a tab the user chose is selected, and before a second tap on the tab on
        /// screen takes it back to its root: `false` keeps everything where it is. For a tab that
        /// opens something rather than being a place — a locked one that offers an invitation.
        ///
        /// Not asked for ``select(tabID:animated:)``: the host chose that itself.
        public var shouldSelect: ((String) -> Bool)?
        /// The user chose a different tab, and the controller has already put it on screen. Also
        /// said when ``tabs`` dropped the tab on screen and the first one took its place.
        ///
        /// Not fired by ``select(tabID:animated:)`` — a host that moved the selection itself
        /// already knows, and hearing it back is how a SwiftUI binding ends up in a loop.
        public var onSelect: ((String) -> Void)?
        /// The user tapped the tab already on screen, and its stack is on its way back to the root
        /// — a navigation controller's is; another controller is left as it is. The place to
        /// scroll a root back to its top.
        public var onReselect: ((String) -> Void)?
        /// A run of taps on one tab (its id and the position in the run: 1, 2, 3…). Left to the
        /// host to interpret — a hidden debug entry is the usual reader.
        public var onMultiTap: ((String, Int) -> Void)?
        /// The bar's action button was tapped. Never a selection — the controller owns no flow of
        /// its own, so it hands this straight out.
        public var onAction: (() -> Void)?

        /// The bar's action button, swappable after the fact. A host whose action changes meaning
        /// with the app's state — add something, or deal with what is happening right now — has
        /// nowhere else to say so, and rebuilding the controller would throw the tabs away with it.
        public var action: BNTabBarAction? {
            get { tabBar.action }
            set {
                tabBar.action = newValue
                // The action is part of the column's length: whether the bar fits the strip may
                // have changed with it.
                viewIfLoaded?.setNeedsLayout()
            }
        }

        /// The tab currently on screen.
        public internal(set) var selectedTabID: String?

        /// The controller of the tab on screen, as `UITabBarController` names it.
        /// ``select(tabID:animated:)`` changes it.
        public var selectedViewController: UIViewController? {
            storedTabs.first { $0.item.id == selectedTabID }?.viewController
        }

        /// The tabs in bar order. Set it to change which tabs there are — one that appears with an
        /// invitation, a set an experiment decides. The tab on screen stays on screen while it is
        /// among them; otherwise the first one takes its place, and ``onSelect`` says so.
        ///
        /// At least one tab: an empty list is a programming error and changes nothing.
        public var tabs: [Tab] {
            get { storedTabs }
            set { replaceTabs(with: newValue) }
        }

        /// The tabs' bar items, in bar order. Set it to redraw them — a title that follows the
        /// locale — without touching the content under them; one badge or one selected icon at a
        /// time is ``setBadge(_:for:)`` or ``setSelectedIcon(_:for:)``.
        ///
        /// The ids have to be the tabs' ids, in the same order: which tabs there are is ``tabs``. A
        /// mismatch is a programming error and changes nothing.
        public var items: [BNTabBarItem] {
            get { storedTabs.map(\.item) }
            set {
                guard newValue.map(\.id) == storedTabs.map(\.item.id) else {
                    assertionFailure("items changes how the tabs look; tabs changes which tabs there are")
                    return
                }
                guard newValue != items else { return }
                storedTabs = zip(storedTabs, newValue).map { Tab(item: $1, viewController: $0.viewController) }
                // Every id survives, so the bar keeps its selection through the rebuild.
                tabBar.items = newValue
            }
        }

        var storedTabs: [Tab]
        /// The bar; the vertical bar's placement measures the room it needs.
        let tabBar: BNTabBarView
        let placement: Placement
        let contentGap: CGFloat
        /// The tab on screen; read by the vertical bar's configuration, which defers to it.
        var currentChild: UIViewController?
        /// Set by ``setTabBarHidden(_:animated:)``.
        var isBarHidden = false
        /// The bar's height while it is shown. The bar reports none while it is hidden or under the
        /// keyboard, and the screens keep the inset of the bar they will get back.
        var expandedHeight: CGFloat = 0
        /// Where the controller itself is on its way on or off screen; the tab on screen follows it.
        var appearance = Appearance.off
        /// The tab whose appearance callbacks are open, to be closed with the controller's own.
        var childInTransition: UIViewController?
        /// The bar as a row: along the bottom, inset from the sides as ``Placement`` says.
        private var rowConstraints: [NSLayoutConstraint] = []
        /// The bar as a column: left, top, width and height, set to the rectangle the strip gives.
        private var columnConstraints: [NSLayoutConstraint] = []

        /// Off the sides and the bottom edge in ``Placement/system``.
        static let systemMargin: CGFloat = 21

        /// - Parameters:
        ///   - tabs: the tabs in bar order, each a bar item and the controller shown when it is
        ///     selected. At least one; the first is on screen at start.
        ///   - action: the button beside the sections. Tapping it is reported through
        ///     ``onAction``, never selected.
        ///   - configuration: composition — where the capsule sits, whether labels show.
        ///   - theme: looks — colours, geometry, type and motion.
        ///   - placement: where the bar stands as a row along the bottom.
        ///   - contentGap: distance kept between the bar's top and the content's safe area.
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
            placement: Placement = .system,
            contentGap: CGFloat = 0,
            material: any BNTabBarMaterial = BNTabBarView.standardMaterial,
            lensRenderer: any BNTabBarLensRenderer = BNMaskedLensRenderer(),
            itemRenderer: (any BNTabBarItemRenderer)? = nil,
            haptics: BNTabBarHaptics = BNTabBarHaptics(),
        ) {
            precondition(!tabs.isEmpty, "BNTabBarController needs at least one tab")
            storedTabs = tabs
            selectedTabID = tabs.first?.item.id
            self.placement = placement
            self.contentGap = contentGap
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
            // Every tab is a child, on screen or not, as under `UITabBarController`: a screen in a
            // tab out of sight finds the controller too, and its stack still says when it changes.
            tabs.forEach { adopt($0.viewController) }
        }

        nonisolated deinit {}

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override public func viewDidLoad() {
            super.viewDidLoad()
            wireBar()
            tabBar.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(tabBar)
            rowConstraints = makeRowConstraints()
            columnConstraints = [
                tabBar.leftAnchor.constraint(equalTo: view.leftAnchor),
                tabBar.topAnchor.constraint(equalTo: view.topAnchor),
                tabBar.widthAnchor.constraint(equalToConstant: 0),
                tabBar.heightAnchor.constraint(equalToConstant: 0),
            ]
            NSLayoutConstraint.activate(rowConstraints)
            observeVerticalBar()
            expandedHeight = tabBar.effectiveHeight
            showSelected()
        }

        override public func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()
            placeBar()
        }

        /// Places the bar again once the tab on screen is laid out. Where the system's buttons stand
        /// in the vertical strip is known only after the tab's navigation has laid them out, which
        /// happens below this view — later in the same pass. Read before it, a first showing found
        /// no buttons and a turn found them where they stood before it.
        override public func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            currentChild?.view.layoutIfNeeded()
            placeBar()
        }

        override public func viewSafeAreaInsetsDidChange() {
            super.viewSafeAreaInsetsDidChange()
            applyContentInsets()
        }

        /// The system settles its bars once a turn, an opening or a closing is over; the bar is
        /// placed again then, against where they ended up.
        override public func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.view.setNeedsLayout()
            }
        }

        /// The tab on screen decides the status bar, as under `UITabBarController`.
        override public var childForStatusBarStyle: UIViewController? {
            currentChild
        }

        override public var childForStatusBarHidden: UIViewController? {
            currentChild
        }

        /// Moves to a tab from the outside — after saving in a modal flow, say. Unknown ids are
        /// ignored rather than trapped: an id is data, and a stale one must not crash the app.
        public func select(tabID: String, animated: Bool = true) {
            guard storedTabs.contains(where: { $0.item.id == tabID }) else { return }
            selectedTabID = tabID
            tabBar.setSelectedID(tabID, animated: animated)
            showSelected()
        }

        /// Shows `badge` on the tab with `tabID`, or takes its badge away with `nil` — drawn in place,
        /// under a finger on the bar too. Found by id rather than by position, so it holds when the
        /// host orders its tabs differently. Unknown ids are ignored, as in ``select(tabID:animated:)``.
        public func setBadge(_ badge: BNBadge?, for tabID: String) {
            guard let index = storedTabs.firstIndex(where: { $0.item.id == tabID }) else { return }
            var items = items
            items[index].badge = badge
            self.items = items
        }

        /// Shows `icon` on the tab with `tabID` while it is selected, or its own icon again with
        /// `nil` — a camera's tab showing the filter in use. Changed in place and animated: a symbol
        /// gives way by the system's replace effect, a picture cross-fades. Unknown ids are ignored,
        /// as in ``select(tabID:animated:)``.
        public func setSelectedIcon(_ icon: BNTabBarItem.Icon?, for tabID: String) {
            guard let index = storedTabs.firstIndex(where: { $0.item.id == tabID }) else { return }
            var items = items
            items[index].selectedIcon = icon
            self.items = items
        }

        // MARK: - Row or column

        private func makeRowConstraints() -> [NSLayoutConstraint] {
            let safeArea = view.safeAreaLayoutGuide
            switch placement {
            case .system:
                return [
                    tabBar.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: Self.systemMargin),
                    tabBar.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -Self.systemMargin),
                    tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Self.systemMargin),
                ]
            case let .safeArea(margin):
                return [
                    tabBar.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: margin),
                    tabBar.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -margin),
                    tabBar.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
                ]
            }
        }

        /// A column in the strip the system keeps for bars beside the content, where there is one
        /// and the bar fits in it; a row along the bottom otherwise — the camera halfway down the
        /// strip of a closed iPhone Duo in landscape leaves too little below it.
        private func placeBar() {
            let column = verticalBarStrip()?.column(
                in: view.bounds,
                top: view.safeAreaInsets.top,
                bottom: view.safeAreaInsets.bottom,
                thickness: tabBar.columnThickness,
                minimumLength: tabBar.minimumColumnLength,
                gap: tabBar.columnGap,
            )
            if let column {
                let values = [column.minX, column.minY, column.width, column.height]
                for (constraint, value) in zip(columnConstraints, values) where abs(constraint.constant - value) > 0.5 {
                    constraint.constant = value
                }
            }
            let axis: NSLayoutConstraint.Axis = column == nil ? .horizontal : .vertical
            guard axis != tabBar.axis else { return }
            NSLayoutConstraint.deactivate(axis == .vertical ? rowConstraints : columnConstraints)
            NSLayoutConstraint.activate(axis == .vertical ? columnConstraints : rowConstraints)
            tabBar.axis = axis
            applyContentInsets()
        }
    }

    public extension UIViewController {
        /// The ``BNTabBarController`` this controller is in — `tabBarController`'s counterpart.
        /// Every tab's controller is the tab bar controller's child, on screen or not, so a screen in
        /// a tab out of sight finds it too. `nil` outside one.
        var bnTabBarController: BNTabBarController? {
            var ancestor = parent
            while let controller = ancestor {
                if let tabBarController = controller as? BNTabBarController {
                    return tabBarController
                }
                ancestor = controller.parent
            }
            return nil
        }
    }
#endif
