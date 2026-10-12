#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// The default content view: an icon, a title, an icon — any of them optional.
    ///
    /// Deliberately not interactive: every touch belongs to the button, and a label that swallowed
    /// one would produce a press the control never hears about.
    final class BNButtonContentView: UIView, BNButtonContentRendering {
        private let content: BNButtonContent
        private var theme: BNButtonTheme
        private var size: BNButtonSize

        private let stack = UIStackView()
        private let titleLabel = UILabel()
        private var iconViews: [BNButtonIconView] = []

        init(content: BNButtonContent, theme: BNButtonTheme, size: BNButtonSize) {
            self.content = content
            self.theme = theme
            self.size = size
            super.init(frame: .zero)
            build()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        // MARK: - Building

        private func build() {
            isUserInteractionEnabled = false
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = size.iconSpacing
            stack.isUserInteractionEnabled = false
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])

            // Natural alignment, never `.left`: right-to-left layouts mirror this for free, and a
            // hard-coded side is the classic way to break them.
            titleLabel.textAlignment = .natural
            titleLabel.adjustsFontForContentSizeCategory = true
            titleLabel.font = theme.typography.font(for: size)
            titleLabel.text = content.title
            titleLabel.isUserInteractionEnabled = false

            if let leading = content.leadingIcon {
                stack.addArrangedSubview(makeIconView(for: leading))
            }
            if content.hasTitle {
                stack.addArrangedSubview(titleLabel)
            }
            if let trailing = content.trailingIcon {
                stack.addArrangedSubview(makeIconView(for: trailing))
            }
        }

        private func makeIconView(for icon: BNButtonIcon) -> BNButtonIconView {
            let view = BNButtonIconView(image: image(for: icon))
            view.keepsOwnColours = icon.rendering == .original
            view.contentMode = .scaleAspectFit
            view.isUserInteractionEnabled = false
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
            iconViews.append(view)
            return view
        }

        private func image(for icon: BNButtonIcon) -> UIImage? {
            let configuration = UIImage.SymbolConfiguration(
                pointSize: size.iconPointSize,
                weight: theme.icon.weight,
                scale: theme.icon.scale,
            )
            switch icon {
            case let .symbol(name):
                return UIImage(systemName: name, withConfiguration: configuration)
            case let .image(image, flipsForRTL, rendering):
                // A symbol from the host's asset catalog takes the same configuration as a system
                // one, so it stands at the same size and weight beside them. A bitmap has none to take.
                let configured = image.isSymbolImage
                    ? image.applyingSymbolConfiguration(configuration) ?? image
                    : image
                let base = flipsForRTL ? configured.imageFlippedForRightToLeftLayoutDirection() : configured
                return base.withRenderingMode(rendering == .original ? .alwaysOriginal : .alwaysTemplate)
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // A multi-line label needs to be told what width to wrap at; without this it reports an
            // intrinsic height for a single line and the button comes out too short.
            let width = titleLabel.bounds.width
            if titleLabel.numberOfLines != 1, titleLabel.preferredMaxLayoutWidth != width {
                titleLabel.preferredMaxLayoutWidth = width
                setNeedsUpdateConstraints()
            }
        }

        // MARK: - BNButtonContentRendering

        func apply(state: BNButtonContentState, transition: BNTransition) {
            theme = state.theme
            size = state.size

            let titleColor = state.style.title.color(for: state.status, isPressed: state.isPressed)
            let iconColor = state.style.resolvedIcon.color(for: state.status, isPressed: state.isPressed)
            let pictureAlpha = state.status == .disabled ? BNCustomContentView.disabledAlpha : 1
            let axis: NSLayoutConstraint.Axis = state.axis == .vertical ? .vertical : .horizontal

            titleLabel.font = state.theme.typography.font(for: state.size)
            titleLabel.numberOfLines = state.numberOfLines
            titleLabel.lineBreakMode = state.numberOfLines == 1 ? .byTruncatingTail : .byWordWrapping
            titleLabel.textAlignment = textAlignment(for: state)
            stack.spacing = state.size.iconSpacing
            stack.axis = axis
            stack.alignment = .center
            for view in iconViews {
                view.scale = state.iconScale
            }

            // Colour rides the transition; layout does not. A press changes the colour, and the
            // caller decides whether that is a frame of a gesture or a settled state.
            transition.run { [titleLabel, iconViews] in
                titleLabel.textColor = titleColor
                for view in iconViews {
                    // A picture keeps its own colours, so the state reaches it as dimming alone, the
                    // way it reaches a view the host brings.
                    if view.keepsOwnColours {
                        view.alpha = pictureAlpha
                    } else {
                        view.tintColor = iconColor
                    }
                }
            }
        }

        private func textAlignment(for state: BNButtonContentState) -> NSTextAlignment {
            // Only meaningful once the title wraps; a single centred line looks the same either way.
            switch state.alignment {
            case .leading: .natural
            case .center: state.axis == .vertical ? .center : .natural
            case .trailing: .natural
            }
        }

        func measure(fittingWidth: CGFloat) -> BNButtonContentMeasurement {
            // Measured from the text itself rather than through `systemLayoutSizeFitting`: the
            // button's width comes back from the solver as a constraint, and asking the view what
            // it fits would echo that constraint straight back.
            let iconSizes = iconViews.compactMap(\.image?.size)
            guard content.hasTitle, let text = content.title else {
                return BNButtonContentMeasurement(titleSize: .zero, iconSizes: iconSizes)
            }

            let font = titleLabel.font ?? theme.typography.font(for: size)
            let titleSize = measureTitle(text, font: font, fittingWidth: fittingWidth, beside: iconSizes)
            return BNButtonContentMeasurement(
                titleSize: CGSize(width: ceil(titleSize.width), height: ceil(titleSize.height)),
                titleLineHeight: ceil(font.lineHeight),
                iconSizes: iconSizes,
            )
        }

        private func measureTitle(
            _ text: String,
            font: UIFont,
            fittingWidth: CGFloat,
            beside icons: [CGSize],
        ) -> CGSize {
            let singleLine = (text as NSString).size(withAttributes: [.font: font])
            let lines = titleLabel.numberOfLines
            guard lines != 1, fittingWidth > 0, fittingWidth.isFinite else { return singleLine }

            // Wrapping only makes sense against a real width. The icons beside the title take their
            // room first, or the label would be measured wider than it will ever be drawn.
            let taken = icons.reduce(0) { $0 + $1.width + size.iconSpacing }
            let limit = max(fittingWidth - taken, 1)
            guard singleLine.width > limit else { return singleLine }

            let bounding = (text as NSString).boundingRect(
                with: CGSize(width: limit, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil,
            )
            guard lines > 0 else { return bounding.size }
            // A capped line count cannot grow past its cap — past that the label truncates.
            let capped = min(bounding.height, singleLine.height * CGFloat(lines))
            return CGSize(width: bounding.width, height: capped)
        }
    }

    /// An icon that can be shrunk to the room the solver found for it.
    ///
    /// Shrunk through the intrinsic size rather than a transform: a transform leaves Auto Layout
    /// holding the full-size glyph, which is exactly what did not fit. The image follows the
    /// frame through `scaleAspectFit`.
    final class BNButtonIconView: UIImageView {
        /// Drawn in the image's own colours rather than tinted by the state.
        var keepsOwnColours = false

        var scale: CGFloat = 1 {
            didSet {
                guard scale != oldValue else { return }
                invalidateIntrinsicContentSize()
            }
        }

        override var intrinsicContentSize: CGSize {
            let natural = super.intrinsicContentSize
            guard scale < 1, natural.width > 0, natural.height > 0 else { return natural }
            return CGSize(width: natural.width * scale, height: natural.height * scale)
        }
    }

    /// The view behind ``BNCustomViewContentRenderer``: a frame around whatever the host supplied.
    final class BNCustomContentView: UIView, BNButtonContentRendering {
        private let wrapped: UIView

        init(wrapping view: UIView) {
            wrapped = view
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            wrapped.isUserInteractionEnabled = false
            wrapped.translatesAutoresizingMaskIntoConstraints = false
            addSubview(wrapped)
            NSLayoutConstraint.activate([
                wrapped.topAnchor.constraint(equalTo: topAnchor),
                wrapped.bottomAnchor.constraint(equalTo: bottomAnchor),
                wrapped.leadingAnchor.constraint(equalTo: leadingAnchor),
                wrapped.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        /// How far a disabled button dims what keeps its own colours — this view, a picture icon.
        static let disabledAlpha: CGFloat = 0.35

        func apply(state: BNButtonContentState, transition: BNTransition) {
            let alpha: CGFloat = state.status == .disabled ? Self.disabledAlpha : 1
            guard wrapped.alpha != alpha else { return }
            transition.run { [wrapped] in wrapped.alpha = alpha }
        }

        func measure(fittingWidth _: CGFloat) -> BNButtonContentMeasurement {
            // Reported as an icon rather than a title: it has no lines to wrap, and it must never
            // be the thing the solver tries to stack at accessibility sizes.
            let size = wrapped.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            return BNButtonContentMeasurement(titleSize: .zero, iconSizes: [size])
        }
    }
#endif
