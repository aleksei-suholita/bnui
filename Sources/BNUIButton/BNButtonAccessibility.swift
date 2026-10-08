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

/// Environment values the host can force instead of reading from the system.
///
/// This exists for the gallery: the acceptance checklist asks for Reduce Motion and Reduce
/// Transparency to be verified, and walking to Settings between each check is how those checks
/// get skipped. `nil` means "read the system", which is what production passes.
public nonisolated struct BNButtonAccessibilityOverrides: Equatable, Sendable {
    public var reduceMotion: Bool?
    public var reduceTransparency: Bool?

    public init(reduceMotion: Bool? = nil, reduceTransparency: Bool? = nil) {
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
    }

    public func resolvedReduceMotion(system: Bool) -> Bool {
        reduceMotion ?? system
    }

    public func resolvedReduceTransparency(system: Bool) -> Bool {
        reduceTransparency ?? system
    }

    public static let none = BNButtonAccessibilityOverrides()
}
