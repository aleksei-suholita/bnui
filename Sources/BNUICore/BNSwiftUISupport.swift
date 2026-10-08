#if canImport(SwiftUI)
    import SwiftUI

    // The Foundation layer, spoken in SwiftUI's terms: a SwiftUI screen next to a kit control
    // moves on the same springs. Gated on SwiftUI rather than UIKit, so the macOS build of
    // `swift test` compiles these too.

    public nonisolated extension BNSpring {
        /// The same spring as a SwiftUI animation.
        ///
        /// Two SwiftUI springs, picked by the push: without one, `.spring` — it retargets an
        /// animation already in flight and keeps its velocity, which is how the kit's own
        /// animators behave when a new touch takes over. With one, `.interpolatingSpring`, the only
        /// SwiftUI spring that accepts a starting velocity: a gesture's momentum carried into the
        /// release matters more than how the release is interrupted.
        var animation: Animation {
            guard initialVelocity != 0 else {
                return .spring(duration: duration, bounce: Double(bounce))
            }
            return .interpolatingSpring(duration: duration, bounce: Double(bounce), initialVelocity: Double(initialVelocity))
        }
    }

    public nonisolated extension BNCurve {
        var animation: Animation {
            switch timing {
            case .easeInOut:
                .easeInOut(duration: duration)
            case let .controlPoints(x1, y1, x2, y2):
                .timingCurve(Double(x1), Double(y1), Double(x2), Double(y2), duration: duration)
            }
        }
    }

    public nonisolated extension BNTransition {
        /// `nil` for `.immediate`, which is exactly what `withAnimation(_:)` takes for "no animation".
        var animation: Animation? {
            switch self {
            case .immediate: nil
            case let .spring(spring): spring.animation
            case let .curve(curve): curve.animation
            }
        }
    }
#endif
