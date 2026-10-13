#if canImport(UIKit)
    import BNUI
    import UIKit

    /// Bench host for `BNTabBarView`. Sections are deliberately generic — the control is a library
    /// component and the gallery must not teach it any consumer's vocabulary.
    ///
    /// Staged the way an app shows it: the bar floats at the bottom of the stage, 16 pt from its
    /// edges, over whatever the stage's backdrop is — a list, photos, a bright or a dark image.
    /// That is where the glass and the label contrast get judged. As a column it stands in a strip
    /// along the stage's trailing edge, as wide as the one iPhone Duo keeps for bars.
    final class BNTabBarDemoView: UIView, BNGalleryEventReporting {
        enum Defaults {
            static let axis = 0
            static let labels = 0
            static let alignment = 1
            /// The bar's own default: glass on iOS 26, `.systemMaterial` below it.
            static let material = GalleryBlurThickness.defaultIndex(leading: 0)
            static let sections = 2
            static let presentation = 0
            static let action = 0
            static let accessory = false
            static let liftScale = Double(BNTabBarMetrics.standard.liftedScale)
            static let minimumItemWidth = Double(BNTabBarMetrics.standard.minimumItemWidth)
            static let motion = BNTabBarMotion.standard
            static let haptics = true
            /// Off, Count, 120, Text, Dot.
            static let badge = 0
            static let badgeCount = 12
            static let selectionAnimation = 0
            static let lastIcon = 0
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
            // Past five, to crowd the bar: sections narrow, labels shrink, then go, then More.
            Section(symbol: "magnifyingglass", title: "Search"),
            Section(symbol: "gearshape.fill", title: "Settings"),
        ]

        /// The material knob's choices, the bar's default first. Glass exists on iOS 26 only, so
        /// below it the knob offers only what can be drawn there.
        static var materials: [(name: String, material: any BNTabBarMaterial)] {
            var choices: [(name: String, material: any BNTabBarMaterial)] = []
            if #available(iOS 26.0, *) {
                choices += [
                    ("Glass", BNGlassTabBarMaterial()),
                    ("Glass flat", BNGlassTabBarMaterial(isInteractive: false)),
                ]
            }
            return choices + GalleryBlurThickness.all.map {
                ("Blur \($0.name)", BNBlurTabBarMaterial(style: $0.style))
            } + [("Solid", BNSolidTabBarMaterial())]
        }

        var onGalleryEvent: ((String) -> Void)?

        private var tabBar: BNTabBarView?
        /// The bar along the bottom of the stage, and the bar in a strip down its trailing edge.
        private var rowConstraints: [NSLayoutConstraint] = []
        private var columnConstraints: [NSLayoutConstraint] = []
        /// The strip iPhone Duo keeps for bars, as measured on its simulator; the container takes
        /// the real one from the safe area.
        private static let stripWidth: CGFloat = 84

        private var sectionCount = Defaults.sections
        private var badgeKind = Defaults.badge
        private var badgeCount = Defaults.badgeCount
        /// Counts up once a second while on, so a drag can be tried against a badge that keeps
        /// changing — it must not lose the gesture.
        private var badgeTicker: Task<Void, Never>?
        private var selectionAnimation = BNTabBarDemoView.selectionEffects[Defaults.selectionAnimation].effect.symbolAnimation
        /// What the last section wears: its symbol, an oversized glyph, a photo, or its symbol as an
        /// image.
        var lastIcon = Defaults.lastIcon {
            didSet { tabBar?.items = makeItems() }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            build()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        // MARK: - Knob hooks

        func setSectionCount(_ count: Int) {
            let clamped = min(max(count, 2), Self.catalogue.count)
            guard clamped != sectionCount else { return }
            sectionCount = clamped
            tabBar?.items = makeItems()
        }

        func setBadge(index: Int) {
            badgeKind = index
            tabBar?.items = makeItems()
        }

        func setTickingBadge(_ ticking: Bool) {
            badgeTicker?.cancel()
            badgeTicker = nil
            guard ticking else { return }
            badgeTicker = Task { [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        return
                    }
                    self?.tickBadge()
                }
            }
        }

        /// By id, the way an app counts: where the section stands in the bar does not matter, and
        /// one that is not there is passed over.
        private func tickBadge() {
            badgeCount += 1
            for id in Self.badgedIDs {
                tabBar?.setBadge(makeBadge(), for: id)
            }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                setTickingBadge(false)
            }
        }

        func setSelectionAnimation(index: Int) {
            guard Self.selectionEffects.indices.contains(index) else { return }
            selectionAnimation = Self.selectionEffects[index].effect.symbolAnimation
            tabBar?.items = makeItems()
        }

        func setLabelMode(index: Int) {
            let modes: [BNTabBarConfiguration.LabelMode] = [.always, .selectedOnly, .never]
            guard modes.indices.contains(index) else { return }
            tabBar?.configuration.labelMode = modes[index]
        }

        func setAlignment(index: Int) {
            let alignments: [BNTabBarConfiguration.Alignment] = [.leading, .center, .trailing]
            guard alignments.indices.contains(index) else { return }
            tabBar?.configuration.alignment = alignments[index]
        }

        func setMaterial(index: Int) {
            let materials = Self.materials
            guard materials.indices.contains(index) else { return }
            // Each one carries a probe, so the feed says what the glass hands its content as the
            // backdrop changes — whether it flips light and dark the way system bars do.
            tabBar?.material = GalleryProbedTabBarMaterial(base: materials[index].material) { [weak self] in
                self?.report($0)
            }
        }

        func setPresentation(index: Int) {
            let states: [BNTabBarPresentation] = [.expanded, .hidden]
            guard states.indices.contains(index) else { return }
            tabBar?.setPresentation(states[index], animated: true)
        }

        func setMinimumItemWidth(_ value: Double) {
            tabBar?.theme.geometry.minimumItemWidth = value
        }

        func setLiftScale(_ value: Double) {
            tabBar?.theme.geometry.liftedScale = value
        }

        func setLift(duration: Double) {
            tabBar?.theme.motion.lift.duration = duration
        }

        func setLift(bounce: Double) {
            tabBar?.theme.motion.lift.bounce = bounce
        }

        func setUnlift(duration: Double) {
            tabBar?.theme.motion.unlift.duration = duration
        }

        func setUnlift(bounce: Double) {
            tabBar?.theme.motion.unlift.bounce = bounce
        }

        func setSelection(duration: Double) {
            tabBar?.theme.motion.selection.duration = duration
        }

        func setSelection(bounce: Double) {
            tabBar?.theme.motion.selection.bounce = bounce
        }

        /// Moves the selection the way a host does, through `setSelectedID`. It is the only path
        /// that rides the selection spring — a finger rides lift and unlift — so without it the
        /// selection knobs would have nothing to show.
        func selectNextFromHost() {
            guard let tabBar else { return }
            let ids = makeItems().map(\.id)
            let index = tabBar.selectedID.flatMap { ids.firstIndex(of: $0) } ?? 0
            let next = ids[(index + 1) % ids.count]
            tabBar.setSelectedID(next, animated: true)
            report("host selected \(next)")
        }

        func setHaptics(_ enabled: Bool) {
            tabBar?.haptics.isEnabled = enabled
        }

        func setAccessory(_ enabled: Bool) {
            tabBar?.accessory = enabled ? BNTabBarAccessory(view: makeAccessoryView()) : nil
        }

        func setAction(index: Int) {
            // The last one brings its own pair: a light fill that needs a dark glyph.
            let styles: [BNTabBarAction.Style?] = [
                nil, .standard, .prominent, .prominent(fill: .systemYellow, glyph: .black),
            ]
            guard styles.indices.contains(index) else { return }
            tabBar?.action = styles[index].map {
                BNTabBarAction(icon: .symbol("plus"), accessibilityLabel: "Create", style: $0)
            }
        }

        /// Returns the control to its default state and clears the log. Called by the inspector's
        /// Reset, which then puts every knob back as well.
        func reset() {
            guard let tabBar else { return }
            sectionCount = Defaults.sections
            badgeKind = Defaults.badge
            badgeCount = Defaults.badgeCount
            setTickingBadge(false)
            selectionAnimation = Self.selectionEffects[Defaults.selectionAnimation].effect.symbolAnimation
            lastIcon = Defaults.lastIcon
            tabBar.items = makeItems()
            tabBar.action = nil
            tabBar.accessory = nil
            tabBar.setPresentation(.expanded, animated: false)
            tabBar.theme = .standard
            applyDefaults()
        }

        // MARK: - Build

        private func build() {
            let bar = BNTabBarView(items: makeItems())
            wireEvents(of: bar)
            bar.translatesAutoresizingMaskIntoConstraints = false
            addSubview(bar)
            tabBar = bar

            rowConstraints = [
                // Full width, not hugging: the host gives the control the whole width, the sections
                // capsule aligns itself within it, and a match-bar accessory spans the lot.
                bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: BNGallerySpacing.m),
                bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -BNGallerySpacing.m),
                bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -BNGallerySpacing.m),
            ]
            // The whole strip, as the container gives it: the column hangs from its bottom.
            columnConstraints = [
                bar.trailingAnchor.constraint(equalTo: trailingAnchor),
                bar.widthAnchor.constraint(equalToConstant: Self.stripWidth),
                bar.topAnchor.constraint(equalTo: topAnchor, constant: BNGallerySpacing.m),
                bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -BNGallerySpacing.m),
            ]
            NSLayoutConstraint.activate(rowConstraints)
            applyDefaults()
        }

        // MARK: - Events

        private func wireEvents(of bar: BNTabBarView) {
            bar.onSelect = { [weak self] id in self?.report("selected \(id)") }
            bar.onReselect = { [weak self] id in self?.report("re-selected \(id)") }
            bar.onMultiTap = { [weak self] id, count in
                guard count > 1 else { return } // a single tap is already select / re-select
                self?.report("tap x\(count) on \(id)")
            }
            bar.onLongPress = { [weak self] id, _ in self?.report("long press \(id)") }
            bar.onAction = { [weak self] in self?.report("action tapped") }
            bar.onAccessoryTap = { [weak self] in self?.report("accessory tapped") }
        }

        private func report(_ event: String) {
            onGalleryEvent?(event)
        }

        private func applyDefaults() {
            setAxis(index: Defaults.axis)
            setLabelMode(index: Defaults.labels)
            setAlignment(index: Defaults.alignment)
            setMaterial(index: Defaults.material)
            setHaptics(Defaults.haptics)
        }

        private func makeItems() -> [BNTabBarItem] {
            Self.catalogue.prefix(sectionCount).enumerated().map { index, entry in
                BNTabBarItem(
                    id: entry.title.lowercased(),
                    icon: index == sectionCount - 1 ? Self.lastIcon(lastIcon, symbol: entry.symbol) : .symbol(entry.symbol),
                    title: entry.title,
                    // The last one is the first behind More: its badge goes to the menu, and a dot
                    // to More.
                    badge: Self.badgedIDs.contains(entry.title.lowercased()) ? makeBadge() : nil,
                    selectionAnimation: selectionAnimation,
                )
            }
        }
    }

    extension BNTabBarDemoView {
        func setBadgePosition(index: Int) {
            tabBar?.theme.badge.position = index == 1 ? .bottomTrailing : .topTrailing
        }
    }

    // MARK: - View builders

    private extension BNTabBarDemoView {
        /// The sections that carry the badge knob's badge.
        static var badgedIDs: [String] {
            [catalogue[1], catalogue[catalogue.count - 1]].map { $0.title.lowercased() }
        }

        func makeBadge() -> BNBadge? {
            switch badgeKind {
            case 1: .count(badgeCount, accessibilityLabel: "\(badgeCount) new")
            case 2: .count(120, accessibilityLabel: "120 new")
            case 3: .text("New")
            case 4: .dot(accessibilityLabel: "New")
            default: nil
            }
        }

        private func makeAccessoryView() -> UIView {
            let label = UILabel()
            label.text = "Accessory slot"
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.textColor = BNGalleryColor.label
            label.textAlignment = .center
            let pill = UIView()
            pill.backgroundColor = BNGalleryColor.accent.withAlphaComponent(0.25)
            pill.bnApplyCapsule()
            label.translatesAutoresizingMaskIntoConstraints = false
            pill.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: pill.topAnchor, constant: BNGallerySpacing.m),
                label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -BNGallerySpacing.m),
                label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: BNGallerySpacing.l),
                label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -BNGallerySpacing.l),
            ])
            return pill
        }
    }

    // MARK: - Axis

    extension BNTabBarDemoView {
        /// A row along the bottom of the stage, or a column in a strip down its trailing edge.
        func setAxis(index: Int) {
            let axes: [NSLayoutConstraint.Axis] = [.horizontal, .vertical]
            guard axes.indices.contains(index), let tabBar, tabBar.axis != axes[index] else { return }
            let column = axes[index] == .vertical
            NSLayoutConstraint.deactivate(column ? rowConstraints : columnConstraints)
            NSLayoutConstraint.activate(column ? columnConstraints : rowConstraints)
            tabBar.axis = axes[index]
        }
    }
#endif
