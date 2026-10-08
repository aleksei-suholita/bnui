/// Whether the bar is on screen.
public nonisolated enum BNTabBarPresentation: Equatable, Sendable {
    case expanded
    /// Off screen; the bar reports zero effective height so the host drops its inset.
    case hidden

    public var isHidden: Bool {
        self == .hidden
    }
}
