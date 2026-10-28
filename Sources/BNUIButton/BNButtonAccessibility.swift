import Foundation

/// Words VoiceOver says. Carried by the configuration rather than the theme: this is the host's
/// language, not its appearance.
public nonisolated struct BNButtonAccessibilityStrings: Equatable, Sendable {
    /// Spoken while the button is loading.
    public var busyValue: String
    /// Spoken for a disabled button; `nil` leaves the system's own wording.
    public var disabledHint: String?

    public init(busyValue: String = "In progress", disabledHint: String? = nil) {
        self.busyValue = busyValue
        self.disabledHint = disabledHint
    }

    public static let standard = BNButtonAccessibilityStrings()
}
