#if canImport(UIKit)
    import BNUI
    import UIKit

    extension BNTabBarDemoView {
        /// The effects the knob offers, by name.
        static let selectionEffects: [(name: String, effect: any BNTabBarSymbolEffect)] = [
            ("Bounce", .bounce),
            ("Pulse", .pulse),
            ("Wiggle", .wiggle),
            ("Breathe", .breathe),
            ("Draw on", .drawOn),
            ("Off", .none),
        ]

        /// The last section's icon by the knob's index: its symbol, an 80 pt glyph that has to
        /// fit the box instead of growing the bar, a photo kept in its own colours, or its symbol
        /// passed as an image — the way an app's own symbol comes.
        static func lastIcon(_ index: Int, symbol: String) -> BNTabBarItem.Icon {
            switch index {
            case 1: .image(oversizedGlyph)
            case 2: .image(photo, rendering: .original)
            // An app's own symbol arrives as an image from its catalogue; a system one stands in.
            case 3: UIImage(systemName: symbol).map { .image($0) } ?? .symbol(symbol)
            default: .symbol(symbol)
            }
        }

        /// A star far larger than a tab icon, drawn as a template.
        private static let oversizedGlyph = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { _ in
            let star = UIBezierPath()
            for point in 0 ..< 10 {
                let radius: CGFloat = point.isMultiple(of: 2) ? 40 : 16
                let angle = CGFloat(point) * .pi / 5 - .pi / 2
                let vertex = CGPoint(x: 40 + radius * cos(angle), y: 40 + radius * sin(angle))
                if point == 0 {
                    star.move(to: vertex)
                } else {
                    star.addLine(to: vertex)
                }
            }
            star.close()
            UIColor.black.setFill()
            star.fill()
        }

        /// A square stand-in for a person's photo: a gradient behind initials, in colours no tint
        /// would give.
        private static let photo = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            let colors = [UIColor.systemOrange.cgColor, UIColor.systemPink.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 120, y: 120), options: [])
            }
            let text = NSAttributedString(string: "AB", attributes: [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.white,
            ])
            let size = text.size()
            text.draw(at: CGPoint(x: (120 - size.width) / 2, y: (120 - size.height) / 2))
        }
    }
#endif
