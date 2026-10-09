import SwiftUI

extension BNButtonSize {
    /// The kit's step for SwiftUI's `.controlSize`, which ``BN/Button`` reads from the environment.
    ///
    /// SwiftUI has five sizes and the kit three, so the outer ones fold inwards: `mini` and `small`
    /// are `small`, `large` and `extraLarge` are `large`.
    nonisolated init(_ controlSize: ControlSize) {
        switch controlSize {
        case .mini, .small:
            self = .small
        case .regular:
            self = .medium
        case .large:
            self = .large
        default:
            // `extraLarge`, which arrives with iOS 17, and whatever SwiftUI adds above it.
            self = .large
        }
    }
}
