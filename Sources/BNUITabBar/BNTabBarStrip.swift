import CoreGraphics

/// The strip the system keeps for bars beside the content — on iPhone Duo, the side of the screen
/// its own bars move to — and where a vertical bar stands in it. Pure numbers, no UIKit, so the
/// rule is tested on macOS.
///
/// The bar stands where the system puts its own tab bar: at the bottom of the strip, centred across
/// it. What the system reserves inside the strip — the camera, the status bar, a fold — is not
/// stood on, and the bar keeps to the free stretch the bottom of the strip belongs to: the
/// stretches above it are where the system's own buttons go.
nonisolated struct BNTabBarStrip: Equatable {
    /// The side of the screen the strip is on — a side of the hardware, not of the reading
    /// direction: the system keeps its bar on the same side in a right-to-left language.
    enum Side: Equatable {
        case left
        case right
    }

    var side: Side
    /// How far the strip reaches in from its side: the safe area's inset there.
    var width: CGFloat
    /// What the system reserves, in the space the strip is measured in. A fold is a line with no
    /// width; it still divides the strip.
    var reserved: [CGRect]

    /// The rectangle a bar stands in: the strip's whole width, from the top of its bottom stretch
    /// to its bottom. Nil when the strip is narrower than `thickness` or that stretch is shorter
    /// than `minimumLength` — the bar then stays a row at the bottom of the screen.
    ///
    /// - Parameters:
    ///   - bounds: The space the strip runs along — the container's view.
    ///   - top: The safe area's top inset; the strip starts under it.
    ///   - bottom: The safe area's bottom inset; the strip ends above it.
    ///   - thickness: How wide the bar is across the strip.
    ///   - minimumLength: The shortest the bar gets along the strip.
    ///   - gap: What the bar keeps between itself and anything reserved above or below it.
    func column(
        in bounds: CGRect,
        top: CGFloat,
        bottom: CGFloat,
        thickness: CGFloat,
        minimumLength: CGFloat,
        gap: CGFloat = 0,
    ) -> CGRect? {
        guard width >= thickness, thickness > 0 else { return nil }
        let minX = switch side {
        case .left: bounds.minX
        case .right: bounds.maxX - width
        }
        let start = bounds.minY + max(top, 0)
        var end = bounds.maxY - max(bottom, 0)
        guard end > start else { return nil }

        // Only what reaches into the strip counts. Compared as closed intervals, so a fold — a
        // rectangle with no width — still meets it.
        let inStrip = reserved
            .map { $0.insetBy(dx: 0, dy: -max(gap, 0)) }
            .filter { $0.minX <= minX + width && $0.maxX >= minX && $0.maxY > start && $0.minY < end }
        // Whatever sits on the bottom of the strip lifts the stretch above it; from the lowest
        // reach up, so one region covering the next lifts it past both.
        for region in inStrip.sorted(by: { $0.maxY > $1.maxY }) where region.maxY >= end && region.minY < end {
            end = region.minY
        }
        let stretchTop = inStrip.map(\.maxY).filter { $0 < end }.max().map { max($0, start) } ?? start
        guard end - stretchTop >= minimumLength else { return nil }
        return CGRect(x: minX, y: stretchTop, width: width, height: end - stretchTop)
    }
}
