#if canImport(UIKit)
    import UIKit

    public extension BNButton {
        /// Whether the button is busy: its content gave way to the spinner and taps are swallowed.
        var isLoading: Bool {
            status == .loading
        }

        /// Moves the button to `status`, riding the theme's state-change curve or, with `animated`
        /// off, at once — a button that appears already loading does not animate into it.
        ///
        /// - Parameters:
        ///   - status: the state the host has decided on.
        ///   - animated: whether the change is shown as a transition.
        func setStatus(_ status: BNButtonStatus, animated: Bool) {
            guard status != self.status else { return }
            pendingStatusTransition = animated ? nil : .immediate
            self.status = status
            pendingStatusTransition = nil
        }

        /// Keeps the UIKit flag in step with the status it bridges to.
        internal func syncEnabledFlag() {
            let shouldBeEnabled = status != .disabled
            if isEnabled != shouldBeEnabled {
                isEnabled = shouldBeEnabled
            }
        }
    }
#endif
