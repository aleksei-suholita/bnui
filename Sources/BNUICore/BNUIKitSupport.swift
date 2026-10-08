#if canImport(UIKit)
    import UIKit

    // Small UIKit helpers shared across the kit — and public, because a host writing its own theme
    // needs the same thing the controls do: a font at a chosen weight.

    public extension UIFont {
        /// The same font at another weight, point size and Dynamic Type scaling intact.
        ///
        /// Text styles do not come in every weight, and a theme that wants a semibold subheadline
        /// should not have to drop to a fixed point size — which is what stops the type growing.
        func withWeight(_ weight: UIFont.Weight) -> UIFont {
            let descriptor = fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight],
            ])
            return UIFont(descriptor: descriptor, size: pointSize)
        }
    }
#endif
