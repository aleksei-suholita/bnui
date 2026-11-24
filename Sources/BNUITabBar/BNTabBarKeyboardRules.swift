import CoreGraphics

/// Pure rule of the keyboard and the bar. Kept out of the view (and out of `canImport(UIKit)`) so
/// it is tested without a simulator.
nonisolated enum BNTabBarKeyboardRules {
    /// Whether a keyboard that is about to show takes the bar's place: one with a frame to stand
    /// in does.
    ///
    /// The system also says a keyboard will show when it puts none on screen. An open iPhone Duo
    /// turned after the keyboard has been up reports one with no height, and no
    /// `keyboardWillHide` follows it (iOS 27.0.1): a bar hidden for that one stayed hidden until
    /// the app came back from the background. A notification that names no frame is taken at its
    /// word.
    static func hidesBar(keyboardEndFrame: CGRect?) -> Bool {
        guard let keyboardEndFrame else { return true }
        return !keyboardEndFrame.isEmpty
    }
}
