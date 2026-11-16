#if canImport(UIKit)
    import BNUICore
    import UIKit

    extension BNButton {
        // MARK: - Drawn styles

        /// Draws the change in a style drawn over the content — roll, blur — when it can be drawn
        /// so. A roll that cannot — to or from a lone icon, two lines, a custom renderer — blurs
        /// instead.
        ///
        /// - Returns: `false` when neither can; the change then fades through.
        func drawsChange(
            from outgoing: UIView?,
            to incoming: UIView,
            timing: BNButtonContentTiming,
            startCentre: CGPoint,
        ) -> Bool {
            let style = contentTransition
            if style == .roll, rollText(from: outgoing, to: incoming, timing: timing, startCentre: startCentre) {
                return true
            }
            if contentDrawing != nil {
                // A roll still under way, and this change cannot be drawn so: the content under it
                // is shown as it is, and leaves from there.
                outgoing?.alpha = 1
                removeContentDrawing()
            }
            return [.blur, .roll].contains(style)
                && blurThrough(from: outgoing, to: incoming, timing: timing, startCentre: startCentre)
        }

        /// Shows the content again once the latest change the roll turned to has settled.
        func handBack(_ roll: BNButtonRoll, after delay: TimeInterval) {
            roll.generation += 1
            let generation = roll.generation
            Task { [weak self, weak roll] in
                // Cancelled only when the button has gone, and with it the roll.
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, let roll, contentDrawing === roll, roll.generation == generation else { return }
                // A button that went busy meanwhile keeps its content behind the spinner.
                contentView?.alpha = status == .loading ? 0 : 1
                removeContentDrawing()
            }
        }

        func removeContentDrawing() {
            contentDrawing?.view.removeFromSuperview()
            contentDrawing = nil
        }
    }
#endif
