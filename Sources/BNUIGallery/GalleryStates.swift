#if canImport(UIKit)
    import BNUI
    import UIKit

    /// A page's demo in each of its states, one under another with its name above it, scrolling
    /// once they outgrow the stage.
    ///
    /// A demo that comes with a controller — a Present button, a SwiftUI host — is kept as a child,
    /// so it can present and gets the stage's traits. Events from a row reach the feed with the
    /// state's name in front, and Reset reaches every row.
    final class GalleryStatesController: UIViewController {
        /// What a row shows.
        enum Content {
            case view(UIView)
            case controller(UIViewController)
        }

        struct Row {
            let name: String
            let subject: AnyObject
            let content: Content
        }

        private let rows: [Row]
        private let acrossWidth: Bool
        private let carrier: GalleryCarrierView

        init(rows: [Row], acrossWidth: Bool) {
            self.rows = rows
            self.acrossWidth = acrossWidth
            carrier = GalleryCarrierView(subjects: rows.map(\.subject))
            super.init(nibName: nil, bundle: nil)
        }

        nonisolated deinit {}

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func loadView() {
            view = carrier
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            let column = UIStackView()
            column.axis = .vertical
            column.spacing = BNGallerySpacing.l
            var demos: [UIView] = []
            for row in rows {
                let demo = place(row.content)
                demos.append(demo)
                (demo as? any BNGalleryEventReporting)?.onGalleryEvent = { [weak carrier] event in
                    carrier?.onGalleryEvent?("\(row.name): \(event)")
                }
                column.addArrangedSubview(stateRow(named: row.name, showing: demo))
            }
            carrier.onReset = {
                for demo in demos {
                    (demo as? any GalleryDemoResetting)?.resetForGallery()
                }
            }
            carrier.embed(scrolling(column))
        }

        /// The row's demo view; a controller's becomes a child on the way.
        private func place(_ content: Content) -> UIView {
            switch content {
            case let .view(view):
                return view
            case let .controller(controller):
                addChild(controller)
                defer { controller.didMove(toParent: self) }
                return controller.view
            }
        }

        private func stateRow(named name: String, showing demo: UIView) -> UIView {
            let caption = UILabel()
            caption.text = name
            caption.font = .preferredFont(forTextStyle: .footnote)
            caption.adjustsFontForContentSizeCategory = true
            caption.textColor = BNGalleryColor.secondaryLabel

            // A page across the width spans every state, the way a field spans a form; otherwise
            // each state's demo decides by itself, so a button that hugs and one that fills sit
            // side by side as they would on a screen.
            let held = acrossWidth ? demo : GalleryWidthFitView(demo: demo)
            let row = UIStackView(arrangedSubviews: [caption, held])
            row.axis = .vertical
            row.spacing = BNGallerySpacing.xs
            return row
        }

        /// The column inside the stage's margins, scrolling only when it is taller than the stage.
        private func scrolling(_ column: UIStackView) -> UIScrollView {
            let scroll = UIScrollView()
            scroll.backgroundColor = .clear
            scroll.delaysContentTouches = false
            scroll.alwaysBounceVertical = false
            column.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(column)
            let margin = BNGallerySpacing.m
            NSLayoutConstraint.activate([
                column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: margin),
                column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -margin),
                column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: margin),
                column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -margin),
            ])
            return scroll
        }
    }

    extension BNGalleryKnob {
        /// One knob driving the same knob of several demos, each started from a value of its own.
        ///
        /// Moving it sets them all to the one value; bringing it back to where it started — by hand
        /// or by Reset — puts each back where it started, so the states of a states page survive
        /// the knobs. The row shows the first demo's starting value.
        static func fanOut(_ knobs: [BNGalleryKnob]) -> BNGalleryKnob {
            guard let first = knobs.first else { return .header("") }
            guard knobs.count > 1 else { return first }
            var knob = BNGalleryKnob(
                label: first.label,
                control: first.control.driving(knobs.map(\.control)),
                unit: first.unit,
                note: first.note,
            )
            knob.wholeNumbers = first.wholeNumbers
            return knob
        }
    }

    extension BNGalleryKnob.Control {
        /// This control with its changes passed on to `controls` — the same knob, one per demo.
        func driving(_ controls: [Self]) -> Self {
            switch self {
            case let .toggle(initial, _):
                .toggle(initial: initial, onChange: Self.spread(initial, controls.compactMap(\.toggle)))
            case let .slider(min, max, initial, _):
                .slider(min: min, max: max, initial: initial, onChange: Self.spread(initial, controls.compactMap(\.slider)))
            case let .segmented(options, initial, _):
                .segmented(options: options, initial: initial, onChange: Self.spread(initial, controls.compactMap(\.choice)))
            case let .textField(initial, _):
                .textField(initial: initial, onChange: Self.spread(initial, controls.compactMap(\.text)))
            case let .color(initial, _):
                .color(initial: initial, onChange: Self.spread(initial, controls.compactMap(\.colorPart)))
            case let .stepper(min, max, initial, _):
                .stepper(min: min, max: max, initial: initial, onChange: Self.spread(initial, controls.compactMap(\.stepperPart)))
            case let .date(initial, mode, _):
                .date(initial: initial, mode: mode, onChange: Self.spread(initial, controls.compactMap(\.datePart)))
            case .header, .custom:
                // A heading has nothing to pass on; a view of the page's own drives the first demo.
                self
            case .button:
                .button(onTap: {
                    for tap in controls.compactMap(\.tap) {
                        tap()
                    }
                })
            }
        }

        /// A change for every demo: the new value, or each demo's own start when the value is the
        /// shared start again.
        private static func spread<Value: Equatable>(
            _ initial: Value,
            _ demos: [(start: Value, change: (Value) -> Void)],
        ) -> (Value) -> Void {
            { value in
                for demo in demos {
                    demo.change(value == initial ? demo.start : value)
                }
            }
        }

        private var toggle: (start: Bool, change: (Bool) -> Void)? {
            if case let .toggle(start, change) = self {
                (start, change)
            } else {
                nil
            }
        }

        private var slider: (start: Double, change: (Double) -> Void)? {
            if case let .slider(_, _, start, change) = self {
                (start, change)
            } else {
                nil
            }
        }

        private var choice: (start: Int, change: (Int) -> Void)? {
            if case let .segmented(_, start, change) = self {
                (start, change)
            } else {
                nil
            }
        }

        private var text: (start: String, change: (String) -> Void)? {
            if case let .textField(start, change) = self {
                (start, change)
            } else {
                nil
            }
        }

        private var colorPart: (start: UIColor, change: (UIColor) -> Void)? {
            if case let .color(start, change) = self {
                (start, change)
            } else {
                nil
            }
        }

        private var stepperPart: (start: Int, change: (Int) -> Void)? {
            if case let .stepper(_, _, start, change) = self {
                (start, change)
            } else {
                nil
            }
        }

        private var datePart: (start: Date, change: (Date) -> Void)? {
            if case let .date(start, _, change) = self {
                (start, change)
            } else {
                nil
            }
        }

        private var tap: (() -> Void)? {
            if case let .button(onTap) = self {
                onTap
            } else {
                nil
            }
        }
    }
#endif
