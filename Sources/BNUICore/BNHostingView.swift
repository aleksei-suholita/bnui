#if canImport(UIKit)
    import SwiftUI
    import UIKit

    /// A SwiftUI view in a slot that takes a `UIView`.
    ///
    /// The kit's slots are UIKit — a toast's custom body and icon, a button's custom content, the
    /// tab bar's accessory — and this is the one adapter for all of them, rather than a SwiftUI
    /// overload per slot:
    ///
    /// ```swift
    /// let content = BNToastContent(text: "Synced", customView: { BNHostingView(SyncBadge()) })
    /// ```
    ///
    /// The view sizes itself by what the SwiftUI content asks for, through Auto Layout, which is
    /// how every slot in the kit measures what it is given. Safe areas are switched off: a slot
    /// sits inside a control, and a toast near the top of the screen must not pad its body for a
    /// notch the toast itself already clears.
    ///
    /// The hosting controller is kept alive by the view but is not a child of any view controller —
    /// a slot has no controller to adopt it. Content is for showing: presenting a sheet from inside
    /// a slot is not supported.
    public final class BNHostingView<Content: View>: UIView {
        private let controller: UIHostingController<Content>

        /// Swapping the content re-renders in place — the slot keeps its view, so the control
        /// holding it does not rebuild.
        public var rootView: Content {
            get { controller.rootView }
            set { controller.rootView = newValue }
        }

        public init(_ rootView: Content) {
            controller = UIHostingController(rootView: rootView)
            super.init(frame: .zero)
            controller.sizingOptions = [.intrinsicContentSize]
            // iOS 16.0–16.3 has no switch, and a slot there may pad for a safe area it overlaps.
            if #available(iOS 16.4, *) {
                controller.safeAreaRegions = []
            }
            backgroundColor = .clear

            let hosted: UIView = controller.view
            hosted.backgroundColor = .clear
            hosted.translatesAutoresizingMaskIntoConstraints = false
            addSubview(hosted)
            NSLayoutConstraint.activate([
                hosted.topAnchor.constraint(equalTo: topAnchor),
                hosted.bottomAnchor.constraint(equalTo: bottomAnchor),
                hosted.leadingAnchor.constraint(equalTo: leadingAnchor),
                hosted.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        nonisolated deinit {}

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }
    }
#endif
