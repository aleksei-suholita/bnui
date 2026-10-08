#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// An app's content, drawn: a featured photo card, grouped lists of rows with icons, a shared
    /// album strip, repeated to fill the stage. Drawn in system colours, so it is light or dark
    /// with the stage's appearance.
    ///
    /// This is what a bar or a toast floats over most of the time, so it is where their material
    /// is judged for everyday use. The content starts just under where a navigation bar ends and
    /// runs on under it, so the page's own bar has something to be glass over too.
    enum GalleryInterfacePainter {
        private struct Row {
            let symbol: String
            let tint: UIColor
            let title: String
            let detail: String
            let trailing: String
        }

        private struct Feature {
            let title: String
            let detail: String
            let photo: Int
        }

        private static let rows: [Row] = [
            Row(symbol: "calendar", tint: .systemRed, title: "Design review", detail: "Tomorrow, 10:00", trailing: "Now"),
            Row(symbol: "envelope.fill", tint: .systemBlue, title: "Invoice #1042", detail: "Payment received", trailing: "9:41"),
            Row(symbol: "airplane", tint: .systemOrange, title: "Flight to Berlin", detail: "Gate B12 · boarding 18:20", trailing: "Fri"),
            Row(symbol: "book.fill", tint: .systemIndigo, title: "Reading notes", detail: "Chapter 7 highlights", trailing: "Thu"),
            Row(symbol: "cart.fill", tint: .systemGreen, title: "Groceries", detail: "12 items left", trailing: "Wed"),
            Row(symbol: "music.note", tint: .systemPink, title: "Road trip mix", detail: "48 songs · 3 h 12 min", trailing: "Tue"),
            Row(symbol: "figure.run", tint: .systemTeal, title: "Morning run", detail: "5.2 km · 28 min", trailing: "Mon"),
            Row(symbol: "gift.fill", tint: .systemPurple, title: "Birthday ideas", detail: "Updated 2 days ago", trailing: "Sun"),
        ]

        private static let features: [Feature] = [
            Feature(title: "Weekend in Lisbon", detail: "128 photos · 3 videos", photo: 0),
            Feature(title: "Autumn walks", detail: "96 photos", photo: 9),
            Feature(title: "Northern coast", detail: "42 photos", photo: 1),
        ]

        private static let sectionTitles = ["Today", "Shared albums", "Earlier"]

        private static let margin: CGFloat = 16
        private static let rowHeight: CGFloat = 64
        private static let blockGap: CGFloat = 28
        /// Where the first card starts: just under a navigation bar with a status bar above it.
        private static let firstCardTop: CGFloat = 108

        static func draw(in bounds: CGRect, context: CGContext) {
            UIColor.systemGroupedBackground.setFill()
            context.fill(bounds)
            var y = bounds.minY + firstCardTop
            var block = 0
            while y < bounds.maxY {
                let round = block / 3
                switch block % 3 {
                case 0:
                    y = drawFeature(features[round % features.count], top: y, bounds: bounds, context: context)
                case 1:
                    let title = sectionTitles[(round * 2) % sectionTitles.count]
                    y = drawList(title: title, first: round * 4, top: y, bounds: bounds, context: context)
                default:
                    y = drawAlbums(title: sectionTitles[1], first: round * 3 + 2, top: y, bounds: bounds, context: context)
                }
                y += blockGap
                block += 1
            }
        }

        // MARK: - Blocks

        /// A wide photo card with a darkened foot and its title on it — the colourful thing near
        /// the top of most apps' first screens.
        private static func drawFeature(_ feature: Feature, top: CGFloat, bounds: CGRect, context: CGContext) -> CGFloat {
            let card = CGRect(x: bounds.minX + margin, y: top, width: bounds.width - margin * 2, height: 196)
            context.saveGState()
            context.addPath(UIBezierPath(roundedRect: card, cornerRadius: BNGalleryMetrics.cardRadius).cgPath)
            context.clip()
            GalleryImageryPainter.drawPhoto(feature.photo, in: card, context: context)
            // A scrim under the caption, the way a photo card keeps white text readable.
            GalleryPaint.linear(
                context,
                colors: [UIColor.black.withAlphaComponent(0), UIColor.black.withAlphaComponent(0.55)],
                from: CGPoint(x: card.midX, y: card.maxY - 96),
                to: CGPoint(x: card.midX, y: card.maxY),
            )
            context.restoreGState()
            text(feature.title, font: .systemFont(ofSize: 22, weight: .bold), color: .white)
                .draw(at: CGPoint(x: card.minX + 18, y: card.maxY - 62))
            text(feature.detail, font: .systemFont(ofSize: 15, weight: .medium), color: .white.withAlphaComponent(0.85))
                .draw(at: CGPoint(x: card.minX + 18, y: card.maxY - 32))
            return card.maxY
        }

        /// A section heading and a grouped card of four rows: icon, title, detail, a time.
        private static func drawList(title: String, first: Int, top: CGFloat, bounds: CGRect, context: CGContext) -> CGFloat {
            let cardTop = drawHeading(title, top: top, bounds: bounds)
            let card = CGRect(x: bounds.minX + margin, y: cardTop, width: bounds.width - margin * 2, height: rowHeight * 4)
            UIColor.secondarySystemGroupedBackground.setFill()
            UIBezierPath(roundedRect: card, cornerRadius: BNGalleryMetrics.cardRadius).fill()
            for offset in 0 ..< 4 {
                let row = rows[(first + offset) % rows.count]
                let frame = CGRect(x: card.minX, y: card.minY + CGFloat(offset) * rowHeight, width: card.width, height: rowHeight)
                drawRow(row, in: frame)
                if offset < 3 {
                    UIColor.separator.setFill()
                    context.fill(CGRect(x: frame.minX + 64, y: frame.maxY - 0.5, width: frame.width - 64, height: 0.5))
                }
            }
            return card.maxY
        }

        private static func drawRow(_ row: Row, in frame: CGRect) {
            let icon = CGRect(x: frame.minX + 16, y: frame.midY - 18, width: 36, height: 36)
            row.tint.setFill()
            UIBezierPath(roundedRect: icon, cornerRadius: 10).fill()
            let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            let glyph = UIImage(systemName: row.symbol, withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            glyph?.draw(at: CGPoint(x: icon.midX - (glyph?.size.width ?? 0) / 2, y: icon.midY - (glyph?.size.height ?? 0) / 2))
            let textX = frame.minX + 64
            let trailing = text(row.trailing, font: .systemFont(ofSize: 15), color: .secondaryLabel)
            let trailingSize = trailing.size()
            trailing.draw(at: CGPoint(x: frame.maxX - 16 - trailingSize.width, y: frame.minY + 13))
            let textWidth = frame.maxX - 16 - trailingSize.width - 12 - textX
            text(row.title, font: .systemFont(ofSize: 17, weight: .regular), color: .label)
                .draw(in: CGRect(x: textX, y: frame.minY + 11, width: textWidth, height: 22))
            text(row.detail, font: .systemFont(ofSize: 15), color: .secondaryLabel)
                .draw(in: CGRect(x: textX, y: frame.minY + 34, width: frame.maxX - 16 - textX, height: 20))
        }

        /// A heading and a strip of three square photos in a card — colour and hard edges in the
        /// middle of an otherwise calm screen.
        private static func drawAlbums(title: String, first: Int, top: CGFloat, bounds: CGRect, context: CGContext) -> CGFloat {
            let cardTop = drawHeading(title, top: top, bounds: bounds)
            let inset: CGFloat = 12
            let spacing: CGFloat = 8
            let width = bounds.width - margin * 2
            let side = ((width - inset * 2 - spacing * 2) / 3).rounded(.down)
            let card = CGRect(x: bounds.minX + margin, y: cardTop, width: width, height: side + inset * 2)
            UIColor.secondarySystemGroupedBackground.setFill()
            UIBezierPath(roundedRect: card, cornerRadius: BNGalleryMetrics.cardRadius).fill()
            for column in 0 ..< 3 {
                let x = card.minX + inset + CGFloat(column) * (side + spacing)
                let tile = CGRect(x: x, y: card.minY + inset, width: side, height: side)
                context.saveGState()
                context.addPath(UIBezierPath(roundedRect: tile, cornerRadius: 12).cgPath)
                context.clip()
                GalleryImageryPainter.drawPhoto(first + column, in: tile, context: context)
                context.restoreGState()
            }
            return card.maxY
        }

        /// A section heading above a card; returns where the card starts.
        private static func drawHeading(_ title: String, top: CGFloat, bounds: CGRect) -> CGFloat {
            text(title, font: .systemFont(ofSize: 20, weight: .bold), color: .label)
                .draw(at: CGPoint(x: bounds.minX + margin + 4, y: top))
            return top + 34
        }

        private static func text(_ string: String, font: UIFont, color: UIColor) -> NSAttributedString {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            return NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        }
    }
#endif
