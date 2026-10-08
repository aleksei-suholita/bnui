#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// The catalogue of gallery pages. Entry points: the app's Debug menu or the
    /// `-OpenGallery <Title>` launch argument.
    ///
    /// Grouped by each page's `section`, searchable, with a Settings-style icon per row — the list
    /// grows with every control and every host app's own pages, and a bare column of titles stops
    /// being scannable long before it stops fitting the screen.
    public final class GalleryViewController: UIViewController, UICollectionViewDelegate, UISearchResultsUpdating {
        /// Set it when the gallery is presented modally — the catalogue then shows a Close button.
        /// Left nil when the gallery is pushed onto an existing stack (Back is enough).
        public var onClose: (() -> Void)? {
            didSet { updateCloseButton() }
        }

        private let pages: [any GalleryPage]
        private let collectionView: UICollectionView
        private let searchController = UISearchController(searchResultsController: nil)
        private var dataSource: UICollectionViewDiffableDataSource<String, Int>?
        private var query = ""

        public init(pages: [any GalleryPage]) {
            self.pages = pages
            var list = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            list.headerMode = .supplementary
            collectionView = UICollectionView(
                frame: .zero,
                collectionViewLayout: UICollectionViewCompositionalLayout.list(using: list),
            )
            super.init(nibName: nil, bundle: nil)
            title = "Design Gallery"
            navigationItem.largeTitleDisplayMode = .always
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override public func viewDidLoad() {
            super.viewDidLoad()
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            collectionView.delegate = self
            view.addSubview(collectionView)
            NSLayoutConstraint.activate([
                collectionView.topAnchor.constraint(equalTo: view.topAnchor),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])

            searchController.searchResultsUpdater = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchBar.placeholder = "Search pages"
            navigationItem.searchController = searchController

            configureDataSource()
            applySnapshot(animated: false)
            updateCloseButton()
        }

        override public func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            collectionView.indexPathsForSelectedItems?.forEach {
                collectionView.deselectItem(at: $0, animated: animated)
            }
        }

        public func openPage(titled title: String) {
            guard let page = pages.first(where: { $0.title == title }) else { return }
            navigationController?.pushViewController(GalleryPageViewController(page: page), animated: false)
        }

        // MARK: - Data

        private func configureDataSource() {
            let pages = pages
            let cell = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { cell, _, index in
                let page = pages[index]
                var content = UIListContentConfiguration.subtitleCell()
                content.text = page.title
                content.secondaryText = page.summary
                content.secondaryTextProperties.color = BNGalleryColor.secondaryLabel
                content.textToSecondaryTextVerticalPadding = 2
                content.image = GalleryIcon.image(symbol: page.symbol, seed: page.title)
                content.imageToTextPadding = BNGallerySpacing.m - 4
                content.directionalLayoutMargins.top = 10
                content.directionalLayoutMargins.bottom = 10
                cell.contentConfiguration = content
                cell.accessories = [.disclosureIndicator()]
            }
            let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
                elementKind: UICollectionView.elementKindSectionHeader,
            ) { [weak self] header, _, indexPath in
                guard let sections = self?.dataSource?.snapshot().sectionIdentifiers,
                      sections.indices.contains(indexPath.section)
                else { return }
                var content = header.defaultContentConfiguration()
                content.text = sections[indexPath.section]
                header.contentConfiguration = content
            }
            let dataSource = UICollectionViewDiffableDataSource<String, Int>(collectionView: collectionView) { view, indexPath, index in
                view.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: index)
            }
            dataSource.supplementaryViewProvider = { view, _, indexPath in
                view.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
            }
            self.dataSource = dataSource
        }

        private func applySnapshot(animated: Bool) {
            let found = pages.indices.filter { matches(pages[$0]) }
            // Sections in the order of their first page, so the order pages are handed in still
            // decides the layout.
            var sections: [String] = []
            for index in found where !sections.contains(pages[index].section) {
                sections.append(pages[index].section)
            }
            var snapshot = NSDiffableDataSourceSnapshot<String, Int>()
            snapshot.appendSections(sections)
            for section in sections {
                snapshot.appendItems(found.filter { pages[$0].section == section }, toSection: section)
            }
            dataSource?.apply(snapshot, animatingDifferences: animated)
            // The empty-search state arrives with iOS 17; before it an empty list says the same.
            if #available(iOS 17.0, *) {
                contentUnavailableConfiguration = found.isEmpty && !query.isEmpty ? UIContentUnavailableConfiguration.search() : nil
            }
        }

        private func matches(_ page: any GalleryPage) -> Bool {
            guard !query.isEmpty else { return true }
            return [page.title, page.summary ?? "", page.section].contains {
                $0.localizedStandardContains(query)
            }
        }

        // MARK: - Delegates

        public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let index = dataSource?.itemIdentifier(for: indexPath) else { return }
            navigationController?.pushViewController(GalleryPageViewController(page: pages[index]), animated: true)
        }

        public func updateSearchResults(for searchController: UISearchController) {
            query = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
            applySnapshot(animated: true)
        }

        private func updateCloseButton() {
            guard isViewLoaded else { return }
            navigationItem.rightBarButtonItem = onClose == nil ? nil : UIBarButtonItem(
                systemItem: .close,
                primaryAction: UIAction { [weak self] _ in self?.onClose?() },
            )
        }
    }

    /// A Settings-style icon: a rounded square in one of a few system colours with a white glyph.
    ///
    /// The colour comes from the page's title, not from a registry, so a host app's page gets a
    /// stable colour without declaring one — and the same page is the same colour on every launch.
    enum GalleryIcon {
        private static let palette: [UIColor] = [
            .systemBlue, .systemIndigo, .systemOrange, .systemPink,
            .systemTeal, .systemGreen, .systemPurple, .systemRed,
        ]

        static func image(symbol: String, seed: String) -> UIImage {
            // A stable sum rather than `hashValue`, which Swift reseeds on every launch.
            let seedValue = seed.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
            let color = palette[seedValue % palette.count]
            let side = BNGalleryMetrics.iconSize
            let size = CGSize(width: side, height: side)
            return UIGraphicsImageRenderer(size: size).image { _ in
                color.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: BNGalleryMetrics.iconRadius).fill()
                let configuration = UIImage.SymbolConfiguration(pointSize: side * 0.5, weight: .semibold)
                guard let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
                else { return }
                let origin = CGPoint(x: (side - glyph.size.width) / 2, y: (side - glyph.size.height) / 2)
                glyph.draw(in: CGRect(origin: origin, size: glyph.size))
            }
        }
    }
#endif
