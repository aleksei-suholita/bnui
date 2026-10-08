#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// The settings the stage is shown under — the ones a checklist asks about and Settings.app
    /// would otherwise have to be opened for: appearance, text size, layout direction.
    ///
    /// Applied as trait overrides to the stage alone. The inspector keeps the app's own traits, so
    /// the panel stays readable while the demo is judged at an accessibility size or in RTL.
    struct GalleryEnvironment: Equatable {
        enum Appearance: CaseIterable {
            case system, light, dark

            var title: String {
                switch self {
                case .system: "System"
                case .light: "Light"
                case .dark: "Dark"
                }
            }

            var style: UIUserInterfaceStyle? {
                switch self {
                case .system: nil
                case .light: .light
                case .dark: .dark
                }
            }
        }

        enum TextSize: CaseIterable {
            case system, small, large, extraExtraExtraLarge, accessibilityMedium, accessibilityExtraExtraExtraLarge

            var title: String {
                switch self {
                case .system: "System"
                case .small: "Small"
                case .large: "Large (default)"
                case .extraExtraExtraLarge: "XXXL"
                case .accessibilityMedium: "Accessibility M"
                case .accessibilityExtraExtraExtraLarge: "Accessibility XXXL"
                }
            }

            var category: UIContentSizeCategory? {
                switch self {
                case .system: nil
                case .small: .small
                case .large: .large
                case .extraExtraExtraLarge: .extraExtraExtraLarge
                case .accessibilityMedium: .accessibilityMedium
                case .accessibilityExtraExtraExtraLarge: .accessibilityExtraExtraExtraLarge
                }
            }
        }

        enum Direction: CaseIterable {
            case system, leftToRight, rightToLeft

            var title: String {
                switch self {
                case .system: "System"
                case .leftToRight: "Left to right"
                case .rightToLeft: "Right to left"
                }
            }

            var layoutDirection: UITraitEnvironmentLayoutDirection? {
                switch self {
                case .system: nil
                case .leftToRight: .leftToRight
                case .rightToLeft: .rightToLeft
                }
            }
        }

        var appearance = Appearance.system
        var textSize = TextSize.system
        var direction = Direction.system

        /// Kept for the session: moving between pages does not throw away a dark, RTL stage the
        /// tester just set up.
        static var current = GalleryEnvironment()

        var isDefault: Bool {
            self == GalleryEnvironment()
        }

        @available(iOS 17.0, *)
        func apply(to traits: inout UITraitOverrides) {
            if let style = appearance.style {
                traits.userInterfaceStyle = style
            } else {
                traits.remove(UITraitUserInterfaceStyle.self)
            }
            if let category = textSize.category {
                traits.preferredContentSizeCategory = category
            } else {
                traits.remove(UITraitPreferredContentSizeCategory.self)
            }
            if let layoutDirection = direction.layoutDirection {
                traits.layoutDirection = layoutDirection
            } else {
                traits.remove(UITraitLayoutDirection.self)
            }
        }

        /// The stage menu, rebuilt after every pick so its checkmarks tell the truth. The backdrop
        /// belongs to the page, the rest to the session, so they report back separately; a page
        /// that is itself a background passes no backdrop and gets no backdrop section.
        func menu(
            backdrop: GalleryBackdrop?,
            onBackdrop: @escaping (GalleryBackdrop) -> Void,
            onChange: @escaping (GalleryEnvironment) -> Void,
        ) -> UIMenu {
            let backdropMenu = backdrop.map { current in
                // Each backdrop with the question it answers, so the choice is made by purpose.
                UIMenu(
                    title: "Backdrop",
                    subtitle: current.title,
                    image: UIImage(systemName: "photo.on.rectangle"),
                    options: .singleSelection,
                    children: GalleryBackdrop.allCases.map { option in
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
                children: [backdropMenu].compactMap(\.self) + environmentSections(onChange: onChange)
                    + [UIMenu(options: .displayInline, children: [reset])],
            )
        }

        private func environmentSections(onChange: @escaping (GalleryEnvironment) -> Void) -> [UIMenu] {
            let sections = [
                Self.section(
                    (title: "Appearance", image: "circle.lefthalf.filled"),
                    options: Appearance.allCases,
                    selected: appearance,
                    name: \.title,
                ) { choice in
                    var copy = self
                    copy.appearance = choice
                    onChange(copy)
                },
                Self.section(
                    (title: "Text Size", image: "textformat.size"),
                    options: TextSize.allCases,
                    selected: textSize,
                    name: \.title,
                ) { choice in
                    var copy = self
                    copy.textSize = choice
                    onChange(copy)
                },
                Self.section(
                    (title: "Layout Direction", image: "arrow.left.arrow.right"),
                    options: Direction.allCases,
                    selected: direction,
                    name: \.title,
                ) { choice in
                    var copy = self
                    copy.direction = choice
                    onChange(copy)
                },
            ]
            // Text size and direction are trait overrides, which arrive with iOS 17; iOS 16 can
            // override only the appearance.
            guard #available(iOS 17.0, *) else { return Array(sections.prefix(1)) }
            return sections
        }

        /// A submenu that shows the current pick as its subtitle, so the closed menu already says
        /// what the stage is set to.
        private static func section<Option: Equatable>(
            _ heading: (title: String, image: String),
            options: [Option],
            selected: Option,
            name: (Option) -> String,
            pick: @escaping (Option) -> Void,
        ) -> UIMenu {
            UIMenu(
                title: heading.title,
                subtitle: name(selected),
                image: UIImage(systemName: heading.image),
                options: .singleSelection,
                children: options.map { option in
                    UIAction(title: name(option), state: option == selected ? .on : .off) { _ in
                        pick(option)
                    }
                },
            )
        }
    }
#endif
