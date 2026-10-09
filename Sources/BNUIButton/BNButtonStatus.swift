import Foundation

/// What the button is doing, as told by the host.
///
/// One case list rather than a pair of flags: `isEnabled == false` together with `isLoading == true`
/// is a combination that would have to be explained in every branch that reads them. The control
/// never sets this itself — it does not start work, it shows that the host started some.
public nonisolated enum BNButtonStatus: Equatable, Sendable {
    case enabled
    case disabled
    case loading

    /// Only an enabled button reacts to a finger. `loading` still receives touches — it swallows
    /// them — so that a tap does not fall through to whatever sits behind the button.
    public var allowsInteraction: Bool {
        self == .enabled
    }

    /// `disabled` is unavailable to VoiceOver; `loading` stays available and reports itself busy.
    public var isAccessibilityEnabled: Bool {
        self != .disabled
    }

    /// The status the SwiftUI face's two signals add up to: `.disabled()` from the environment and
    /// the button's own `isLoading`.
    ///
    /// Busy wins. Disabling a whole form while it submits is ordinary SwiftUI, and the button
    /// doing the submitting must keep its spinner rather than turn dim and shake at a tap.
    static func resolving(isLoading: Bool, isEnabled: Bool) -> BNButtonStatus {
        if isLoading {
            return .loading
        }
        return isEnabled ? .enabled : .disabled
    }

    /// The status after `UIControl.isEnabled` is set on the button.
    ///
    /// `loading` survives the flag either way, by the same rule: busy wins. A host toggling the
    /// flag on a loading button did not mean "stop loading" — and neither did SwiftUI, which sets
    /// it on a wrapped control under `.disabled()`.
    func settingEnabledFlag(_ isEnabled: Bool) -> BNButtonStatus {
        if self == .loading {
            return .loading
        }
        return isEnabled ? .enabled : .disabled
    }
}
