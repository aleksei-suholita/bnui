#if canImport(UIKit)
    import BNUI
    import UIKit

    // MARK: - Present: the bar inside the controller

    extension BNTabBarDemoView {
        /// Opens the stage's bar inside `BNTabBarController`, full screen, as the knobs set it: the
        /// sections, the action, the material, the theme and the configuration, the lock on the last
        /// section. The axis is the controller's to decide, and it hosts no accessory.
        func presentController() {
            guard let tabBar, let presenter = nearestController, presenter.presentedViewController == nil else { return }
            let items = catalogueItems()
            let host = GalleryTabBarHost(catalogue: items.shown + items.spare, verticalBar: verticalBar)
            let haptics = BNTabBarHaptics()
            haptics.isEnabled = tabBar.haptics.isEnabled
            let controller = BNTabBarController(
                tabs: items.shown.map(host.makeTab),
                action: tabBar.action,
                configuration: tabBar.configuration,
                theme: tabBar.theme,
                material: Self.materials[materialIndex].material,
                haptics: haptics,
            )
            if locksLastSection {
                controller.shouldSelect = { [weak controller] id in
                    guard let controller, id == controller.tabs.last?.item.id else { return true }
                    let alert = UIAlertController(title: "Locked", message: "This tab opens with an invitation.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    controller.present(alert, animated: true)
                    return false
                }
            }
            controller.modalPresentationStyle = .fullScreen
            GalleryEnvironment.applyCurrent(to: controller)
            presenter.present(controller, animated: true)
            report("presented the controller")
        }

        /// The controller showing the stage, found up the responder chain.
        private var nearestController: UIViewController? {
            var responder = next
            while let current = responder {
                if let controller = current as? UIViewController {
                    return controller
                }
                responder = current.next
            }
            return nil
        }
    }

    /// What a presented controller's screens come back to: the sections a tab can be added from,
    /// and what the screens ask of iPhone Duo's strip.
    final class GalleryTabBarHost {
        nonisolated deinit {}

        enum VerticalBar: CaseIterable, Equatable {
            case automatic
            case disabled
        }

        let verticalBar: VerticalBar
        /// Every section, in order; the controller starts with the first of them.
        private let catalogue: [BNTabBarItem]

        init(catalogue: [BNTabBarItem], verticalBar: VerticalBar) {
            self.catalogue = catalogue
            self.verticalBar = verticalBar
        }

        func makeTab(_ item: BNTabBarItem) -> BNTabBarController.Tab {
            let screen = GalleryTabBarHostScreen(title: item.title, host: self, kind: .root)
            return BNTabBarController.Tab(item: item, viewController: UINavigationController(rootViewController: screen))
        }

        /// The first section of the catalogue the controller does not show.
        fileprivate func addTab(to controller: BNTabBarController) {
            let shown = Set(controller.tabs.map(\.item.id))
            guard let item = catalogue.first(where: { !shown.contains($0.id) }) else { return }
            controller.tabs.append(makeTab(item))
        }

        fileprivate func removeLastTab(from controller: BNTabBarController) {
            guard controller.tabs.count > 1 else { return }
            controller.tabs.removeLast()
        }
    }

    /// A tab's screen as an app has one: a navigation bar with buttons on both sides — the ones
    /// iPhone Duo moves into the strip above the bar — and rows for what only the controller does:
    /// hiding the bar, changing the tabs, a stack to go back from. The screen without the bar
    /// offers no rows for the bar or the tabs: it hides the bar every time it appears, so a bar
    /// shown by hand there would be gone again after a trip to another tab.
    private final class GalleryTabBarHostScreen: UITableViewController {
        enum Kind {
            /// A tab's root: it closes the whole controller.
            case root
            case pushed
            /// Hides the bar as it appears and shows it as it goes, as an app's screen does.
            case withoutBar
        }

        private struct Row {
            let title: String
            let perform: (GalleryTabBarHostScreen) -> Void
        }

        private let host: GalleryTabBarHost
        private let kind: Kind

        init(title: String, host: GalleryTabBarHost, kind: Kind) {
            self.host = host
            self.kind = kind
            super.init(style: .insetGrouped)
            self.title = title
        }

        nonisolated deinit {}

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
            if kind == .root {
                navigationItem.leftBarButtonItem = UIBarButtonItem(
                    systemItem: .close,
                    primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) },
                )
            }
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "square.and.pencil"),
                primaryAction: UIAction { _ in },
            )
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if kind == .withoutBar {
                bnTabBarController?.setTabBarHidden(true, animated: animated)
            }
        }

        /// Shown again in the middle of a swipe back, the bar waits for the swipe to complete.
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if kind == .withoutBar {
                bnTabBarController?.setTabBarHidden(false, animated: animated)
            }
        }

        #if canImport(UIKit, _version: 9127.1)
            @available(iOS 27.1, *)
            override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
                host.verticalBar == .disabled ? .disabled : .automatic
            }
        #endif

        private var sections: [(title: String, rows: [Row])] {
            let pushRows = (1 ... 20).map { number in
                Row(title: "Row \(number)") { $0.push(.pushed, title: "Row \(number)") }
            }
            guard kind != .withoutBar else {
                return [("Without the bar while on screen. Push: the next screen has it", pushRows)]
            }
            let isBarHidden = bnTabBarController?.isTabBarHidden ?? false
            return [
                ("Bar", [
                    Row(title: "Push a screen that hides the bar") { $0.push(.withoutBar, title: "Without the bar") },
                    Row(title: isBarHidden ? "Show the bar" : "Hide the bar") { screen in
                        screen.bnTabBarController?.setTabBarHidden(!isBarHidden, animated: true)
                    },
                ]),
                ("Tabs", [
                    Row(title: "Add a tab") { $0.onController($0.host.addTab) },
                    Row(title: "Remove the last tab") { $0.onController($0.host.removeLastTab) },
                ]),
                ("Push, then tap this tab again to go back to the root", pushRows),
            ]
        }

        private func push(_ kind: Kind, title: String) {
            let screen = GalleryTabBarHostScreen(title: title, host: host, kind: kind)
            navigationController?.pushViewController(screen, animated: true)
        }

        private func onController(_ change: (BNTabBarController) -> Void) {
            guard let controller = bnTabBarController else { return }
            change(controller)
        }

        override func numberOfSections(in _: UITableView) -> Int {
            sections.count
        }

        override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
            sections[section].title
        }

        override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
            sections[section].rows.count
        }

        override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = sections[indexPath.section].rows[indexPath.row].title
            cell.contentConfiguration = content
            return cell
        }

        override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            sections[indexPath.section].rows[indexPath.row].perform(self)
            // Hide the bar becomes Show the bar.
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
        }
    }
#endif
