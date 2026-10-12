#if canImport(UIKit)
    import UIKit

    public extension BNGalleryDemoPage.Knob {
        /// Any knob driven by closures of its own — for a value set through a method rather than
        /// a property: `.knob(BNGalleryKnob(label: "Speed", control: .slider(…) { pill.setSpeed($0) }))`.
        static func knob(_ knob: BNGalleryKnob) -> Self {
            Self { _ in knob }
        }

        /// A section heading above a group of knobs.
        static func header(_ title: String) -> Self {
            .knob(.header(title))
        }

        /// An action rather than a value — something a host would do, such as select from code.
        static func button(_ label: String, note: String? = nil, action: @escaping () -> Void) -> Self {
            .knob(BNGalleryKnob(label: label, control: .button(onTap: action), note: note))
        }

        /// A switch bound to a `Bool` property of the demo.
        ///
        /// `then` runs after every write, Reset's included — for what the value brings along, such
        /// as a second property it implies: `.toggle("Compact", \.isCompact) { $0.width = $1 ? .hug : .fill }`.
        /// The sliders, the text fields and the choices take one too.
        static func toggle(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Bool>,
            note: String? = nil,
            then: ((Subject, Bool) -> Void)? = nil,
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .toggle(initial: demo[keyPath: property], onChange: { value in
                        demo[keyPath: property] = value
                        then?(demo, value)
                    }),
                    note: note,
                )
            }
        }

        /// A slider bound to a `Double` property of the demo.
        static func slider(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Double>,
            in range: ClosedRange<Double>,
            unit: String? = nil,
            note: String? = nil,
            then: ((Subject, Double) -> Void)? = nil,
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .slider(
                        min: range.lowerBound,
                        max: range.upperBound,
                        initial: demo[keyPath: property],
                        onChange: { value in
                            demo[keyPath: property] = value
                            then?(demo, value)
                        },
                    ),
                    unit: unit,
                    note: note,
                )
            }
        }

        /// A slider bound to a `CGFloat` property of the demo — a size, a radius, an alpha.
        static func slider(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, CGFloat>,
            in range: ClosedRange<CGFloat>,
            unit: String? = nil,
            note: String? = nil,
            then: ((Subject, CGFloat) -> Void)? = nil,
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .slider(
                        min: Double(range.lowerBound),
                        max: Double(range.upperBound),
                        initial: Double(demo[keyPath: property]),
                        onChange: { value in
                            demo[keyPath: property] = CGFloat(value)
                            then?(demo, CGFloat(value))
                        },
                    ),
                    unit: unit,
                    note: note,
                )
            }
        }

        /// A slider in whole steps bound to an `Int` property of the demo — a count, not a measure.
        static func slider(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Int>,
            in range: ClosedRange<Int>,
            unit: String? = nil,
            note: String? = nil,
            then: ((Subject, Int) -> Void)? = nil,
        ) -> Self {
            Self { demo in
                var knob = BNGalleryKnob(
                    label: label,
                    control: .slider(
                        min: Double(range.lowerBound),
                        max: Double(range.upperBound),
                        initial: Double(demo[keyPath: property]),
                        onChange: { value in
                            demo[keyPath: property] = Int(value.rounded())
                            then?(demo, Int(value.rounded()))
                        },
                    ),
                    unit: unit,
                    note: note,
                )
                knob.wholeNumbers = true
                return knob
            }
        }

        /// A text field bound to a `String` property of the demo.
        static func text(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, String>,
            note: String? = nil,
            then: ((Subject, String) -> Void)? = nil,
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .textField(initial: demo[keyPath: property], onChange: { value in
                        demo[keyPath: property] = value
                        then?(demo, value)
                    }),
                    note: note,
                )
            }
        }

        /// A text field bound to an optional `String` property of the demo, such as a label's
        /// `text`. An empty field writes `nil`.
        static func text(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, String?>,
            note: String? = nil,
            then: ((Subject, String?) -> Void)? = nil,
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .textField(
                        initial: demo[keyPath: property] ?? "",
                        onChange: { text in
                            let value = text.isEmpty ? nil : text
                            demo[keyPath: property] = value
                            then?(demo, value)
                        },
                    ),
                    note: note,
                )
            }
        }

        /// One of the cases of an enum property, titled after the cases: `.extraLarge` reads
        /// "Extra large".
        static func choice<Value: CaseIterable & Equatable>(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Value>,
            note: String? = nil,
            then: ((Subject, Value) -> Void)? = nil,
        ) -> Self {
            choosing(label, property, among: Value.allCases.map { (title(of: $0), $0) }, note: note, then: then)
        }

        /// One of the given values under the given titles — for a property whose values are not a
        /// plain list of cases: `options: ["Off": nil, "Count": .count(3), "Dot": .dot]`.
        static func choice<Value: Equatable>(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Value>,
            options: KeyValuePairs<String, Value>,
            note: String? = nil,
            then: ((Subject, Value) -> Void)? = nil,
        ) -> Self {
            choosing(label, property, among: options.map { ($0.key, $0.value) }, note: note, then: then)
        }

        /// A colour well bound to a `UIColor` property of the demo.
        static func color(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, UIColor>,
            note: String? = nil,
        ) -> Self {
            Self { subject in
                BNGalleryKnob(
                    label: label,
                    control: .color(initial: subject[keyPath: property], onChange: { subject[keyPath: property] = $0 }),
                    note: note,
                )
            }
        }

        /// A colour well bound to an optional `UIColor` property of the demo, such as a view's
        /// `tintColor` or `backgroundColor`. No colour starts the well clear.
        static func color(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, UIColor?>,
            note: String? = nil,
        ) -> Self {
            Self { subject in
                BNGalleryKnob(
                    label: label,
                    control: .color(initial: subject[keyPath: property] ?? .clear, onChange: { subject[keyPath: property] = $0 }),
                    note: note,
                )
            }
        }

        /// A stepper bound to an `Int` property of the demo — a count small enough to step through.
        static func stepper(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Int>,
            in range: ClosedRange<Int>,
            note: String? = nil,
        ) -> Self {
            Self { subject in
                BNGalleryKnob(
                    label: label,
                    control: .stepper(
                        min: range.lowerBound,
                        max: range.upperBound,
                        initial: subject[keyPath: property],
                        onChange: { subject[keyPath: property] = $0 },
                    ),
                    note: note,
                )
            }
        }

        /// A date picker bound to a `Date` property of the demo.
        static func date(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Date>,
            mode: UIDatePicker.Mode = .dateAndTime,
            note: String? = nil,
        ) -> Self {
            Self { subject in
                BNGalleryKnob(
                    label: label,
                    control: .date(initial: subject[keyPath: property], mode: mode, onChange: { subject[keyPath: property] = $0 }),
                    note: note,
                )
            }
        }

        /// A view of the page's own under the title, for a value no other knob fits:
        /// `.custom("Emoji") { EmojiPicker { pill.emoji = $0 } }`. The view keeps its own state;
        /// `onReset`, if given, is what Reset does to it. On a page of states it drives the
        /// demo it was made for — the first.
        static func custom(
            _ label: String,
            note: String? = nil,
            onReset: (() -> Void)? = nil,
            view: @escaping () -> UIView,
        ) -> Self {
            Self { _ in
                BNGalleryKnob(label: label, control: .custom(view: view(), onReset: onReset), note: note)
            }
        }

        /// A value the options do not list starts the row on the first option, and Reset then
        /// writes that option rather than the value the demo started with.
        private static func choosing<Value: Equatable>(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Value>,
            among options: [(title: String, value: Value)],
            note: String?,
            then: ((Subject, Value) -> Void)?,
        ) -> Self {
            Self { demo in
                let initial = options.firstIndex { $0.value == demo[keyPath: property] } ?? 0
                return BNGalleryKnob(
                    label: label,
                    control: .segmented(
                        options: options.map(\.title),
                        initial: initial,
                        onChange: { index in
                            demo[keyPath: property] = options[index].value
                            then?(demo, options[index].value)
                        },
                    ),
                    note: note,
                )
            }
        }

        /// A case's name as a title: `extraLarge` → "Extra large".
        private static func title(of value: some Any) -> String {
            var words: [String] = []
            for character in String(describing: value) {
                if character.isUppercase || words.isEmpty {
                    words.append(String(character).lowercased())
                } else {
                    words[words.count - 1].append(character)
                }
            }
            let phrase = words.joined(separator: " ")
            return phrase.prefix(1).uppercased() + phrase.dropFirst()
        }
    }
#endif
