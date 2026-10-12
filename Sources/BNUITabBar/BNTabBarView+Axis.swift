#if canImport(UIKit)
    import UIKit

    // MARK: - Along the bar

    // A row and a column are one bar turned on its side: the lens and the finger move along the
    // bar, and across it everything spans the bar whole. These read a point or a rectangle along
    // whichever way the bar runs, so the lens and the gesture are written once for both.

    extension NSLayoutConstraint.Axis {
        /// The point's coordinate along the axis.
        func position(of point: CGPoint) -> CGFloat {
            self == .vertical ? point.y : point.x
        }

        /// Where the rectangle starts along the axis.
        func start(of rect: CGRect) -> CGFloat {
            self == .vertical ? rect.minY : rect.minX
        }

        /// The rectangle's extent along the axis.
        func length(of rect: CGRect) -> CGFloat {
            self == .vertical ? rect.height : rect.width
        }

        /// The rectangle's extent across the axis.
        func thickness(of rect: CGRect) -> CGFloat {
            self == .vertical ? rect.width : rect.height
        }

        /// A rectangle `length` long from `start` along the axis, spanning `thickness` across it
        /// from the edge.
        func rect(start: CGFloat, length: CGFloat, thickness: CGFloat) -> CGRect {
            self == .vertical
                ? CGRect(x: 0, y: start, width: thickness, height: length)
                : CGRect(x: start, y: 0, width: length, height: thickness)
        }
    }

    extension BNTabBarView {
        /// How wide the bar is as a column: a section's square and the capsule's padding, or the
        /// action, whichever is wider.
        var columnThickness: CGFloat {
            let geometry = activeTheme.geometry
            let action = action == nil ? 0 : max(geometry.actionSide, BNTabBarMetrics.minimumTouchTarget)
            return max(geometry.effectiveItemHeight + 2 * geometry.capsulePadding, action)
        }

        /// What a column keeps between itself and what is reserved in its strip — the camera, the
        /// system's buttons: the gap it keeps between the sections and the action.
        var columnGap: CGFloat {
            activeTheme.geometry.actionSpacing
        }

        /// The shortest the bar gets as a column: every section standing — up to the slots a bar
        /// holds at most — and the action under them. A strip too short for that leaves the bar a
        /// row: no section goes behind More only because the bar turned.
        var minimumColumnLength: CGFloat {
            let geometry = activeTheme.geometry
            let slots = CGFloat(min(max(items.count, 1), BNTabBarLayoutSolver.maximumSlots))
            let capsule = slots * geometry.effectiveItemHeight + (slots - 1) * geometry.itemSpacing
                + 2 * geometry.capsulePadding
            let action = action == nil
                ? 0
                : max(geometry.actionSide, BNTabBarMetrics.minimumTouchTarget) + geometry.actionSpacing
            return capsule + action
        }
    }

    public extension BNTabBarView {
        /// A column's view runs the length of the strip, and most of it is empty above the capsule
        /// — the part of the strip where the system's own buttons go. It takes a touch only where
        /// it draws, so the touches meant for them reach them.
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            guard axis == .vertical else { return super.point(inside: point, with: event) }
            return subviews.contains { $0.frame.contains(point) }
        }
    }
#endif
