#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// A knob that tweaks one property of a control on a gallery page.
    public struct GalleryKnob {
        public enum Control {
            case toggle(initial: Bool, onChange: (Bool) -> Void)
            case slider(min: Double, max: Double, initial: Double, onChange: (Double) -> Void)
            /// Up to four short options are drawn as a segmented control; more, or longer ones,
            /// become a pull-down menu, because segments that narrow cannot be read or hit.
            case segmented(options: [String], initial: Int, onChange: (Int) -> Void)
            case textField(initial: String, onChange: (String) -> Void)
            /// A section divider — the knob's label is drawn as a heading, with no control.
            case header
            case button(onTap: () -> Void)
        }

        /// A section heading above a group of knobs.
        public static func header(_ title: String) -> GalleryKnob {
            GalleryKnob(label: title, control: .header)
        }

        public let label: String
        public let control: Control
        /// Unit written after a slider's value — "s", "pt", "×". Ignored by other controls.
        public let unit: String?
        /// A line of help under the knob: what moving it means, or why it seems to do nothing.
        public let note: String?

        public init(label: String, control: Control, unit: String? = nil, note: String? = nil) {
            self.label = label
            self.control = control
            self.unit = unit
            self.note = note
        }
    }
#endif
