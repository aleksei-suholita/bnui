import CoreGraphics

/// Pure positional rules of the drag. Kept out of the view (and out of `canImport(UIKit)`) so the
/// parts that decide *what gets selected* are testable without a simulator.
public nonisolated enum BNTabBarGeometry {
    /// Section closest to a horizontal position, measured from section centres.
    ///
    /// The finger's absolute position decides, not the lens position — releasing picks what is
    /// under the finger even when the lens is still catching up, or the finger left the capsule.
    public static func nearestIndex(toX positionX: CGFloat, in centers: [CGFloat]) -> Int? {
        guard !centers.isEmpty else { return nil }
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, centre) in centers.enumerated() {
            let distance = abs(centre - positionX)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    /// Keeps the lens inside the bar: dragging past the edge makes it stop there rather than
    /// travel outside the capsule.
    public static func clampedLensOriginX(_ originX: CGFloat, lensWidth: CGFloat, barWidth: CGFloat) -> CGFloat {
        let maxOrigin = max(barWidth - lensWidth, 0)
        return min(max(originX, 0), maxOrigin)
    }
}
