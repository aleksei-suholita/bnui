#if canImport(UIKit)
    import UIKit

    extension BNButton {
        /// Whether a touch landing now opens the menu rather than pressing the button.
        var opensMenuOnTouch: Bool {
            menu != nil && showsMenuAsPrimaryAction && status.allowsInteraction
        }

        /// The menu for UIKit to show, or none: a button that takes no tap opens no menu either,
        /// and its refusal plays instead.
        func menuConfiguration() -> UIContextMenuConfiguration? {
            guard let menu, status.allowsInteraction else { return nil }
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in menu }
        }

        /// A menu on screen has the finger: the press that opened it — a long one — ends without
        /// firing, as a touch the system took does. Turning the recognizer off and on again is
        /// how a gesture under way is cancelled.
        func endPressForMenu() {
            guard pressRecognizer.state == .began || pressRecognizer.state == .changed else { return }
            pressRecognizer.isEnabled = false
            pressRecognizer.isEnabled = true
        }
    }
#endif
