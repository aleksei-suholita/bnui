#if canImport(UIKit)
    import BNUI
    import UIKit

    /// The settings the stage is shown under — the ones a checklist asks about and Settings.app
    /// would otherwise have to be opened for: appearance, text size, layout direction — and the
    /// stage's tools: a phone's width, slowed animation, a frame meter, view outlines.
    ///
    /// Applied to the stage alone, traits as overrides. The inspector keeps the app's own traits
    /// and speed, so the panel stays readable and quick while the demo is judged at an
    /// accessibility size, in RTL or at a tenth of its speed.
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

        /// The stage's width, for a layout judged on a phone narrower than the one at hand.
        enum Width: CaseIterable {
            case device, points320, points375, points430

            var title: String {
                switch self {
                case .device: "Device"
                case .points320: "320 pt"
                case .points375: "375 pt"
                case .points430: "430 pt"
                }
            }

            /// The phone the width belongs to, as the menu's subtitle.
            var phone: String? {
                switch self {
                case .device: nil
                case .points320: "iPhone SE (1st generation)"
                case .points375: "iPhone SE, mini"
                case .points430: "Pro Max, Plus"
                }
            }

            var points: CGFloat? {
                switch self {
                case .device: nil
                case .points320: 320
                case .points375: 375
                case .points430: 430
                }
            }
        }

        /// Core Animation's speed on the stage — a spring watched phase by phase.
        enum Speed: CaseIterable {
            case normal, half, quarter, tenth

            var title: String {
                switch self {
                case .normal: "Normal"
                case .half: "×0.5"
                case .quarter: "×0.25"
                case .tenth: "×0.1"
                }
            }

            var factor: Float {
                switch self {
                case .normal: 1
                case .half: 0.5
                case .quarter: 0.25
                case .tenth: 0.1
                }
            }
        }

        var appearance = Appearance.system
        var textSize = TextSize.system
        var direction = Direction.system
        var width = Width.device
        var speed = Speed.normal
        var showsFrameRate = false
        var showsOutlines = false

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
            // A phone's width is a compact one, on an iPad stage too.
            if width.points != nil {
                traits.horizontalSizeClass = .compact
            } else {
                traits.remove(UITraitHorizontalSizeClass.self)
            }
        }
    }
#endif
