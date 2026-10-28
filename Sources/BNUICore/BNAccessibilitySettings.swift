#if canImport(UIKit)
    import UIKit

    // Reduce Motion and Reduce Transparency as a control reads them: the system's switches, unless
    // a stage forces one for the views under it. The gallery's stage menu does, so a check is made
    // without a trip to Settings and holds for every control on the stage at once. The force
    // travels as a trait — it reaches the view it is set on and what lies under it, nothing else —
    // and so from iOS 17, where a trait of one's own arrives. Not API: an app reads the system.

    /// Reduce Motion forced for the views under the one it is set on; `nil` reads the system.
    @available(iOS 17.0, *)
    package nonisolated struct BNForcedReduceMotion: UITraitDefinition {
        package static let defaultValue: Bool? = nil
    }

    /// Reduce Transparency forced for the views under the one it is set on; `nil` reads the system.
    @available(iOS 17.0, *)
    package nonisolated struct BNForcedReduceTransparency: UITraitDefinition {
        package static let defaultValue: Bool? = nil
    }

    package extension UIView {
        /// Reduce Motion, as this view sees it.
        var bnReducesMotion: Bool {
            if #available(iOS 17.0, *), let forced = traitCollection[BNForcedReduceMotion.self] {
                return forced
            }
            return UIAccessibility.isReduceMotionEnabled
        }

        /// Reduce Transparency, as this view sees it.
        var bnReducesTransparency: Bool {
            if #available(iOS 17.0, *), let forced = traitCollection[BNForcedReduceTransparency.self] {
                return forced
            }
            return UIAccessibility.isReduceTransparencyEnabled
        }

        /// The forced switches, for a control to register for beside the system's notifications.
        @available(iOS 17.0, *)
        static var bnForcedAccessibilityTraits: [UITrait] {
            [BNForcedReduceMotion.self, BNForcedReduceTransparency.self]
        }
    }
#endif
