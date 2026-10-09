#if (DEBUG || GalleryInRelease) && canImport(UIKit)
    import BNUI
    import UIKit

    /// A page: the demo on a full-screen stage, the knobs in an inspector.
    ///
    /// On a phone the inspector is a drawer whose heights `GalleryDrawer` works out and drives;
    /// the stage above always ends where the drawer begins, so no height of it hides the demo. On
    /// a regular-width screen the inspector is a sidebar and nothing moves.
    public final class BNGalleryPageViewController: UIViewController {
        private let page: any BNGalleryPage
        private let demoController: UIViewController?
        private let demoView: UIView
        private let stage: GalleryStageView
        private let inspector: GalleryInspectorView
        private let stageItem = UIBarButtonItem()
        private var drawer: GalleryDrawer?
        private var backdrop: BNGalleryBackdrop
        private var compactConstraints: [NSLayoutConstraint] = []
        private var regularConstraints: [NSLayoutConstraint] = []
        /// What each pop gesture was set to before this page took it away. Empty while off screen.
        private var popGesturesWereEnabled: [(gesture: UIGestureRecognizer, wasEnabled: Bool)] = []

        public init(page: any BNGalleryPage) {
            self.page = page
            // Built here rather than in viewDidLoad so every piece can be a constant; the knobs
            // capture the demo, so it has to exist before them.
            let demoController = page.makeDemoViewController()
            let demoView = demoController?.view ?? page.makeDemoView()
            let stage = GalleryStageView(demoView: demoView, layout: page.layout, feedEdge: page.eventFeedEdge)
            self.demoController = demoController
            self.demoView = demoView
            self.stage = stage
            inspector = GalleryInspectorView(knobs: page.makeKnobs(for: demoView))
            backdrop = page.backdrop
            super.init(nibName: nil, bundle: nil)
            title = page.title
            navigationItem.largeTitleDisplayMode = .never
            (demoView as? any BNGalleryEventReporting)?.onGalleryEvent = { [weak stage] event in
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
            observeDemoTyping()
            if #available(iOS 17.0, *) {
                registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (controller: BNGalleryPageViewController, _) in
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
        /// the system's swipe back steals any of those it can: one that starts near the leading
        /// edge and, from iOS 26, a horizontal one anywhere in the content. So both are off while
        /// a page is on screen, and restored on the way out: the gallery may sit on a host app's
        /// own navigation stack.
        override public func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            popGesturesWereEnabled = popGestures.map { ($0, $0.isEnabled) }
            disablePopGestures()
        }

        /// Again once the push has finished, in case the transition handed a gesture back.
        override public func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            disablePopGestures()
            Self.onScreen = self
        }

        override public func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            for (gesture, wasEnabled) in popGesturesWereEnabled {
                gesture.isEnabled = wasEnabled
            }
            popGesturesWereEnabled = []
            if Self.onScreen === self {
                Self.onScreen = nil
            }
        }

        // MARK: - Typing in the demo

        /// Fields of the demo being typed into right now — two for a moment while the focus moves
        /// from one to the next.
        private var demoFieldsEditing = 0
        private var isDemoTyping = false
        private lazy var demoAboveDrawer = stage.demoArea.bottomAnchor.constraint(equalTo: inspector.topAnchor)
        private lazy var demoOnKeyboard = stage.demoArea.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)

        private lazy var keyboardItem = UIBarButtonItem(
            title: "Hide Keyboard",
            image: UIImage(systemName: "keyboard.chevron.compact.down"),
            primaryAction: UIAction { [weak self] _ in self?.view.endEditing(true) },
        )

        /// Typing into the demo tucks the drawer away, so a field or a composer meets the keyboard
        /// the way it would in an app, and puts a button in the bar to put the keyboard down — the
        /// demo itself may have no way to end the typing. A field of the inspector is left alone:
        /// for it the drawer rides up on the keyboard instead.
        private func observeDemoTyping() {
            let center = NotificationCenter.default
            for name in [UITextField.textDidBeginEditingNotification, UITextView.textDidBeginEditingNotification] {
                center.addObserver(self, selector: #selector(demoTypingBegan(_:)), name: name, object: nil)
            }
            for name in [UITextField.textDidEndEditingNotification, UITextView.textDidEndEditingNotification] {
                center.addObserver(self, selector: #selector(demoTypingEnded(_:)), name: name, object: nil)
            }
        }

        @objc private func demoTypingBegan(_ notification: Notification) {
            guard isInDemo(notification) else { return }
            demoFieldsEditing += 1
            showDemoTyping(true)
        }

        /// Moving from one field of the demo to the next ends one and begins the other within the
        /// same tap, so the drawer comes back only if nothing began by the time the tap is over.
        @objc private func demoTypingEnded(_ notification: Notification) {
            guard isInDemo(notification) else { return }
            demoFieldsEditing = max(demoFieldsEditing - 1, 0)
            Task { @MainActor [weak self] in
                guard let self, demoFieldsEditing == 0 else { return }
                showDemoTyping(false)
            }
        }

        private func isInDemo(_ notification: Notification) -> Bool {
            (notification.object as? UIView)?.isDescendant(of: demoView) == true
        }

        private func showDemoTyping(_ typing: Bool) {
            isDemoTyping = typing
            applyDemoEdge()
            // A sidebar on a regular-width screen is beside the keyboard, not under it.
            drawer?.isTucked = typing && isCompact
            navigationItem.rightBarButtonItems = typing ? [stageItem, keyboardItem] : [stageItem]
        }

        /// The stage's bottom edge on a phone: the drawer's top, or the keyboard's while the demo
        /// is typed into. On a regular-width screen the sidebar's constraints own it.
        private func applyDemoEdge() {
            let onKeyboard = isDemoTyping && isCompact
            let wanted = onKeyboard ? demoOnKeyboard : isCompact ? demoAboveDrawer : nil
            // Off before on: two bottom edges at once cannot both hold.
            for edge in [demoAboveDrawer, demoOnKeyboard] where edge !== wanted {
                edge.isActive = false
            }
            wanted?.isActive = true
        }

        // MARK: - Events

        /// The page on screen, whose feed ``BNGallery/post(_:)`` writes to. One at a time: a page
        /// pushed over another takes the feed until it goes.
        private weak static var onScreen: BNGalleryPageViewController?

        static func postToPageOnScreen(_ event: String) {
            onScreen?.stage.post(event)
        }

        private var popGestures: [UIGestureRecognizer] {
            guard let navigationController else { return [] }
            var gestures = [navigationController.interactivePopGestureRecognizer]
            if #available(iOS 26.0, *) {
                gestures.append(navigationController.interactiveContentPopGestureRecognizer)
            }
            return gestures.compactMap(\.self)
        }

        private func disablePopGestures() {
            for gesture in popGestures {
                gesture.isEnabled = false
            }
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
            applyDemoEdge()
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
            stage.apply(environment)
            guard #available(iOS 17.0, *) else {
                // iOS 16 overrides only the appearance among traits; the menu offers no other trait.
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

        private func applyBackdrop(_ backdrop: BNGalleryBackdrop) {
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
                backdrop: page.layout == .background ? nil : backdrop,
                onBackdrop: { [weak self] in self?.applyBackdrop($0) },
                onChange: { [weak self] in self?.applyEnvironment($0) },
            )
        }
    }
#endif
