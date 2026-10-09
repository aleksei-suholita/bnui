import Foundation

/// A section's badge: a count, a short text, or a dot.
///
/// Typed rather than a string, the way the system's bar button badge is from iOS 26: a count is
/// formatted by the bar — capped, in the user's digits — and a dot is a badge of its own rather
/// than an empty string that may or may not draw. Pure, so the rules are testable without UIKit.
///
/// What VoiceOver says is the host's to word: the kit knows no app and no language. Without a
/// label a count or a text is read as shown; a dot has nothing to show and needs one.
public nonisolated enum BNTabBarBadge: Equatable, Sendable {
    /// A number. Zero or less shows no badge; past the theme's limit it reads "99+".
    case count(Int, accessibilityLabel: String? = nil)
    /// A short word or sign — "New", "!". An empty text shows no badge.
    case text(String, accessibilityLabel: String? = nil)
    /// A dot without text, for "something is new here".
    case dot(accessibilityLabel: String)

    /// What a badge draws.
    public enum Appearance: Equatable, Sendable {
        case dot
        case text(String)
    }

    /// What the badge draws, or `nil` when there is nothing to draw.
    ///
    /// - Parameters:
    ///   - countLimit: the largest count shown as is; a larger one shows the limit and a plus.
    ///   - locale: whose digits a count is written in.
    public func appearance(countLimit: Int, locale: Locale = .current) -> Appearance? {
        switch self {
        case let .count(count, _):
            guard count > 0 else { return nil }
            let shown = min(count, countLimit).formatted(.number.locale(locale))
            return .text(count > countLimit ? "\(shown)+" : shown)
        case let .text(text, _):
            return text.isEmpty ? nil : .text(text)
        case .dot:
            return .dot
        }
    }

    /// What VoiceOver says for the badge: the host's label, or else what it shows. `nil` when the
    /// badge draws nothing.
    public func spokenText(countLimit: Int, locale: Locale = .current) -> String? {
        guard let appearance = appearance(countLimit: countLimit, locale: locale) else { return nil }
        switch (self, appearance) {
        case let (.count(_, label?), _), let (.text(_, label?), _), let (.dot(label), _):
            return label
        case let (_, .text(shown)):
            return shown
        case (_, .dot):
            return nil
        }
    }

    /// The badge as a menu item's subtitle, for a section behind More: a system menu draws no
    /// badge of its own. What it shows, or a dot's label, since a menu cannot draw a dot.
    func menuText(countLimit: Int, locale: Locale = .current) -> String? {
        switch appearance(countLimit: countLimit, locale: locale) {
        case let .text(shown)?: shown
        case .dot?: spokenText(countLimit: countLimit, locale: locale)
        case nil: nil
        }
    }
}
