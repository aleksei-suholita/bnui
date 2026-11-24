#if canImport(UIKit)
    import BNUICore
    import UIKit

    /// What the row did when it took new icons in place.
    struct BNButtonIconChange {
        /// Icons new to the row: laid out where they will stand, to be shown.
        var arrived: [BNButtonIconView] = []
        /// Icons gone from the row: out of its layout, still where they stood, to be taken away.
        var left: [BNButtonIconView] = []
    }

    extension BNButtonContentView {
        // MARK: - Icons in place

        /// The row's views in their order: the icons and the title.
        var rowViews: [UIView] {
            stack.arrangedSubviews
        }

        /// Takes `newContent` without being made again when its title is the one shown: each slot
        /// keeps its icon, replaces it where it stands, gains one or loses one. A symbol gives way
        /// to a symbol by the system's replace effect — from iOS 18 the one that morphs a symbol
        /// into its relative, `bell` into `bell.slash` — and anything else, or anything under
        /// Reduce Motion, cross-fades for `duration`. An icon gained or lost is only put into the
        /// row or taken out of it: the button shows it coming and going.
        ///
        /// - Parameters:
        ///   - newContent: The content to take.
        ///   - duration: How long a cross-fade takes.
        ///   - symbolDuration: How long the replace effect takes; `nil` keeps the system's speed.
        /// - Returns: `nil` when the title changed; the button then replaces the whole view.
        func takeIconsInPlace(
            from newContent: BNButtonContent,
            duration: TimeInterval,
            symbolDuration: TimeInterval?,
        ) -> BNButtonIconChange? {
            guard newContent.title == content.title else { return nil }
            var change = BNButtonIconChange()
            let timing = (crossFade: duration, symbol: symbolDuration)
            let leading = takeSlot(leading: true, to: newContent.leadingIcon, change: &change, timing: timing)
            let trailing = takeSlot(leading: false, to: newContent.trailingIcon, change: &change, timing: timing)
            iconViews = [leading, trailing].compactMap(\.self)
            icons = [newContent.leadingIcon, newContent.trailingIcon].compactMap(\.self)
            content = newContent
            return change
        }

        /// One slot's icon after the change: kept, replaced, put in or taken out. Read before
        /// `content` moves on: the slot's view is found by the content it was made for.
        private func takeSlot(
            leading: Bool,
            to new: BNButtonIcon?,
            change: inout BNButtonIconChange,
            timing: (crossFade: TimeInterval, symbol: TimeInterval?),
        ) -> BNButtonIconView? {
            let old = leading ? content.leadingIcon : content.trailingIcon
            let view = old == nil ? nil : (leading ? iconViews.first : iconViews.last)
            switch (view, new) {
            case let (view?, new?):
                if new != old {
                    view.keepsOwnColours = new.rendering == .original
                    if let image = image(for: new) {
                        replaceImage(in: view, with: image, timing: timing)
                    } else {
                        view.image = nil
                    }
                }
                return view
            case let (view?, nil):
                stack.removeArrangedSubview(view)
                change.left.append(view)
                return nil
            case let (nil, new?):
                let view = makeIconView(for: new)
                stack.insertArrangedSubview(view, at: leading ? 0 : stack.arrangedSubviews.count)
                change.arrived.append(view)
                return view
            case (nil, nil):
                return nil
            }
        }

        private func replaceImage(
            in view: UIImageView,
            with image: UIImage,
            timing: (crossFade: TimeInterval, symbol: TimeInterval?),
        ) {
            let morphs = !bnReducesMotion && image.isSymbolImage && view.image?.isSymbolImage == true
            if #available(iOS 17.0, *), morphs {
                if #available(iOS 18.0, *) {
                    view.setSymbolImage(
                        image,
                        contentTransition: .replace.magic(fallback: .replace),
                        options: symbolOptions(natural: BNSymbolReplaceTiming.magicReplace, duration: timing.symbol),
                    )
                } else {
                    view.setSymbolImage(
                        image,
                        contentTransition: .replace,
                        options: symbolOptions(natural: BNSymbolReplaceTiming.replace, duration: timing.symbol),
                    )
                }
                return
            }
            UIView.transition(
                with: view,
                duration: timing.crossFade,
                options: [.transitionCrossDissolve, .allowUserInteraction],
            ) {
                view.image = image
            }
        }

        /// The replace effect at the system's speed, or at the one that makes it take `duration`.
        @available(iOS 17.0, *)
        private func symbolOptions(natural: TimeInterval, duration: TimeInterval?) -> SymbolEffectOptions {
            guard let duration else { return .default }
            return .speed(BNSymbolReplaceTiming.speed(toTake: duration, natural: natural))
        }

        // MARK: - Roll

        /// The content as one row SwiftUI can draw again, for the roll style: what it
        /// says, in the font, colours and sizes it stands in now. `nil` when it is not one row on
        /// one line — a stacked or wrapped title — and the change then blurs instead.
        func rollRow() -> BNButtonRollRow? {
            let font = titleLabel.font ?? theme.typography.font(for: size)
            let oneLine = !content.hasTitle || titleLabel.bounds.height <= ceil(font.lineHeight) + 1
            guard stack.axis == .horizontal, oneLine else { return nil }
            let drawn = zip(iconViews, icons).map { view, icon in view.rollIcon(showing: icon) }
            var row = BNButtonRollRow(
                title: content.hasTitle ? content.title : nil,
                titleWidth: titleLabel.bounds.width,
                font: font,
                titleColour: (titleLabel.textColor ?? .label).resolvedColor(with: traitCollection),
                spacing: stack.spacing,
                size: bounds.size,
            )
            if content.leadingIcon != nil, let first = drawn.first {
                row.leading = first
            }
            if content.trailingIcon != nil, let last = drawn.last {
                row.trailing = last
            }
            return row
        }
    }
#endif
