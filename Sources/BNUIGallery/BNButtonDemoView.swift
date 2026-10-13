#if canImport(UIKit)
    import BNUI
    import UIKit

    /// The bench for ``BNButton``.
    ///
    /// The button in the middle of the whole stage, over whatever backdrop the stage shows, with a
    /// system glass button under it — the motion bar is "indistinguishable from the system", and
    /// that is only judgeable side by side. What the control reports goes to the stage's event
    /// feed, so a tap that did not fire is visible rather than merely suspected. Full-bleed on
    /// purpose: a Fill button is judged against a screen's width, not a card's.
    final class BNButtonDemoView: UIView, BNGalleryEventReporting {
        enum Defaults {
            static let title = "Continue"
            static let sizeIndex = 1
            static let widthIndex = 0
            static let styleIndex = 0
            static let materialIndex = 0
            static let cornerIndex = 0
            static let forcedAccessibility = false
            static let statusIndex = 0
            static let cooldown = 0.0
            static let rejectionEnabled = true
            static let rejectionTravel = 7.0
            static let rejectionHaptic = true
            static let rejectionHold = 0.35
            static let rejectionFlashAlpha = 0.45
            static let contentIndex = 0
            static let iconIndex = 0
            static let badgeIndex = 0
            static let menuIndex = 0
            static let usesLongTitle = false
            static let titleBehaviorIndex = 0
            static let pressedScale = 0.96
            static let pressDuration = 0.16
            static let fastBounce = 0.45
            static let slowBounce = 0.10
            static let snapWindow = 0.25
            static let maxVelocity = 6.0
            static let hapticsEnabled = true
            static let hapticMergeWindow = 0.15
            static let showsHitTarget = false
            static let showsSystemButton = true
        }

        static let sizes: [BNButtonSize] = [.small, .medium, .large]
        static let styles: [BNButtonStyle] = [.primary, .secondary, .ghost, .destructive]
        /// The material knob's choices, every one explicit: what the knob names is what is drawn,
        /// whatever the style would have picked. Blur in its regular thickness only — the
        /// thickness scale is the tab bar's and the toast's to show. Glass exists on iOS 26 only,
        /// so below it the knob offers only what can be drawn there.
        static var materials: [(name: String, material: any BNButtonMaterial)] {
            var choices: [(name: String, material: any BNButtonMaterial)] = []
            if #available(iOS 26.0, *) {
                choices += [
                    ("Glass", BNGlassButtonMaterial(tinted: true)),
                    ("Glass static", BNGlassButtonMaterial(isInteractive: false, tinted: true)),
                ]
            }
            return choices + [
                ("Blur", BNBlurButtonMaterial(tinted: true)),
                ("Solid", BNSolidButtonMaterial()),
            ]
        }

        /// Chosen by shape, for the icon-only circle: `square.and.arrow.up` is the tall one,
        /// `person.2` is shrunk at `small` and reaches the inset at `medium`, and `person.3` is
        /// shrunk at every size.
        static let iconNames = [
            "gearshape", "plus", "chevron.forward", "square.and.arrow.up", "person.2", "person.3",
        ]
        /// A picture in colours of its own, the way a sign-in button carries a brand's mark: drawn
        /// as given, dimmed when the button is disabled.
        ///
        /// Drawn at 80 pt, as an asset brought at the wrong size would be: the button shrinks it to
        /// what the size holds, alone or beside a title, rather than growing.
        static let picture = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
            let colours: [UIColor] = [.systemRed, .systemYellow, .systemGreen, .systemBlue]
            let centre = CGPoint(x: 40, y: 40)
            for (index, colour) in colours.enumerated() {
                let start = CGFloat(index) * .pi / 2
                let quarter = UIBezierPath()
                quarter.move(to: centre)
                quarter.addArc(withCenter: centre, radius: 40, startAngle: start, endAngle: start + .pi / 2, clockwise: true)
                quarter.close()
                colour.setFill()
                quarter.fill()
            }
            context.cgContext.setBlendMode(.clear)
            UIBezierPath(ovalIn: CGRect(x: 24, y: 24, width: 32, height: 32)).fill()
        }

        /// The menu knob's commands; choosing one reaches the feed.
        func makeMenu() -> UIMenu {
            UIMenu(children: [
                menuCommand("Rename", symbol: "pencil"),
                menuCommand("Share", symbol: "square.and.arrow.up"),
                menuCommand("Delete", symbol: "trash", attributes: .destructive),
            ])
        }

        private func menuCommand(_ title: String, symbol: String, attributes: UIMenuElement.Attributes = []) -> UIAction {
            UIAction(title: title, image: UIImage(systemName: symbol), attributes: attributes) { [weak self] _ in
                self?.log("menu: \(title)")
            }
        }

        /// Long enough to need several lines at every width, Fill on a phone included — so
        /// Truncate, Wrap 2 and Wrap ∞ each draw something different.
        static let longTitle = "Continue with a label long enough to run onto several lines at any width, "
            + "so truncating, two lines and unlimited wrapping all look different"

        /// The system's glass button to stand beside the kit's; before iOS 26, the nearest system look.
        static var systemConfiguration: UIButton.Configuration {
            if #available(iOS 26.0, *) {
                return .glass()
            }
            return .gray()
        }

        var onGalleryEvent: ((String) -> Void)?
        let button = BNButton(content: .title(Defaults.title))
        let systemButton = UIButton(configuration: BNButtonDemoView.systemConfiguration)
        var widthConstraints: [NSLayoutConstraint] = []

        // Knob state the content is rebuilt from.
        var titleText = Defaults.title
        var iconIndex = Defaults.iconIndex
        var contentKind = 0
        var usesLongTitle = false
        /// The corner knob, kept apart from the size: every size step carries a capsule of its
        /// own, so switching steps would otherwise undo the knob.
        var cornerShape = BNShape.capsule

        override init(frame: CGRect) {
            super.init(frame: frame)
            build()
            wireEvents()
            reset()
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        // MARK: - Building

        private func build() {
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)

            var configuration = systemButton.configuration ?? Self.systemConfiguration
            configuration.title = "System"
            systemButton.configuration = configuration
            systemButton.translatesAutoresizingMaskIntoConstraints = false
            addSubview(systemButton)

            NSLayoutConstraint.activate([
                // A little above centre, so the pair — ours over the system's — is what is centred.
                button.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -BNGallerySpacing.l),
                systemButton.topAnchor.constraint(equalTo: button.bottomAnchor, constant: BNGallerySpacing.l),
                systemButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            ])
        }

        /// The feed shows what a `UIControl` target hears, so the touch events are checked on the
        /// bench. The drags inside and outside are left out: they come on every move and would
        /// push everything else off the feed.
        private func wireEvents() {
            let reported: [(event: UIControl.Event, name: String)] = [
                (.touchDown, "touchDown"),
                (.touchDownRepeat, "touchDownRepeat"),
                (.touchDragEnter, "touchDragEnter"),
                (.touchDragExit, "touchDragExit"),
                (.touchUpInside, "touchUpInside"),
                (.touchUpOutside, "touchUpOutside"),
                (.touchCancel, "touchCancel"),
                (.primaryActionTriggered, "primaryActionTriggered"),
                (.menuActionTriggered, "menuActionTriggered"),
            ]
            for entry in reported {
                button.addAction(UIAction { [weak self] _ in self?.log(entry.name) }, for: entry.event)
            }
            button.onRejected = { [weak self] in self?.log("rejected") }
        }

        func log(_ line: String) {
            onGalleryEvent?(line)
        }
    }
#endif
