#if canImport(UIKit)
    import BNUICore
    import os
    import UIKit

    extension BNButton {
        static let logger = Logger(subsystem: "BNUI", category: "BNButton")

        // MARK: - Hierarchy

        /// ```
        /// BNButton (UIControl)                ← pressRecognizer; hit area ≥ 44 pt
        /// └── surface.view                    ← the material; the press compression lives here
        ///     └── surface.contentContainer
        ///         ├── borderView?             (isUserInteractionEnabled = false)
        ///         └── contentView             (isUserInteractionEnabled = false)
        /// ```
        ///
        /// The content takes no touches, so a finger lands on the material — on glass, inside it,
        /// where the system draws its response — or, in the margin the hit area adds, on the button
        /// itself. The press recognizer sits on the button, above both, and hears either.
        func buildHierarchy() {
            for view in subviews {
                view.removeFromSuperview()
            }
            borderView = nil
            contentView = nil
            contentPins = nil
            indicatorView = nil
            rejectionOverlay = nil
            rejectionAnimation?.interrupt()
            rejectionAnimation = nil
            surface = nil

            let surface = resolvedMaterial.makeSurface(style: activeStyle, size: size, theme: activeTheme)
            self.surface = surface
            surface.view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(surface.view)
            NSLayoutConstraint.activate([
                surface.view.topAnchor.constraint(equalTo: topAnchor),
                surface.view.bottomAnchor.constraint(equalTo: bottomAnchor),
                surface.view.leadingAnchor.constraint(equalTo: leadingAnchor),
                surface.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])

            let container = surface.contentContainer

            let renderer = contentRenderer ?? BNStandardButtonContentRenderer()
            let content = renderer.makeContentView(for: content, theme: activeTheme, size: size)
            contentView = content
            content.isUserInteractionEnabled = false
            content.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(content)
            activateContentConstraints(for: content, in: container)

            indicatorView = makeIndicatorView(in: container)
            rejectionOverlay = makeRejectionOverlay(in: container)

            if activeStyle.border != nil {
                borderView = makeBorderView(in: container)
            }
        }

        /// The spinner is built once and kept, whatever the status.
        ///
        /// It never takes part in sizing: it is pinned to the centre with a fixed side, and the
        /// content it replaces stays in the hierarchy at zero alpha. That is what keeps the width
        /// from jolting on the way into `loading` — the thing that decides the width never moved.
        private func makeIndicatorView(in container: UIView) -> any BNButtonLoadingIndicating {
            let view = loadingIndicator.makeIndicator()
            view.isUserInteractionEnabled = false
            view.alpha = 0
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                view.widthAnchor.constraint(equalToConstant: size.indicatorSide),
                view.heightAnchor.constraint(equalToConstant: size.indicatorSide),
            ])
            return view
        }

        private func activateContentConstraints(for content: UIView, in container: UIView) {
            // Leading and trailing anchors rather than left and right: right-to-left mirrors this
            // for free, and the control never sets `semanticContentAttribute`.
            let alignedEdge: NSLayoutConstraint? = switch configuration.alignment {
            case .center: nil
            case .leading: content.leadingAnchor.constraint(equalTo: container.leadingAnchor)
            case .trailing: content.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            }
            let pins = BNButtonContentPins(
                top: content.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
                leading: content.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
                bottom: content.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
                trailing: content.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
                alignedEdge: alignedEdge,
                alignment: configuration.alignment,
            )
            // Solved now rather than at the first layout pass: pins left at the text paddings would
            // squeeze a lone icon into a dozen points, and Auto Layout would break a constraint to
            // get out of it.
            pins.apply(solveLayout(availableWidth: bounds.width).contentInsets)
            contentPins = pins

            NSLayoutConstraint.activate([content.centerYAnchor.constraint(equalTo: container.centerYAnchor)] + pins.all)
            if configuration.alignment == .center {
                content.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
            }
        }

        /// The colour a refused touch flashes.
        ///
        /// Sits above the fill and below the content, so the button glows rather than the title
        /// turning red — and it works over glass, where there is no fill to recolour at all.
        private func makeRejectionOverlay(in container: UIView) -> UIView {
            let view = UIView()
            view.isUserInteractionEnabled = false
            view.backgroundColor = activeTheme.rejectionColor
            view.alpha = 0
            view.bnApplyShape(size.shape, maximumRadius: size.maximumCornerRadius)
            view.translatesAutoresizingMaskIntoConstraints = false
            container.insertSubview(view, at: 0)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            return view
        }

        /// A separate overlay rather than a border on the material's own layer: a glass effect view
        /// is not ours to draw on, and a stroke on its layer would sit under the refraction.
        private func makeBorderView(in container: UIView) -> UIView {
            let view = UIView()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
            view.bnApplyShape(size.shape, maximumRadius: size.maximumCornerRadius)
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            return view
        }

        // MARK: - Applying state to the layers

        func applyPressedScale(_ pressed: Bool, transition: BNTransition) {
            guard let surface else { return }
            guard resolvedMaterial.pressResponse == .control else {
                // The material compresses itself, so the control keeps its own scale out of the
                // way. It still owns the haptics, the loading mode and the speed reward.
                surface.view.transform = .identity
                return
            }

            let target = pressed ? activeTheme.geometry.pressedScale : 1
            let transform = CGAffineTransform(scaleX: target, y: target)
            // Interrupting leaves the view on its current frame, so a new touch takes the movement
            // over mid-flight instead of teleporting it back to the start.
            scaleAnimation?.interrupt()
            scaleAnimation = nil

            guard transition.isAnimated else {
                surface.view.transform = transform
                return
            }
            let view = surface.view
            scaleAnimation = transition.run { view.transform = transform }
        }

        func applyLoading(transition: BNTransition) {
            guard let indicatorView, let contentView else { return }
            let loading = status == .loading

            indicatorView.apply(
                color: activeStyle.indicatorColor ?? activeStyle.title.color(for: status, isPressed: false),
                side: size.indicatorSide,
            )
            indicatorView.setAnimating(loading)

            guard contentView.alpha != (loading ? 0 : 1) else { return }
            // Alpha only: the content stays in the hierarchy so it keeps deciding the width. A
            // spinner swapped in for the label would resize the button the moment work started.
            transition.run {
                contentView.alpha = loading ? 0 : 1
                indicatorView.alpha = loading ? 1 : 0
            }
        }

        func applyBorder(transition _: BNTransition) {
            guard let borderView, let border = activeStyle.border else { return }
            borderView.layer.borderWidth = border.width
            // Set directly: a CALayer colour does not take part in a UIView animation anyway, and
            // pretending otherwise would only hide that from whoever reads this next.
            borderView.layer.borderColor = border.color.resolvedColor(with: traitCollection).cgColor
        }

        // MARK: - Layout

        var solvedIntrinsicSize: CGSize {
            let output = solvedOutput ?? solveLayout(availableWidth: bounds.width)
            let width: CGFloat = switch configuration.width {
            // The host stretches a full-width button; reporting a width would fight its constraints.
            case .fill: UIView.noIntrinsicMetric
            case .hug, .fixed: output.buttonWidth
            }
            return CGSize(width: width, height: output.buttonHeight)
        }

        /// Re-solves after a layout pass and reacts only to what actually changed — re-applying an
        /// unchanged axis on every pass would restart the colour transition mid-press.
        func refreshSolvedLayout() {
            let output = solveLayout(availableWidth: bounds.width)
            guard output != solvedOutput else { return }

            let previous = solvedOutput
            solvedOutput = output
            if previous?.contentInsets != output.contentInsets {
                contentPins?.apply(output.contentInsets)
            }
            let contentChanged = previous?.axis != output.axis
                || previous?.numberOfLines != output.numberOfLines
                || previous?.iconScale != output.iconScale
            if contentChanged {
                contentView?.apply(state: contentState, transition: .immediate)
            }
            if output.iconScale < 1, previous?.iconScale != output.iconScale {
                reportShrunkIcon(scale: output.iconScale)
            }
            if previous?.buttonWidth != output.buttonWidth || previous?.buttonHeight != output.buttonHeight {
                invalidateIntrinsicContentSize()
            }
        }

        /// A shrunk glyph is a working button with a thinner stroke than its neighbours — worth a
        /// line in the console, not a failed assertion.
        private func reportShrunkIcon(scale: CGFloat) {
            let label = content.resolvedAccessibilityLabel ?? ""
            let sizeID = size.id
            Self.logger.debug("""
            BNButton “\(label, privacy: .public)”: the icon is shrunk to \(Double(scale), format: .fixed(precision: 2)) \
            to fit the “\(sizeID, privacy: .public)” circle. A larger size or a narrower symbol keeps its stroke.
            """)
        }

        func solveLayout(availableWidth: CGFloat) -> BNButtonLayoutSolver.Output {
            // What is left for content once the padding has taken its share. Unbounded until the
            // host has given the button a width, which is when a wrapping title still measures as
            // one line — correctly, because there is nothing to wrap against yet.
            let fittingWidth = availableWidth > 0
                ? max(availableWidth - 2 * size.horizontalPadding, 1)
                : .greatestFiniteMagnitude
            let measurement = contentView?.measure(fittingWidth: fittingWidth) ?? BNButtonContentMeasurement()
            var solverSize = size
            if !configuration.reservesSpaceForLoading {
                // The host accepted the jolt; the floor that guarantees room for the spinner goes.
                solverSize.indicatorSide = 0
            }

            return BNButtonLayoutSolver.solve(BNButtonLayoutSolver.Input(
                availableWidth: availableWidth,
                titleWidth: measurement.titleSize.width,
                titleHeight: measurement.titleSize.height,
                titleLineHeight: measurement.titleLineHeight,
                iconWidths: measurement.iconSizes.map(\.width),
                iconHeight: measurement.iconHeight,
                size: solverSize,
                metrics: activeTheme.geometry,
                width: configuration.width,
                titleBehavior: configuration.titleBehavior,
                isAccessibilitySize: traitCollection.preferredContentSizeCategory.isAccessibilityCategory,
                allowsVerticalStack: configuration.stacksVerticallyAtAccessibilitySizes,
            ))
        }

        func invalidateSolvedLayout() {
            solvedOutput = nil
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }

        // MARK: - Focus

        /// The ring hugs the *visual* bounds, not the touch area: a halo the size of the 44 pt hit
        /// rect would draw a ring in empty space around a small icon button.
        func updateFocusEffect() {
            let padding = activeTheme.geometry.focusHaloPadding
            let radius = size.shape.cornerRadius(forHeight: bounds.height, maximumRadius: size.maximumCornerRadius)

            guard activeTheme.focus.usesSystemHalo else {
                focusEffect = nil
                updateFocusRing(radius: radius, padding: padding)
                return
            }
            focusRing?.removeFromSuperlayer()
            focusRing = nil
            focusEffect = UIFocusHaloEffect(
                roundedRect: bounds.insetBy(dx: -padding, dy: -padding),
                cornerRadius: radius + padding,
                curve: .continuous,
            )
        }

        /// The theme's own ring, for a design that does not want the system halo.
        private func updateFocusRing(radius: CGFloat, padding: CGFloat) {
            guard isFocused else {
                focusRing?.removeFromSuperlayer()
                focusRing = nil
                return
            }

            let ring = focusRing ?? {
                let created = CAShapeLayer()
                created.fillColor = UIColor.clear.cgColor
                layer.addSublayer(created)
                focusRing = created
                return created
            }()
            ring.frame = bounds
            ring.lineWidth = activeTheme.focus.ringWidth
            ring.strokeColor = activeTheme.focus.ringColor.resolvedColor(with: traitCollection).cgColor
            ring.path = UIBezierPath(
                roundedRect: bounds.insetBy(dx: -padding, dy: -padding),
                cornerRadius: radius + padding,
            ).cgPath
        }

        // MARK: - Debug

        func updateHitOverlay() {
            guard showsHitTargetOutline else {
                hitOverlay?.removeFromSuperlayer()
                hitOverlay = nil
                return
            }

            let shape = hitOverlay ?? {
                let created = CAShapeLayer()
                created.fillColor = UIColor.clear.cgColor
                created.strokeColor = UIColor.systemRed.withAlphaComponent(0.9).cgColor
                created.lineDashPattern = [4, 3]
                created.lineWidth = 1
                layer.addSublayer(created)
                hitOverlay = created
                return created
            }()
            shape.frame = bounds
            shape.path = UIBezierPath(rect: hitRect).cgPath
        }
    }
#endif
