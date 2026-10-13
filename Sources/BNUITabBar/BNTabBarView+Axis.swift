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
        /// The bar's view is larger than what it draws: a row spans the screen beside its capsule,
        /// a column runs the length of its strip, where the system's own buttons go. It takes a
        /// touch only where one of its pieces would — the capsule, the action with the margin of
        /// its touch target, the accessory — so the touches meant for what is under the empty
        /// rest reach it.
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            subviews.contains { piece in
                !piece.isHidden && piece.alpha > 0.01 && piece.isUserInteractionEnabled
                    && piece.point(inside: convert(point, to: piece), with: event)
            }
        }
    }
#endif
