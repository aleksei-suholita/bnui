#if (DEBUG || GalleryInRelease) && canImport(UIKit)
    import BNUI
    import UIKit

    /// One knob drawn as a row of an inset-grouped card.
    ///
    /// The row holds the knob's current value itself, which is what lets the inspector say what
    /// changed and put it back — the widget and the demo together, never one without the other.
    class GalleryKnobRow: UIView {
        let knob: BNGalleryKnob
        /// Tells the inspector the row moved to or from its initial value.
        var onModifiedChange: (() -> Void)?

        var isModified: Bool {
            false
        }

        let titleLabel = UILabel()
        private let titleSlot = UIView()
        private let topLine = UIStackView()
        private let body = UIStackView()
        private let modifiedMark = UIView()

        private static let markSize: CGFloat = 6
        /// One dot's width of air after the text: close enough to read as the title's, clear of the glyph.
        private static let markGap: CGFloat = 6

        init(knob: BNGalleryKnob) {
            self.knob = knob
            super.init(frame: .zero)

            layOutTitle(knob.label)

            topLine.axis = .horizontal
            topLine.alignment = .center
            topLine.spacing = BNGallerySpacing.s
            topLine.addArrangedSubview(titleSlot)

            body.axis = .vertical
            body.spacing = BNGallerySpacing.s
            body.addArrangedSubview(topLine)
            if let note = knob.note {
                body.addArrangedSubview(Self.makeNoteLabel(note))
            }

            directionalLayoutMargins = NSDirectionalEdgeInsets(
                top: 12,
                leading: BNGallerySpacing.m,
                bottom: 12,
                trailing: BNGallerySpacing.m,
            )
            body.translatesAutoresizingMaskIntoConstraints = false
            addSubview(body)
            NSLayoutConstraint.activate([
                body.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
                body.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
                body.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                body.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
                heightAnchor.constraint(greaterThanOrEqualToConstant: BNGalleryMetrics.rowMinHeight),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        /// Back to the initial value — the control and the demo both. Fires the knob even when
        /// nothing changed, so a demo that drifted on its own comes back in step with the panel.
        func reset() {}

        /// A control on the title's line, after it.
        func setTrailing(_ view: UIView) {
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
            topLine.addArrangedSubview(view)
        }

        /// A control on its own line under the title — a slider, segments.
        func setBelow(_ view: UIView) {
            body.insertArrangedSubview(view, at: 1)
        }

        /// Every subclass ends a change here: the mark and the inspector's count follow the value.
        func noteChange() {
            modifiedMark.isHidden = !isModified
            onModifiedChange?()
        }

        /// The title and its changed mark, which follows the title's last glyph. The slot keeps the
        /// mark's room free whether it shows or not, so marking a row changed never re-wraps the
        /// title or moves the control.
        private func layOutTitle(_ text: String) {
            titleLabel.text = text
            titleLabel.font = BNGalleryFont.body
            titleLabel.textColor = BNGalleryColor.label
            titleLabel.numberOfLines = 0
            titleLabel.adjustsFontForContentSizeCategory = true
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            modifiedMark.backgroundColor = BNGalleryColor.accent
            modifiedMark.bnApplyCapsule()
            modifiedMark.isHidden = true
            modifiedMark.isUserInteractionEnabled = false

            for view in [titleLabel, modifiedMark] {
                view.translatesAutoresizingMaskIntoConstraints = false
                titleSlot.addSubview(view)
            }
            titleSlot.setContentHuggingPriority(.defaultLow, for: .horizontal)
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: titleSlot.topAnchor),
                titleLabel.bottomAnchor.constraint(equalTo: titleSlot.bottomAnchor),
                titleLabel.leadingAnchor.constraint(equalTo: titleSlot.leadingAnchor),
                titleLabel.trailingAnchor.constraint(
                    lessThanOrEqualTo: titleSlot.trailingAnchor,
                    constant: -(Self.markGap + Self.markSize),
                ),
                modifiedMark.widthAnchor.constraint(equalToConstant: Self.markSize),
                modifiedMark.heightAnchor.constraint(equalToConstant: Self.markSize),
                modifiedMark.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: Self.markGap),
                modifiedMark.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            ])
        }

        private static func makeNoteLabel(_ text: String) -> UILabel {
            let label = UILabel()
            label.text = text
            label.font = BNGalleryFont.footnote
            label.textColor = BNGalleryColor.secondaryLabel
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            return label
        }
    }

    extension GalleryKnobRow {
        /// The row for a knob, or nil for a header — headers become section titles, not rows.
        static func make(for knob: BNGalleryKnob) -> GalleryKnobRow? {
            switch knob.control {
            case let .toggle(initial, onChange):
                GalleryToggleRow(knob: knob, initial: initial, onChange: onChange)
            case let .slider(min, max, initial, onChange):
                GallerySliderRow(knob: knob, range: Swift.min(min, max) ... Swift.max(min, max), initial: initial, onChange: onChange)
            case let .segmented(options, initial, onChange):
                GalleryChoiceRow(knob: knob, options: options, initial: initial, onChange: onChange)
            case let .textField(initial, onChange):
                GalleryTextRow(knob: knob, initial: initial, onChange: onChange)
            case let .button(onTap):
                GalleryActionRow(knob: knob, onTap: onTap)
            case .header:
                nil
            }
        }
    }

    extension UIView {
        /// The controller that owns this view, found up the responder chain — for a row that has
        /// to present something of its own.
        var galleryHostViewController: UIViewController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController {
                    return controller
                }
                responder = current.next
            }
            return nil
        }
    }

    // MARK: - Toggle

    final class GalleryToggleRow: GalleryKnobRow {
        private let toggle = UISwitch()
        private let initial: Bool
        private let onChange: (Bool) -> Void

        override var isModified: Bool {
            toggle.isOn != initial
        }

        init(knob: BNGalleryKnob, initial: Bool, onChange: @escaping (Bool) -> Void) {
            self.initial = initial
            self.onChange = onChange
            super.init(knob: knob)
            toggle.isOn = initial
            toggle.addAction(UIAction { [weak self] _ in self?.changed() }, for: .valueChanged)
            setTrailing(toggle)
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func reset() {
            toggle.setOn(initial, animated: true)
            changed()
        }

        private func changed() {
            onChange(toggle.isOn)
            noteChange()
        }
    }

    // MARK: - Text

    final class GalleryTextRow: GalleryKnobRow, UITextFieldDelegate {
        private let field = UITextField()
        private let initial: String
        private let onChange: (String) -> Void

        override var isModified: Bool {
            (field.text ?? "") != initial
        }

        init(knob: BNGalleryKnob, initial: String, onChange: @escaping (String) -> Void) {
            self.initial = initial
            self.onChange = onChange
            super.init(knob: knob)
            field.text = initial
            field.placeholder = initial.isEmpty ? "Text" : initial
            field.font = BNGalleryFont.body
            field.adjustsFontForContentSizeCategory = true
            field.textColor = BNGalleryColor.secondaryLabel
            field.textAlignment = .right
            field.returnKeyType = .done
            field.clearButtonMode = .whileEditing
            field.delegate = self
            field.addAction(UIAction { [weak self] _ in self?.changed() }, for: .editingChanged)
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
            setTrailing(field)
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func reset() {
            field.text = initial
            changed()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        private func changed() {
            onChange(field.text ?? "")
            noteChange()
        }
    }

    // MARK: - Action

    /// A command rather than a value: the whole row is the button, drawn in the accent colour the
    /// way Settings draws its actions. Nothing to reset, so it never counts as changed.
    final class GalleryActionRow: GalleryKnobRow {
        private let onTap: () -> Void

        init(knob: BNGalleryKnob, onTap: @escaping () -> Void) {
            self.onTap = onTap
            super.init(knob: knob)
            titleLabel.textColor = BNGalleryColor.accent

            var configuration = UIButton.Configuration.plain()
            configuration.background.cornerRadius = 0
            let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
                self?.onTap()
            })
            button.configurationUpdateHandler = { button in
                button.configuration?.background.backgroundColor = button.isHighlighted ? BNGalleryColor.highlight : .clear
            }
            button.accessibilityLabel = knob.label
            button.translatesAutoresizingMaskIntoConstraints = false
            // Under the label, over the whole row: the row reads as text and taps as a button.
            insertSubview(button, at: 0)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: topAnchor),
                button.bottomAnchor.constraint(equalTo: bottomAnchor),
                button.leadingAnchor.constraint(equalTo: leadingAnchor),
                button.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            titleLabel.isAccessibilityElement = false
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            // The label and its stack sit above the button; every touch in the row goes to it.
            guard self.point(inside: point, with: event) else { return nil }
            return subviews.first { $0 is UIButton } ?? super.hitTest(point, with: event)
        }
    }
#endif
