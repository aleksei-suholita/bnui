#if canImport(UIKit)
    import BNUI
    import UIKit

    /// A knob that tweaks one property of a control on a gallery page.
    ///
    /// Each control takes its starting value and a closure that applies a new one to the demo;
    /// Reset moves the control back to the starting value and calls the closure with it.
    public struct BNGalleryKnob {
        /// What the knob is drawn as, with its starting value and what a change does.
        public enum Control {
            /// A switch.
            case toggle(initial: Bool, onChange: (Bool) -> Void)
            /// A slider, with the value written beside the title; tapping the value takes an
            /// exact number.
            case slider(min: Double, max: Double, initial: Double, onChange: (Double) -> Void)
            /// One of several options, reported by index. Up to four short options are drawn as a
            /// segmented control; more, or longer ones, become a pull-down menu, because segments
            /// that narrow cannot be read or hit.
            case segmented(options: [String], initial: Int, onChange: (Int) -> Void)
            /// A line of text, reported on every keystroke.
            case textField(initial: String, onChange: (String) -> Void)
            /// A section divider — the knob's label is drawn as a heading, with no control.
            case header
            /// An action rather than a value: something a host would do, such as select from code.
            case button(onTap: () -> Void)
            /// A colour, in a swatch that opens the system colour picker.
            case color(initial: UIColor, onChange: (UIColor) -> Void)
            /// A whole number moved one step at a time — a count small enough to step through.
            case stepper(min: Int, max: Int, initial: Int, onChange: (Int) -> Void)
            /// A date, a time or both, in the system's compact picker.
            case date(initial: Date, mode: UIDatePicker.Mode, onChange: (Date) -> Void)
            /// A view of the page's own under the title, for a value no other control fits — an
            /// emoji picker, a palette. It keeps its own state; Reset calls `onReset`, if given.
            case custom(view: UIView, onReset: (() -> Void)? = nil)
        }

        /// A section heading above a group of knobs.
        public static func header(_ title: String) -> BNGalleryKnob {
            BNGalleryKnob(label: title, control: .header)
        }

        /// The title drawn on the row.
        public let label: String
        /// The control, its starting value and what a change does.
        public let control: Control
        /// Unit written after a slider's value — "s", "pt", "×". Ignored by other controls.
        public let unit: String?
        /// A line of help under the knob: what moving it means, or why it seems to do nothing.
        public let note: String?
        /// A slider that moves in whole steps and writes no decimals — a count, not a measure.
        var wholeNumbers = false

        /// A knob with a title, a control and, optionally, a unit and a line of help.
        public init(label: String, control: Control, unit: String? = nil, note: String? = nil) {
            self.label = label
            self.control = control
            self.unit = unit
            self.note = note
        }
    }
#endif
