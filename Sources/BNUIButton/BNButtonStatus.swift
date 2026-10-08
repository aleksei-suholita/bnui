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
}
