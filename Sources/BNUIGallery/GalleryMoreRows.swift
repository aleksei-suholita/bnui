#if canImport(UIKit)
    import BNUI
    import UIKit

    // MARK: - Colour

    /// A colour: the system's swatch beside the title, which opens its colour picker.
    final class GalleryColorRow: GalleryKnobRow {
        private let well = UIColorWell()
        private let initial: UIColor
        private let onChange: (UIColor) -> Void

        override var isModified: Bool {
            well.selectedColor != initial
        }

        init(knob: BNGalleryKnob, initial: UIColor, onChange: @escaping (UIColor) -> Void) {
            self.initial = initial
            self.onChange = onChange
            super.init(knob: knob)
            well.supportsAlpha = true
            well.title = knob.label
            well.selectedColor = initial
            well.addAction(UIAction { [weak self] _ in self?.changed() }, for: .valueChanged)
            setTrailing(well)
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func reset() {
            well.selectedColor = initial
            changed()
        }

        private func changed() {
            onChange(well.selectedColor ?? initial)
            noteChange()
        }
    }

    // MARK: - Stepper

    /// A whole number one step at a time: the value written out, the stepper beside it.
    final class GalleryStepperRow: GalleryKnobRow {
        private let stepper = UIStepper()
        private let valueLabel = UILabel()
        private let initial: Int
        private let onChange: (Int) -> Void

        override var isModified: Bool {
            Int(stepper.value) != initial
        }

        init(knob: BNGalleryKnob, range: ClosedRange<Int>, initial: Int, onChange: @escaping (Int) -> Void) {
            self.initial = initial
            self.onChange = onChange
            super.init(knob: knob)
            stepper.minimumValue = Double(range.lowerBound)
            stepper.maximumValue = Double(range.upperBound)
            stepper.value = Double(initial)
            stepper.addAction(UIAction { [weak self] _ in self?.changed() }, for: .valueChanged)
            valueLabel.font = BNGalleryFont.value
            valueLabel.adjustsFontForContentSizeCategory = true
            let trailing = UIStackView(arrangedSubviews: [valueLabel, stepper])
            trailing.spacing = BNGallerySpacing.s
            trailing.alignment = .center
            setTrailing(trailing)
            refreshValue()
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func reset() {
            stepper.value = Double(initial)
            changed()
        }

        private func changed() {
            onChange(Int(stepper.value))
            refreshValue()
            noteChange()
        }

        private func refreshValue() {
            valueLabel.text = "\(Int(stepper.value))"
            valueLabel.textColor = isModified ? BNGalleryColor.accent : BNGalleryColor.secondaryLabel
        }
    }

    // MARK: - Date

    /// A date, a time or both, in the system's compact picker beside the title.
    final class GalleryDateRow: GalleryKnobRow {
        private let picker = UIDatePicker()
        private let initial: Date
        private let onChange: (Date) -> Void

        override var isModified: Bool {
            picker.date != initial
        }

        init(knob: BNGalleryKnob, initial: Date, mode: UIDatePicker.Mode, onChange: @escaping (Date) -> Void) {
            self.initial = initial
            self.onChange = onChange
            super.init(knob: knob)
            picker.datePickerMode = mode
            picker.preferredDatePickerStyle = .compact
            picker.date = initial
            picker.addAction(UIAction { [weak self] _ in self?.changed() }, for: .valueChanged)
            setTrailing(picker)
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func reset() {
            picker.setDate(initial, animated: true)
            changed()
        }

        private func changed() {
            onChange(picker.date)
            noteChange()
        }
    }

    // MARK: - Custom

    /// A view of the page's own under the title. Its value is its own business: the row never
    /// counts as changed, and Reset only passes the word on.
    final class GalleryCustomRow: GalleryKnobRow {
        private let onReset: (() -> Void)?

        init(knob: BNGalleryKnob, view: UIView, onReset: (() -> Void)?) {
            self.onReset = onReset
            super.init(knob: knob)
            setBelow(view)
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func reset() {
            onReset?()
        }
    }
#endif
