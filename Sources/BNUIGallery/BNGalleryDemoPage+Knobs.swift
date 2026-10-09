#if (DEBUG || GalleryInRelease) && canImport(UIKit)
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
        static func toggle(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Bool>,
            note: String? = nil,
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .toggle(initial: demo[keyPath: property], onChange: { demo[keyPath: property] = $0 }),
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
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .slider(
                        min: range.lowerBound,
                        max: range.upperBound,
                        initial: demo[keyPath: property],
                        onChange: { demo[keyPath: property] = $0 },
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
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .slider(
                        min: Double(range.lowerBound),
                        max: Double(range.upperBound),
                        initial: Double(demo[keyPath: property]),
                        onChange: { demo[keyPath: property] = CGFloat($0) },
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
        ) -> Self {
            Self { demo in
                var knob = BNGalleryKnob(
                    label: label,
                    control: .slider(
                        min: Double(range.lowerBound),
                        max: Double(range.upperBound),
                        initial: Double(demo[keyPath: property]),
                        onChange: { demo[keyPath: property] = Int($0.rounded()) },
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
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .textField(initial: demo[keyPath: property], onChange: { demo[keyPath: property] = $0 }),
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
        ) -> Self {
            Self { demo in
                BNGalleryKnob(
                    label: label,
                    control: .textField(
                        initial: demo[keyPath: property] ?? "",
                        onChange: { demo[keyPath: property] = $0.isEmpty ? nil : $0 },
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
        ) -> Self {
            choosing(label, property, among: Value.allCases.map { (title(of: $0), $0) }, note: note)
        }

        /// One of the given values under the given titles — for a property whose values are not a
        /// plain list of cases: `options: ["Off": nil, "Count": .count(3), "Dot": .dot]`.
        static func choice<Value: Equatable>(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Value>,
            options: KeyValuePairs<String, Value>,
            note: String? = nil,
        ) -> Self {
            choosing(label, property, among: options.map { ($0.key, $0.value) }, note: note)
        }

        /// A value the options do not list starts the row on the first option, and Reset then
        /// writes that option rather than the value the demo started with.
        private static func choosing<Value: Equatable>(
            _ label: String,
            _ property: ReferenceWritableKeyPath<Subject, Value>,
            among options: [(title: String, value: Value)],
            note: String?,
        ) -> Self {
            Self { demo in
                let initial = options.firstIndex { $0.value == demo[keyPath: property] } ?? 0
                return BNGalleryKnob(
                    label: label,
                    control: .segmented(
                        options: options.map(\.title),
                        initial: initial,
                        onChange: { demo[keyPath: property] = options[$0].value },
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
