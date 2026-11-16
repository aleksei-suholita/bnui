#if canImport(UIKit)
    import BNUICore
    import SwiftUI
    import UIKit

    extension BNButton {
        // MARK: - Blur

        /// Carries the old content into the new one through a blur, as the system's bars do: the
        /// old content blurs away while the new one comes into focus.
        ///
        /// UIKit has no public way to blur a view's own pixels, so both contents are pictured at
        /// rest and SwiftUI blurs the pictures, over the real content, until the blur has ended;
        /// then the new content is shown again. Its own picture at rest is its own pixels, so the
        /// hand-back shows no seam. Centred content only: a picture is centred over it.
        ///
        /// Called once the new size is already under way: the pictures are taken from the views as
        /// they will stand, and the box holding them is moved from `startCentre`, the middle of
        /// the outline the change began in, along with the outline.
        ///
        /// - Returns: `false` when it cannot be drawn; the change then fades through instead.
        func blurThrough(
            from outgoing: UIView?,
            to incoming: UIView,
            timing: BNButtonContentTiming,
            startCentre: CGPoint,
        ) -> Bool {
            guard configuration.alignment == .center, let container = surface?.contentContainer else { return false }
            let tuning = activeContentTuning
            let reduced = reducesMotion
            var pictures: (old: UIImage?, new: UIImage)?
            UIView.performWithoutAnimation {
                pictures = (outgoing.map { $0.pictureAtRest() }, incoming.pictureAtRest())
                incoming.alpha = 0
            }
            guard let pictures else { return false }
            if let outgoing {
                finishLeaving(outgoing)
            }

            let spring = contentSpring(for: timing)
            let radius = reduced ? 0 : tuning.blurRadius
            let leaving = BNCurve(duration: spring.duration * tuning.outgoingShare, timing: Self.leavingTiming)
            let overlay = BNHostingView(BNButtonBlurReplaceView(
                old: pictures.old,
                new: pictures.new,
                radius: radius,
                scale: reduced ? 1 : tuning.incomingScale,
                leaving: leaving.animation,
                arrival: spring.animation.delay(spring.duration * tuning.incomingDelayShare),
            ))
            // A box of fixed size, centred like the content and kept centred while the outline
            // changes under it, with room for the blur to spread. SwiftUI lays it out once.
            let padding = radius * 2
            let oldSize = pictures.old?.size ?? .zero
            overlay.isUserInteractionEnabled = false
            overlay.translatesAutoresizingMaskIntoConstraints = true
            overlay.bounds = CGRect(
                x: 0,
                y: 0,
                width: max(oldSize.width, pictures.new.size.width) + 2 * padding,
                height: max(oldSize.height, pictures.new.size.height) + 2 * padding,
            )
            overlay.center = startCentre
            container.insertSubview(overlay, aboveSubview: incoming)
            blurOverlay = overlay
            follow(overlay, to: contentCentre, timing: timing)

            let handBack = spring.duration * (1 + tuning.incomingDelayShare) * Self.settlingFactor
            Task { [weak self, weak overlay, weak incoming] in
                // Cancelled only when the button has gone, and with it the overlay.
                do { try await Task.sleep(for: .seconds(handBack)) } catch { return }
                guard let self, let overlay, blurOverlay === overlay else { return }
                // A button that went busy meanwhile keeps its content behind the spinner.
                incoming?.alpha = status == .loading ? 0 : 1
                removeBlurOverlay()
            }
            return true
        }

        /// Moves the box along with the outline: on the spring the new size is laid out under, or
        /// straight into the host's animation. From there it keeps its place by its margins.
        func follow(_ overlay: UIView, to centre: CGPoint, timing: BNButtonContentTiming) {
            let keepsPlace: () -> Void = {
                overlay.center = centre
                overlay.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
            }
            guard case .own = timing, animatesSizeChanges, overlay.center != centre else {
                keepsPlace()
                return
            }
            BNTransition.spring(sizeSpring).run(keepsPlace)
        }

        func removeBlurOverlay() {
            blurOverlay?.removeFromSuperview()
            blurOverlay = nil
        }

        /// Fades out whatever is still drawn over the content — a blur, a roll — with the content
        /// itself, when work starts and the spinner takes its place.
        func fadeOutContentOverlays(transition: BNTransition) {
            let overlays = [blurOverlay, contentDrawing?.view].compactMap(\.self)
            blurOverlay = nil
            contentDrawing = nil
            for overlay in overlays {
                transition.run {
                    overlay.alpha = 0
                } completion: { _ in
                    overlay.removeFromSuperview()
                }
            }
        }

        // MARK: - Clipping

        /// Clips the content to the outline for `duration`: new content wider than the outline
        /// would otherwise stand out of it until the outline caught up, and a sliding title would
        /// pass outside it.
        ///
        /// The content's container is clipped, not the surface: the surface may cast a shadow of
        /// its own, as the blur plate does, and clipping it would cut the shadow off. Lifted once
        /// the latest change has settled.
        func clipWhileTransitioning(for duration: TimeInterval) {
            guard let surface else { return }
            let container = surface.contentContainer
            if container !== surface.view {
                container.layer.cornerRadius = size.shape.cornerRadius(
                    forHeight: container.bounds.height,
                    maximumRadius: size.maximumCornerRadius,
                )
                container.layer.cornerCurve = .continuous
            }
            container.clipsToBounds = true
            contentClipGeneration += 1
            let generation = contentClipGeneration
            Task { [weak self, weak container] in
                do { try await Task.sleep(for: .seconds(duration)) } catch { return }
                guard let self, contentClipGeneration == generation else { return }
                container?.clipsToBounds = false
            }
        }

        /// How long a change takes to settle, the longer of the content and the outline, with
        /// room for a spring's tail.
        func settlingTime(of timing: BNButtonContentTiming) -> TimeInterval {
            let tuning = activeContentTuning
            return switch timing {
            case .immediate: 0
            case let .inherited(duration): duration * Self.settlingFactor
            case .own: max(tuning.content.duration * (1 + tuning.incomingDelayShare), tuning.size.duration) * Self.settlingFactor
            }
        }

        /// A spring given a duration is still moving, slightly, at its end.
        static let settlingFactor = 1.4
    }

    extension UIView {
        /// The view's pixels as they stand at rest — opaque, untransformed — wherever its own fade
        /// had got to: what the drawn styles draw, so that handing back to the view shows no seam.
        func pictureAtRest() -> UIImage {
            let restingAlpha = alpha
            let restingTransform = transform
            alpha = 1
            transform = .identity
            defer {
                alpha = restingAlpha
                transform = restingTransform
            }
            let format = UIGraphicsImageRendererFormat(for: traitCollection)
            return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
                layer.render(in: context.cgContext)
            }
        }
    }

    /// The blur between two contents, drawn by SwiftUI: its blur is the one public way on iOS to
    /// blur pixels a view draws. The old picture blurs away and shrinks a little; the new one comes
    /// into focus as it grows to full size.
    struct BNButtonBlurReplaceView: View {
        let old: UIImage?
        let new: UIImage
        let radius: CGFloat
        let scale: CGFloat
        let leaving: Animation
        let arrival: Animation

        @State private var oldIsGone = false
        @State private var newIsIn = false

        var body: some View {
            ZStack {
                if let old {
                    // A picture of what the button already says: the button speaks for itself.
                    Image(uiImage: old)
                        .accessibilityHidden(true)
                        .blur(radius: oldIsGone ? radius : 0)
                        .scaleEffect(oldIsGone ? scale : 1)
                        .opacity(oldIsGone ? 0 : 1)
                }
                Image(uiImage: new)
                    .accessibilityHidden(true)
                    .blur(radius: newIsIn ? 0 : radius)
                    .scaleEffect(newIsIn ? 1 : scale)
                    .opacity(newIsIn ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(leaving) { oldIsGone = true }
                withAnimation(arrival) { newIsIn = true }
            }
        }
    }
#endif
