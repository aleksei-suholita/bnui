#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    // MARK: - Slider

    /// A number: the value written out beside the title, the slider under it.
    ///
    /// Tapping the value opens a field for an exact number — "set it to 0.40" is a common ask a
    /// thumb on a 300-point track cannot meet. Dragging past the initial value sticks to it for a
    /// moment with a tick, so the shipped value is found again by feel rather than by squinting.
    final class GallerySliderRow: GalleryKnobRow {
        private let slider = UISlider()
        private let valueButton = UIButton(configuration: .plain())
        private let range: ClosedRange<Double>
        private let initial: Double
        private let onChange: (Double) -> Void
        private let decimals: Int
        /// Whether the thumb is resting on the initial value, so the tick plays once on arrival.
        private var isOnInitial = true

        private var span: Double {
            range.upperBound - range.lowerBound
        }

        override var isModified: Bool {
            abs(Double(slider.value) - initial) > span * 0.0005
        }

        init(knob: GalleryKnob, range: ClosedRange<Double>, initial: Double, onChange: @escaping (Double) -> Void) {
            self.range = range
            self.initial = initial
            self.onChange = onChange
            decimals = Self.decimals(for: range)
            super.init(knob: knob)

            slider.minimumValue = Float(range.lowerBound)
            slider.maximumValue = Float(range.upperBound)
            slider.value = Float(initial)
            slider.addAction(UIAction { [weak self] _ in self?.sliderMoved() }, for: .valueChanged)

            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 0)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = BNGalleryFont.value
                return attributes
            }
            valueButton.configuration = configuration
            valueButton.addAction(UIAction { [weak self] _ in self?.presentEntry() }, for: .primaryActionTriggered)
            valueButton.accessibilityHint = "Enter an exact value"

            setTrailing(valueButton)
            setBelow(slider)
            refreshValue()
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func reset() {
            set(initial, animated: true)
        }

        private func sliderMoved() {
            var value = Double(slider.value)
            if abs(value - initial) < span * 0.015 {
                value = initial
                slider.value = Float(initial)
                if !isOnInitial {
                    BNHaptics.shared.play(.selection, merging: false)
                }
                isOnInitial = true
            } else {
                isOnInitial = false
            }
            commit(value)
        }

        private func set(_ value: Double, animated: Bool) {
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            slider.setValue(Float(clamped), animated: animated)
            isOnInitial = abs(clamped - initial) < span * 0.015
            commit(clamped)
        }

        private func commit(_ value: Double) {
            onChange(value)
            refreshValue()
            noteChange()
        }

        private func refreshValue() {
            valueButton.configuration?.title = formatted(Double(slider.value))
            valueButton.configuration?.baseForegroundColor = isModified ? BNGalleryColor.accent : BNGalleryColor.secondaryLabel
        }

        private func presentEntry() {
            guard let host = galleryHostViewController else { return }
            let alert = UIAlertController(
                title: knob.label,
                message: "\(formatted(range.lowerBound)) … \(formatted(range.upperBound))",
                preferredStyle: .alert,
            )
            let current = String(format: "%.\(decimals)f", Double(slider.value))
            alert.addTextField { field in
                field.keyboardType = .decimalPad
                field.text = current
                field.clearButtonMode = .always
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Default · \(formatted(initial))", style: .default) { [weak self] _ in
                guard let self else { return }
                set(initial, animated: true)
            })
            let apply = UIAlertAction(title: "Set", style: .default) { [weak self, weak alert] _ in
                // A decimal pad types the locale's separator; a comma is a point here.
                guard let text = alert?.textFields?.first?.text?.replacingOccurrences(of: ",", with: "."),
                      let value = Double(text)
                else { return }
                self?.set(value, animated: true)
            }
            alert.addAction(apply)
            alert.preferredAction = apply
            host.present(alert, animated: true)
        }

        private func formatted(_ value: Double) -> String {
            let number = String(format: "%.\(decimals)f", value)
            guard let unit = knob.unit else { return number }
            // A multiplier or a percentage hugs its number; a real unit is set off by a space.
            return unit == "×" || unit == "%" ? number + unit : "\(number) \(unit)"
        }

        /// Enough digits to tell two thumb positions apart, and no more: a 0…1 range wants
        /// hundredths, 0…200 wants whole numbers.
        private static func decimals(for range: ClosedRange<Double>) -> Int {
            switch range.upperBound - range.lowerBound {
            case ..<2: 2
            case ..<20: 1
            default: 0
            }
        }
    }

    // MARK: - Choice

    /// One of several options. Up to four short ones are segments under the title; more, or longer
    /// ones, a pull-down beside it — five segments on a phone are slivers nobody can read or hit.
    final class GalleryChoiceRow: GalleryKnobRow {
        private let options: [String]
        private let initial: Int
        private let onChange: (Int) -> Void
        private var selected: Int
        private var segments: UISegmentedControl?
        private var menuButton: UIButton?

        override var isModified: Bool {
            selected != initial
        }

        init(knob: GalleryKnob, options: [String], initial: Int, onChange: @escaping (Int) -> Void) {
            self.options = options
            self.initial = initial
            self.onChange = onChange
            selected = options.indices.contains(initial) ? initial : 0
            super.init(knob: knob)

            if Self.fitsSegments(options) {
                let control = UISegmentedControl(items: options)
                control.selectedSegmentIndex = selected
                control.addAction(UIAction { [weak self, weak control] _ in
                    self?.select(control?.selectedSegmentIndex ?? 0)
                }, for: .valueChanged)
                setBelow(control)
                segments = control
            } else {
                var configuration = UIButton.Configuration.gray()
                configuration.image = UIImage(
                    systemName: "chevron.up.chevron.down",
                    withConfiguration: UIImage.SymbolConfiguration(scale: .small),
                )
                configuration.imagePlacement = .trailing
                configuration.imagePadding = BNGallerySpacing.xs
                configuration.buttonSize = .small
                configuration.cornerStyle = .capsule
                let button = UIButton(configuration: configuration)
                button.showsMenuAsPrimaryAction = true
                setTrailing(button)
                menuButton = button
            }
            refresh()
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func reset() {
            select(initial)
        }

        private func select(_ index: Int) {
            guard options.indices.contains(index) else { return }
            selected = index
            onChange(index)
            refresh()
            noteChange()
        }

        private func refresh() {
            segments?.selectedSegmentIndex = selected
            guard let menuButton, options.indices.contains(selected) else { return }
            menuButton.configuration?.title = options[selected]
            menuButton.configuration?.baseForegroundColor = isModified ? BNGalleryColor.accent : BNGalleryColor.label
            menuButton.menu = UIMenu(options: .singleSelection, children: options.enumerated().map { index, title in
                UIAction(
                    title: title,
                    subtitle: index == initial ? "Default" : nil,
                    state: index == selected ? .on : .off,
                ) { [weak self] _ in
                    self?.select(index)
                }
            })
        }

        private static func fitsSegments(_ options: [String]) -> Bool {
            options.count <= 4 && options.reduce(0) { $0 + $1.count } <= 24
        }
    }
#endif
