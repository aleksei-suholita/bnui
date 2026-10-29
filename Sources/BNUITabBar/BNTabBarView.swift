#if canImport(UIKit)
    import BNUIButton
    import BNUICore
    import UIKit

    /// Custom tab bar: a content-width capsule of sections over a swappable material.
    ///
    /// The control displays and reports; it never navigates. Selection truth lives with the host —
    /// `selectedID` is what to draw, and `onSelect` / `onReselect` are what happened. It knows
    /// nothing about what a section means.
    ///
    /// Composition is open at three seams — material (the backdrop), lens (how selection is drawn
    /// and moved) and item renderer (what a section looks like). A host that needs none of them
    /// writes `BNTabBarView(items:)`.
    public final class BNTabBarView: UIView {
        // MARK: - Public API

        public var items: [BNTabBarItem] {
            didSet {
                // Changing the sections must not silently move the selection: it stays put when
                // the section still exists, and only falls back to the first one when it is gone.
                if let selectedID, !items.contains(where: { $0.id == selectedID }) {
                    self.selectedID = items.first?.id
                }
                // A change of badges or selected icons alone is drawn in place: a counter that ticks
                // while a finger drives the lens must not take the gesture away.
                guard !updateInPlace(from: oldValue) else { return }
                rebuild()
            }
        }

        public var configuration: BNTabBarConfiguration {
            didSet { rebuild() }
        }

        public var theme: BNTabBarTheme {
            didSet {
                // Rebuilding for a spring duration would throw away the whole tree to change a
                // number nobody has read yet.
                if theme.requiresRebuild(comparedTo: oldValue) {
                    rebuild()
                } else {
                    activeTheme = resolvedTheme
                    setNeedsLayout()
                    applySelection(transition: .immediate)
                }
            }
        }

        public var material: any BNTabBarMaterial {
            didSet { rebuild() }
        }

        public var lensRenderer: any BNTabBarLensRenderer {
            didSet { rebuild() }
        }

        /// Optional action beside the sections. Present, it fixes the composition: sections to
        /// the leading edge, action to the trailing one, flexible gap between.
        public var action: BNTabBarAction? {
            didSet { rebuild() }
        }

        /// Optional host view above the bar — a running session, a mini player. The control owns
        /// its place and appearance and folds its height into `effectiveHeight`; the host owns the
        /// content.
        public var accessory: BNTabBarAccessory? {
            didSet {
                animateAccessoryIn = oldValue == nil && accessory != nil
                rebuild()
            }
        }

        /// nil uses the default renderer, which follows the current theme and label mode.
        public var itemRenderer: (any BNTabBarItemRenderer)? {
            didSet { rebuild() }
        }

        public let haptics: BNTabBarHaptics

        /// Asked before a section the user chose is selected, and before a reselection is reported:
        /// `false` keeps the selection where it is, and the lens goes back to it. Not asked for
        /// ``setSelectedID(_:animated:)`` — the host chose that itself.
        ///
        /// For a section that opens something instead of being a place — a locked one that offers
        /// an invitation — rather than one the host has to take back after the bar has moved.
        public var shouldSelect: ((String) -> Bool)?
        /// A different section was chosen.
        public var onSelect: ((String) -> Void)?
        /// The already-active section was chosen again. What that means is the host's business —
        /// the control only reports it.
        public var onReselect: ((String) -> Void)?
        /// Height the bar occupies, so the host can inset its scroll views and lose nothing under it.
        public var onEffectiveHeightChange: ((CGFloat) -> Void)?
        /// A run of taps on one section: its id and the position in the run (1, 2, 3…).
        ///
        /// Reported rather than interpreted — a double tap, a triple tap or a five-tap easter egg
        /// are all the host's business. Selection still happens on the first tap, so nothing waits
        /// on a timer to find out whether more taps are coming.
        public var onMultiTap: ((String, Int) -> Void)?
        /// The action button was tapped. Never reported as a selection — it is not one.
        public var onAction: (() -> Void)?
        /// The accessory was tapped. Reported without cancelling the accessory's own touches, so a
        /// host view that handles its own gestures still works.
        public var onAccessoryTap: (() -> Void)?
        /// Long press on a section, with the view to anchor a menu to.
        public var onLongPress: ((String, UIView) -> Void)? {
            didSet { refreshLongPressActions() }
        }

        /// Read-only to the outside: selection truth belongs to the host, which sets it through
        /// `setSelectedID`. Writable within the module so the gesture code can commit a choice.
        public internal(set) var selectedID: String?

        public private(set) var presentation: BNTabBarPresentation = .expanded

        /// A row along the bottom of the screen, or a column in the strip the system keeps for bars
        /// beside the content — where its own bars go on iPhone Duo. `BNTabBarController` turns the
        /// bar into a column there by itself. In a column the sections are icons, the
        /// action stands under them, and an accessory is not shown: the strip has no room for one.
        package var axis: NSLayoutConstraint.Axis = .horizontal {
            didSet {
                guard axis != oldValue else { return }
                rebuild()
            }
        }

        /// The keyboard hides the bar independently of whatever the host asked for, so the two
        /// reasons are tracked separately and combined rather than overwriting each other.
        var isHiddenByKeyboard = false

        var isEffectivelyHidden: Bool {
            presentation.isHidden || isHiddenByKeyboard
        }

        /// Measured, not assumed: at accessibility text sizes the bar grows with the label, and
        /// the host's insets have to grow with it. A bar standing in a column beside the content
        /// takes nothing from the bottom edge: zero.
        public var effectiveHeight: CGFloat {
            // Gone means gone: the host must drop its inset, not merely shrink it. A column stands
            // in a strip the content already keeps clear of.
            guard !isEffectivelyHidden, axis == .horizontal else { return 0 }
            // Prefer the laid-out height: measuring with systemLayoutSizeFitting on every
            // layout pass would cost an extra solve per frame.
            let measured = bounds.height > 0
                ? bounds.height
                : systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            return max(measured, activeTheme.geometry.effectiveItemHeight + 2 * activeTheme.geometry.capsulePadding)
        }

        public init(
            items: [BNTabBarItem],
            selectedID: String? = nil,
            configuration: BNTabBarConfiguration = BNTabBarConfiguration(),
            theme: BNTabBarTheme = .standard,
            material: any BNTabBarMaterial = BNTabBarView.standardMaterial,
            lensRenderer: any BNTabBarLensRenderer = BNMaskedLensRenderer(),
            haptics: BNTabBarHaptics = BNTabBarHaptics(),
        ) {
            self.items = items
            self.selectedID = selectedID ?? items.first?.id
            self.configuration = configuration
            self.theme = theme
            self.material = material
            self.lensRenderer = lensRenderer
            self.haptics = haptics
            super.init(frame: .zero)
            // The row guide spans the full width and sits at the bottom; only its top moves when
            // an accessory appears above it. These three never reference a rebuilt view, so they
            // are set once.
            addLayoutGuide(barRowGuide)
            NSLayoutConstraint.activate([
                barRowGuide.bottomAnchor.constraint(equalTo: bottomAnchor),
                barRowGuide.leadingAnchor.constraint(equalTo: leadingAnchor),
                barRowGuide.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            rebuild()
            startObservingEnvironment()
            // Text size arrives as a trait change rather than a notification — registered on
            // iOS 17 and later, through `traitCollectionDidChange` below it.
            if #available(iOS 17.0, *) {
                registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: BNTabBarView, _) in
                    view.rebuild()
                }
            }
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        public func setSelectedID(_ id: String, animated: Bool) {
            guard items.contains(where: { $0.id == id }) else { return }
            selectedID = id
            applySelection(transition: animated ? .spring(activeTheme.motion.selection) : .immediate)
        }

        public func setPresentation(_ presentation: BNTabBarPresentation, animated: Bool) {
            guard presentation != self.presentation else { return }
            self.presentation = presentation
            // Leaving and returning both ride the visibility curve — the bar slides, it never
            // reshapes itself.
            let transition: BNTransition = animated ? .curve(activeTheme.motion.visibility) : .immediate
            applyPresentation(transition: transition)
        }

        // MARK: - Internals

        let baseStack = UIStackView()
        let selectedStack = UIStackView()
        var lens: (any BNTabBarLens)?
        var baseItemViews: [any BNTabBarItemRendering] = []
        var selectedItemViews: [any BNTabBarItemRendering] = []
        /// Where the badges are drawn: inside the material, over the sections.
        let badgeOverlay = UIView()
        /// A badge per slot, in slot order; `nil` where the section's view draws its own.
        var badgeViews: [BNBadgeView?] = []
        var reportedHeight: CGFloat?
        /// Each section's extent along the bar: its width in a row, its height in a column.
        var itemLengthConstraints: [NSLayoutConstraint] = []
        /// How the last solve fits the labels. Items read it on their next state refresh.
        var solvedLabels: BNTabBarLayoutSolver.Labels = .natural
        var actionView: BNButton?
        /// Lies over the More slot: a system menu opens only from a control the finger touched.
        var moreButton: UIButton?

        /// The bar row's vertical region. Without an accessory it fills the view; with one it is
        /// pinned below it. The capsule and action anchor to this rather than to the view, so
        /// adding an accessory does not touch how the row itself is laid out.
        let barRowGuide = UILayoutGuide()
        var barRowTopConstraint: NSLayoutConstraint?
        var animateAccessoryIn = false

        /// The finger driving the lens. One value for the whole gesture, so its pieces cannot
        /// outlive each other: everything goes when it ends.
        struct Drag {
            /// Where the lens started along the bar when the finger landed. The lens moves by the
            /// finger's delta from here, so it never teleports under the touch.
            var start: CGFloat
            /// The section under the finger; a change plays the boundary tick.
            var hoveredIndex: Int
            /// The finger has travelled past `dragThreshold`, and the lens follows it from now on.
            var isFollowing = false
        }

        var drag: Drag?

        var isDragging: Bool {
            drag != nil
        }

        /// When the running selection spring is expected to finish.
        ///
        /// A layout pass in the middle of that spring would snap the lens to its destination while
        /// the animation keeps pulling it — one frame forward, one back. So layout leaves the lens
        /// alone until the spring has settled.
        var selectionSettlesAt: CFTimeInterval = 0
        /// A pass is already asked for the moment the spring lands.
        var awaitsSettledLayout = false

        /// How long a tap still counts as part of the previous run.
        static let multiTapWindow: CFTimeInterval = 0.18
        var tapRunID: String?
        var tapRunCount = 0
        var tapRunTime: CFTimeInterval = 0

        /// Theme after accessibility overrides, resolved once per rebuild so every piece works
        /// from the same values instead of each re-reading the environment.
        var activeTheme: BNTabBarTheme = .standard

        /// Slots the width holds at the minimum section width; unlimited until the bar has a width.
        var slotCount = BNTabBarLayoutSolver.maximumSlots

        /// Sections standing in the capsule, in the host's order. Past the slots it holds, the
        /// tail goes behind More.
        var visibleItems: ArraySlice<BNTabBarItem> {
            items.prefix(BNTabBarLayoutSolver.visibleSectionCount(of: items.count, slots: slotCount))
        }

        /// Sections behind More, opened in its menu.
        var overflowItems: ArraySlice<BNTabBarItem> {
            items.dropFirst(visibleItems.count)
        }

        /// The More slot, when there is one: right after the visible sections.
        var moreSlotIndex: Int? {
            overflowItems.isEmpty ? nil : visibleItems.count
        }

        /// The slot the lens marks. A section chosen from the menu is marked on More itself —
        /// the slot keeps its own glyph, and the menu ticks which section is active.
        var selectedIndex: Int {
            if let index = visibleItems.firstIndex(where: { $0.id == selectedID }) {
                return index
            }
            if overflowItems.contains(where: { $0.id == selectedID }), let moreSlotIndex {
                return moreSlotIndex
            }
            return 0
        }

        // No intrinsic height on purpose: the capsule is sized by its content, so the bar grows
        // with Dynamic Type instead of clipping the label against a fixed number.

        override public func traitCollectionDidChange(_ previous: UITraitCollection?) {
            super.traitCollectionDidChange(previous)
            guard #unavailable(iOS 17.0) else { return }
            legacyTraitsDidChange(from: previous)
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            // Which sections stand comes first, then their widths, then the lens on them — all in
            // this pass: a pass asked for from inside this one does not always come, and a
            // rotation brings only one. New lengths reach the lens and the capsule through the
            // second `super` call, and the sections through the stacks `applySelection` lays out.
            let slotsChanged = applySlotCount()
            if applySolvedWidths() || slotsChanged {
                super.layoutSubviews()
            }
            placeLensAfterLayout()
            reportHeightIfNeeded()
        }

        func rebuild() {
            activeTheme = resolvedTheme
            baseStack.removeFromSuperview()
            selectedStack.removeFromSuperview()
            subviews.forEach { $0.removeFromSuperview() }
            baseItemViews.removeAll()
            selectedItemViews.removeAll()
            badgeViews.removeAll()
            // Off the bar now, and nothing is built into it again: a layout pass forced before the
            // new one exists — the accessory's, on its way in — would otherwise rebuild the slots
            // into it, and pin a More button in the bar to a lens outside it, which UIKit traps.
            lens = nil
            // A drag in progress goes with the surface its recogniser sat on, and the selection
            // applied at the end of the rebuild puts the lens back.
            drag = nil

            // Placed first: the accessory decides where the row guide's top sits, and everything
            // below anchors to that guide.
            buildAccessory()

            // Accessibility overrides are applied here, once, so every piece below sees the same
            // resolved values instead of each consulting the environment on its own.
            let surface = resolvedMaterial.makeSurface()
            let lens = resolvedLensRenderer.makeLens()
            self.lens = lens

            // Inside, not beside: the lens carries the items and the marker, and lies in the
            // capsule's content view, so whatever the glass does under a finger — lifting, stretching
            // after a finger that has left it — the sections and the marker do with it, as one
            // surface. The marker is flat paint, so the bar stays one glass layer.
            surface.view.translatesAutoresizingMaskIntoConstraints = false
            lens.translatesAutoresizingMaskIntoConstraints = false
            addSubview(surface.view)
            surface.contentContainer.addSubview(lens)
            followAppearance(of: surface)
            buildBadgeOverlay(in: surface)

            // Built before the constraints below: an action changes the composition, so it has to
            // exist by the time alignment is decided.
            buildAction()

            // The lens carries the items, so it is what the bar measures; the capsule takes its size.
            NSLayoutConstraint.activate(alignmentConstraints(for: surface.view) + [
                lens.topAnchor.constraint(equalTo: surface.contentContainer.topAnchor),
                lens.bottomAnchor.constraint(equalTo: surface.contentContainer.bottomAnchor),
                lens.leadingAnchor.constraint(equalTo: surface.contentContainer.leadingAnchor),
                lens.trailingAnchor.constraint(equalTo: surface.contentContainer.trailingAnchor),
            ])

            // Counted against the action just built, so the slots are not built twice.
            resolveSlotCount()
            buildItems(in: lens)
            // Touches still land on the material's content container — the topology the glass
            // spike verified. The lens takes no touches, so they pass straight through to it.
            attachGesture(to: surface.contentContainer)
            buildMoreButton()
            applySelection(transition: .immediate)
            refreshLongPressActions()
            setNeedsLayout()
        }
    }
#endif
