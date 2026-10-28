#if canImport(UIKit)
    import UIKit

    extension GalleryEnvironment {
        /// The stage menu, rebuilt after every pick so its checkmarks tell the truth. The backdrop
        /// belongs to the page, the rest to the session, so they report back separately; a page
        /// that is itself a background passes no backdrop and gets no backdrop section.
        func menu(
            backdrop: BNGalleryBackdrop?,
            among backdrops: [BNGalleryBackdrop],
            onBackdrop: @escaping (BNGalleryBackdrop) -> Void,
            onChange: @escaping (GalleryEnvironment) -> Void,
        ) -> UIMenu {
            let backdropMenu = backdrop.map { current in
                // Each backdrop with the question it answers, so the choice is made by purpose.
                UIMenu(
                    title: "Backdrop",
                    subtitle: current.title,
                    image: UIImage(systemName: "photo.on.rectangle"),
                    options: .singleSelection,
                    children: backdrops.map { option in
                        UIAction(title: option.title, subtitle: option.purpose, state: option == current ? .on : .off) { _ in
                            onBackdrop(option)
                        }
                    },
                )
            }
            let reset = UIAction(
                title: "Reset Environment",
                image: UIImage(systemName: "arrow.counterclockwise"),
                attributes: isDefault ? .disabled : [],
            ) { _ in
                onChange(GalleryEnvironment())
            }
            return UIMenu(
                title: "Stage",
                children: [backdropMenu].compactMap(\.self) + traitSections(onChange: onChange)
                    + toolSections(onChange: onChange)
                    + [UIMenu(options: .displayInline, children: [reset])],
            )
        }

        /// Text size, direction and the accessibility switches are trait overrides, which arrive with
        /// iOS 17; iOS 16 can override only the appearance.
        private func traitSections(onChange: @escaping (GalleryEnvironment) -> Void) -> [UIMenu] {
            let appearance = section(
                (title: "Appearance", image: "circle.lefthalf.filled"), \.appearance, name: \.title, onChange: onChange,
            )
            guard #available(iOS 17.0, *) else { return [appearance] }
            return [
                appearance,
                section((title: "Text Size", image: "textformat.size"), \.textSize, name: \.title, onChange: onChange),
                section(
                    (title: "Layout Direction", image: "arrow.left.arrow.right"), \.direction, name: \.title, onChange: onChange,
                ),
                accessibility(onChange: onChange),
            ]
        }

        /// What Settings → Accessibility would switch on, for the kit's controls on the stage. The
        /// closed menu names what is on.
        private func accessibility(onChange: @escaping (GalleryEnvironment) -> Void) -> UIMenu {
            let on = [(reducesMotion, "Reduce Motion"), (reducesTransparency, "Reduce Transparency")]
                .filter(\.0).map(\.1)
            return UIMenu(
                title: "Accessibility",
                subtitle: on.isEmpty ? "System" : on.joined(separator: ", "),
                image: UIImage(systemName: "accessibility"),
                children: [
                    toggle(
                        (title: "Reduce Motion", image: "figure.walk.motion"), "The kit's controls move as Settings asks",
                        \.reducesMotion, onChange: onChange,
                    ),
                    toggle(
                        (title: "Reduce Transparency", image: "drop.halffull"), "The kit's materials go solid",
                        \.reducesTransparency, onChange: onChange,
                    ),
                ],
            )
        }

        private func toolSections(onChange: @escaping (GalleryEnvironment) -> Void) -> [UIMenu] {
            [
                section(
                    (title: "Width", image: "arrow.left.and.right"), \.width, name: \.title, subtitle: \.phone, onChange: onChange,
                ),
                section((title: "Animation Speed", image: "tortoise"), \.speed, name: \.title, onChange: onChange),
                // What the stage can draw over the demo, each on or off.
                UIMenu(options: .displayInline, children: [
                    toggle(
                        (title: "Frame Rate", image: "speedometer"), "Frames per second and hitches",
                        \.showsFrameRate, onChange: onChange,
                    ),
                    toggle(
                        (title: "View Outlines", image: "square.dashed"), "A frame around every view of the demo",
                        \.showsOutlines, onChange: onChange,
                    ),
                ]),
            ]
        }

        /// A submenu that shows the current pick as its subtitle, so the closed menu already says
        /// what the stage is set to.
        private func section<Option: Equatable & CaseIterable>(
            _ heading: (title: String, image: String),
            _ setting: WritableKeyPath<GalleryEnvironment, Option>,
            name: (Option) -> String,
            subtitle: (Option) -> String? = { _ in nil },
            onChange: @escaping (GalleryEnvironment) -> Void,
        ) -> UIMenu {
            let selected = self[keyPath: setting]
            return UIMenu(
                title: heading.title,
                subtitle: name(selected),
                image: UIImage(systemName: heading.image),
                options: .singleSelection,
                children: Option.allCases.map { option in
                    UIAction(title: name(option), subtitle: subtitle(option), state: option == selected ? .on : .off) { _ in
                        var copy = self
                        copy[keyPath: setting] = option
                        onChange(copy)
                    }
                },
            )
        }

        private func toggle(
            _ heading: (title: String, image: String),
            _ subtitle: String,
            _ setting: WritableKeyPath<GalleryEnvironment, Bool>,
            onChange: @escaping (GalleryEnvironment) -> Void,
        ) -> UIAction {
            UIAction(
                title: heading.title,
                subtitle: subtitle,
                image: UIImage(systemName: heading.image),
                state: self[keyPath: setting] ? .on : .off,
            ) { _ in
                var copy = self
                copy[keyPath: setting].toggle()
                onChange(copy)
            }
        }
    }
#endif
