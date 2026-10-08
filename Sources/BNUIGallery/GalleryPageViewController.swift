#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// A page: the demo on a full-screen stage, the knobs in an inspector.
    ///
    /// On a phone the inspector is a drawer whose heights `GalleryDrawer` works out and drives;
    /// the stage above always ends where the drawer begins, so no height of it hides the demo. On
    /// a regular-width screen the inspector is a sidebar and nothing moves.
    public final class GalleryPageViewController: UIViewController {
        private let page: any GalleryPage
        private let demoController: UIViewController?
        private let demoView: UIView
        private let stage: GalleryStageView
        private let inspector: GalleryInspectorView
        private let stageItem = UIBarButtonItem()
        private var drawer: GalleryDrawer?
        private var backdrop: GalleryBackdrop
        private var compactConstraints: [NSLayoutConstraint] = []
        private var regularConstraints: [NSLayoutConstraint] = []
        /// What the pop gesture was set to before this page took it away. `nil` while off screen.
        private var popGestureWasEnabled: Bool?

        public init(page: any GalleryPage) {
            self.page = page
            // Built here rather than in viewDidLoad so every piece can be a constant; the knobs
            // capture the demo, so it has to exist before them.
            let demoController = page.makeDemoViewController()
            let demoView = demoController?.view ?? page.makeDemoView()
            let placement: GalleryStageView.Placement = page.isBackground ? .background : page.fillsDemoArea ? .filling : .centred
            let stage = GalleryStageView(demoView: demoView, placement: placement, feedEdge: page.eventFeedEdge)
            self.demoController = demoController
            self.demoView = demoView
            self.stage = stage
            inspector = GalleryInspectorView(knobs: page.makeKnobs(for: demoView))
            backdrop = page.backdrop
            super.init(nibName: nil, bundle: nil)
            title = page.title
            navigationItem.largeTitleDisplayMode = .never
            (demoView as? any GalleryEventReporting)?.onGalleryEvent = { [weak stage] event in
                stage?.post(event)
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        // MARK: - Lifecycle

        override public func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = BNGalleryColor.groupedBackground

            // A controller-backed demo becomes a child, so its own children — a system tab bar
            // controller, say — get appearance callbacks and traits the normal way.
            if let demoController {
                addChild(demoController)
            }
            stage.translatesAutoresizingMaskIntoConstraints = false
            inspector.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stage)
            view.addSubview(inspector)
            demoController?.didMove(toParent: self)

            let drawer = GalleryDrawer(host: view, inspector: inspector, stage: stage, page: page)
            self.drawer = drawer
            inspector.onReset = { [weak self] in self?.resetAll() }
            buildConstraints(drawerHeight: drawer.height)
            stage.setBackdrop(backdrop)
            navigationItem.rightBarButtonItem = stageItem
            applyEnvironment(GalleryEnvironment.current)
            applySizeClass()
            if #available(iOS 17.0, *) {
                registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (controller: GalleryPageViewController, _) in
                    controller.applySizeClass()
                }
            }
        }

        override public func traitCollectionDidChange(_ previous: UITraitCollection?) {
            super.traitCollectionDidChange(previous)
            // iOS 16 has no trait registration; the same change arrives here instead.
            guard #unavailable(iOS 17.0) else { return }
            if previous?.horizontalSizeClass != traitCollection.horizontalSizeClass {
                applySizeClass()
            }
        }

        override public func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            drawer?.snapToCurrentStop()
        }

        /// The demos are driven by finger — a drag along a tab bar, a press held on a button — and
        /// the system's edge swipe steals any of those that starts near the left edge. So it is
        /// off while a page is on screen, and restored on the way out: the gallery may sit on a
        /// host app's own navigation stack.
        override public func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let pop = navigationController?.interactivePopGestureRecognizer else { return }
            popGestureWasEnabled = pop.isEnabled
            pop.isEnabled = false
        }

        override public func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let popGestureWasEnabled,
                  let pop = navigationController?.interactivePopGestureRecognizer
            else { return }
            pop.isEnabled = popGestureWasEnabled
            self.popGestureWasEnabled = nil
        }

        // MARK: - Layout

        private var isCompact: Bool {
            traitCollection.horizontalSizeClass != .regular
        }

        private func buildConstraints(drawerHeight: NSLayoutConstraint) {
            let safe = view.safeAreaLayoutGuide
            // Hidden, the keyboard guide sits on the screen's bottom edge rather than the safe
            // area's, so the drawer rests where it always does and rises with a keyboard. iOS 16
            // has no switch: there the drawer rests on the safe area's edge instead.
            if #available(iOS 17.0, *) {
                view.keyboardLayoutGuide.usesBottomSafeArea = false
            }

            NSLayoutConstraint.activate([
                stage.topAnchor.constraint(equalTo: view.topAnchor),
                stage.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                stage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                stage.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                stage.demoArea.topAnchor.constraint(equalTo: safe.topAnchor),
                stage.demoArea.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
                inspector.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
                inspector.topAnchor.constraint(greaterThanOrEqualTo: safe.topAnchor),
            ])
            compactConstraints = [
                inspector.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                inspector.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                drawerHeight,
                stage.demoArea.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
                stage.demoArea.bottomAnchor.constraint(equalTo: inspector.topAnchor),
            ]
            regularConstraints = [
                inspector.topAnchor.constraint(equalTo: safe.topAnchor),
                inspector.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                inspector.widthAnchor.constraint(equalToConstant: BNGalleryMetrics.sidebarWidth),
                stage.demoArea.trailingAnchor.constraint(equalTo: inspector.leadingAnchor),
                stage.demoArea.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            ]
        }

        private func applySizeClass() {
            NSLayoutConstraint.deactivate(isCompact ? regularConstraints : compactConstraints)
            NSLayoutConstraint.activate(isCompact ? compactConstraints : regularConstraints)
            inspector.setLayout(isCompact ? .drawer : .sidebar)
            drawer?.isEnabled = isCompact
            inspector.setDetent(isCompact ? drawer?.detent ?? .medium : .expanded)
            view.setNeedsLayout()
        }

        // MARK: - Reset and stage

        /// The page's own reset first, for state no knob owns; then every knob back to its initial
        /// value, which moves the widgets and replays the value into the demo together.
        private func resetAll() {
            page.resetDemo(demoView)
            inspector.rows.forEach { $0.reset() }
            inspector.refreshChanges()
            stage.clearEvents()
        }

        private func applyEnvironment(_ environment: GalleryEnvironment) {
            GalleryEnvironment.current = environment
            guard #available(iOS 17.0, *) else {
                // iOS 16 overrides only the appearance of a view; the menu offers nothing else there.
                let style = environment.appearance.style ?? .unspecified
                stage.overrideUserInterfaceStyle = style
                demoController?.overrideUserInterfaceStyle = style
                refreshStageMenu()
                return
            }
            environment.apply(to: &stage.traitOverrides)
            if let demoController {
                environment.apply(to: &demoController.traitOverrides)
            }
            refreshStageMenu()
        }

        private func applyBackdrop(_ backdrop: GalleryBackdrop) {
            self.backdrop = backdrop
            stage.setBackdrop(backdrop)
            refreshStageMenu()
        }

        /// The prominent bar button arrives with iOS 26; before it, the bold one says the same.
        private static var overriddenStageStyle: UIBarButtonItem.Style {
            if #available(iOS 26.0, *) {
                return .prominent
            }
            return .done
        }

        private func refreshStageMenu() {
            let environment = GalleryEnvironment.current
            stageItem.image = UIImage(systemName: "circle.lefthalf.filled")
            // Filled while anything is overridden: a dark or RTL stage left on from the last page
            // should not be mistaken for the app's own look.
            stageItem.style = environment.isDefault ? .plain : Self.overriddenStageStyle
            stageItem.accessibilityLabel = "Stage"
            stageItem.menu = environment.menu(
                backdrop: page.isBackground ? nil : backdrop,
                onBackdrop: { [weak self] in self?.applyBackdrop($0) },
                onChange: { [weak self] in self?.applyEnvironment($0) },
            )
        }
    }
#endif
