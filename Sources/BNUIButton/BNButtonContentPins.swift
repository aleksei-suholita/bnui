#if canImport(UIKit)
    import UIKit

    /// The constraints that hold the content inside the button's edges.
    ///
    /// Kept rather than rebuilt: the insets are the solver's answer — text paddings, or one inset
    /// all round a lone icon — and that answer can change on a layout pass without a new view tree.
    struct BNButtonContentPins {
        let top: NSLayoutConstraint
        let leading: NSLayoutConstraint
        let bottom: NSLayoutConstraint
        let trailing: NSLayoutConstraint
        /// The edge the content is aligned to. `nil` when it is centred.
        let alignedEdge: NSLayoutConstraint?
        let alignment: BNButtonAlignment

        var all: [NSLayoutConstraint] {
            [top, leading, bottom, trailing] + (alignedEdge.map { [$0] } ?? [])
        }

        /// Lets go of the sides, or holds them again. Let go while new content waits for a wider
        /// frame the host gives later: held to the old width, a longer title is laid out — and
        /// pictured by a blur or a roll — cut short. Its own width and the centre hold it meanwhile.
        func holdSides(_ holds: Bool) {
            leading.isActive = holds
            trailing.isActive = holds
        }

        func apply(_ insets: BNButtonInsets) {
            top.constant = insets.top
            leading.constant = insets.leading
            bottom.constant = -insets.bottom
            trailing.constant = -insets.trailing
            switch alignment {
            case .center: break
            case .leading: alignedEdge?.constant = insets.leading
            case .trailing: alignedEdge?.constant = -insets.trailing
            }
        }
    }
#endif
