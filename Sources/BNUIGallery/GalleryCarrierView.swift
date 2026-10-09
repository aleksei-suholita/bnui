#if (DEBUG || GalleryInRelease) && canImport(UIKit)
    import UIKit

    /// A view the gallery builds around a demo, carrying what the page's knobs drive — the props of
    /// a presented controller or a SwiftUI view, or every demo of a states page.
    protocol GallerySubjectCarrying: AnyObject {
        var gallerySubjects: [AnyObject] { get }
    }

    /// A view the gallery builds around a demo, with state of its own for Reset to clear.
    protocol GalleryDemoResetting: AnyObject {
        func resetForGallery()
    }

    /// The root view of a controller the gallery builds around a demo — a Present button, a SwiftUI
    /// host, a column of states. It is what the page sees as the demo view: it carries the knobs'
    /// subjects, passes events on to the stage's feed and hears Reset.
    final class GalleryCarrierView: UIView, GallerySubjectCarrying, GalleryDemoResetting, BNGalleryEventReporting {
        let gallerySubjects: [AnyObject]
        var onGalleryEvent: ((String) -> Void)?
        var onReset: (() -> Void)?

        init(subjects: [AnyObject]) {
            gallerySubjects = subjects
            super.init(frame: .zero)
        }

        // periphery:ignore - UIKit requires the initializer; `unavailable` keeps anyone from calling it
        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func resetForGallery() {
            onReset?()
        }

        /// Holds `content` edge to edge, so the carrier is exactly as big as what it carries.
        func embed(_ content: UIView) {
            content.translatesAutoresizingMaskIntoConstraints = false
            addSubview(content)
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: topAnchor),
                content.bottomAnchor.constraint(equalTo: bottomAnchor),
                content.leadingAnchor.constraint(equalTo: leadingAnchor),
                content.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
    }
#endif
