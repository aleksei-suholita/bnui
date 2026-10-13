#if canImport(UIKit)
    import BNUI
    import UIKit

    /// The bar inside `BNTabBarContainerViewController`, presented full screen the way an app hosts
    /// it. The container alone decides where the bar stands — a row along the bottom, or a column
    /// in the strip iPhone Duo keeps for bars beside the content — so this is where that is judged:
    /// on the iPhone Duo simulator, opened, closed and turned, beside the system's own buttons.
    enum BNTabBarContainerGalleryPage {
        static func make() -> some BNGalleryPage {
            BNGalleryDemoPage(
                "TabBar container",
                symbol: "rectangle.portrait.bottomthird.inset.filled",
                summary: "Full screen, with the vertical bar of iPhone Duo",
                presenting: BNTabBarContainerDemo(),
                controller: { $0.makeContainer() },
                knobs: { _ in [
                    .choice("Sections", \.sectionCount, options: ["2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7]),
                    .toggle("Action button", \.hasAction),
                    .choice(
                        "Vertical bar",
                        \.verticalBar,
                        note: "What every tab's screen asks for. Disabled sends the system's bars and this one back "
                            + "to the top and the bottom; on any phone but iPhone Duo nothing changes.",
                    ),
                ] },
            )
        }
    }

    /// What the container is made from; every Present builds it afresh.
    final class BNTabBarContainerDemo {
        nonisolated deinit {}

        enum VerticalBar: CaseIterable, Equatable {
            case automatic
            case disabled
        }

        private struct Section {
            let symbol: String
            let title: String
        }

        private static let catalogue = [
            Section(symbol: "house.fill", title: "Home"),
            Section(symbol: "chart.bar.fill", title: "Stats"),
            Section(symbol: "bell.fill", title: "Alerts"),
            Section(symbol: "bookmark.fill", title: "Saved"),
            Section(symbol: "person.fill", title: "Profile"),
            Section(symbol: "magnifyingglass", title: "Search"),
            Section(symbol: "gearshape.fill", title: "Settings"),
        ]

        var sectionCount = 4
        var hasAction = true
        var verticalBar = VerticalBar.automatic

        func makeContainer() -> UIViewController {
            let tabs = Self.catalogue.prefix(sectionCount).map { section in
                let screen = BNTabBarContainerDemoScreen(title: section.title, disablesVerticalBar: verticalBar == .disabled, closes: true)
                return BNTabBarContainerViewController.Tab(
                    item: BNTabBarItem(id: section.title.lowercased(), icon: .symbol(section.symbol), title: section.title),
                    viewController: UINavigationController(rootViewController: screen),
                )
            }
            let container = BNTabBarContainerViewController(
                tabs: Array(tabs),
                action: hasAction ? BNTabBarAction(icon: .symbol("plus"), accessibilityLabel: "Create") : nil,
            )
            container.modalPresentationStyle = .fullScreen
            return container
        }
    }

    /// A tab's screen as an app has one: a navigation bar with buttons on both sides — the ones
    /// iPhone Duo moves into the strip above the bar — and a list to scroll and to push from.
    private final class BNTabBarContainerDemoScreen: UITableViewController {
        /// Asks iOS 27.1 to keep the bars at the top and the bottom.
        private let disablesVerticalBar: Bool
        /// The root of a tab closes the whole container; a pushed screen goes back instead.
        private let closes: Bool

        init(title: String, disablesVerticalBar: Bool, closes: Bool) {
            self.disablesVerticalBar = disablesVerticalBar
            self.closes = closes
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
            if closes {
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

        #if canImport(UIKit, _version: 9127.1)
            @available(iOS 27.1, *)
            override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
                disablesVerticalBar ? .disabled : .automatic
            }
        #endif

        override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
            40
        }

        override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = "Row \(indexPath.row + 1)"
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        }

        override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
            let detail = BNTabBarContainerDemoScreen(
                title: "Row \(indexPath.row + 1)",
                disablesVerticalBar: disablesVerticalBar,
                closes: false,
            )
            navigationController?.pushViewController(detail, animated: true)
        }
    }
#endif
