#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// The picture backdrops: a photo library, a bright sky, a night. Fixed colours — a photo does
    /// not change with the system appearance, and neither should the thing standing in for one.
    enum GalleryImageryPainter {
        /// The colours of one generated photo: a sky, the ground below the horizon, a light source.
        struct Palette {
            let skyTop: UInt32
            let skyBottom: UInt32
            let ground: UInt32
            let light: UInt32
        }

        /// A soft colour bloom placed in shares of the backdrop's size.
        struct Bloom {
            let x: CGFloat
            let y: CGFloat
            let radius: CGFloat
            let color: UInt32
            let alpha: CGFloat
        }

        static let palettes: [Palette] = [
            Palette(skyTop: 0xFF7E5F, skyBottom: 0xFEB47B, ground: 0x6B2F2F, light: 0xFFE29A), // sunset
            Palette(skyTop: 0x2E8BC0, skyBottom: 0xB1D4E0, ground: 0x0C2D48, light: 0xFFFFFF), // sea
            Palette(skyTop: 0xA8C686, skyBottom: 0xDCE8B8, ground: 0x2F4A1E, light: 0xFFF4C2), // meadow
            Palette(skyTop: 0x3A1C71, skyBottom: 0xD76D77, ground: 0x1B1030, light: 0xFFAF7B), // dusk
            Palette(skyTop: 0xE6B980, skyBottom: 0xEACDA3, ground: 0x8C5A2B, light: 0xFFF6D8), // desert
            Palette(skyTop: 0xCFDEF3, skyBottom: 0xF5F7FA, ground: 0x8FA3BF, light: 0xFFFFFF), // snow
            Palette(skyTop: 0x0F2027, skyBottom: 0x2C5364, ground: 0x05080A, light: 0xFFB347), // city night
            Palette(skyTop: 0xF8CDDA, skyBottom: 0xFDF0F5, ground: 0xB4637E, light: 0xFFFFFF), // blossom
            Palette(skyTop: 0x43C6AC, skyBottom: 0xF8FFAE, ground: 0x1D5E55, light: 0xFFFFFF), // lagoon
            Palette(skyTop: 0xF12711, skyBottom: 0xF5AF19, ground: 0x4A1A06, light: 0xFFE8A3), // autumn
        ]

        // MARK: - Photos

        /// A library grid the way Photos draws one: square tiles, hairline gaps, no margins. Busy
        /// colour and a hard edge every few points — refraction and label contrast get tested at
        /// once, and a bar over it is judged over the kind of thing it floats over in a media app.
        static func drawLibrary(in bounds: CGRect, context: CGContext) {
            GalleryPaint.color(0x0B0B0D).setFill()
            context.fill(bounds)
            let columns: CGFloat = bounds.width > 600 ? 5 : bounds.width > 430 ? 4 : 3
            let gap: CGFloat = 2
            let side = ((bounds.width - gap * (columns - 1)) / columns).rounded(.down)
            var index = 0
            var y = bounds.minY
            while y < bounds.maxY {
                for column in 0 ..< Int(columns) {
                    let x = bounds.minX + CGFloat(column) * (side + gap)
                    drawPhoto(index, in: CGRect(x: x, y: y, width: side, height: side), context: context)
                    index += 1
                }
                y += side + gap
            }
        }

        /// One generated "photo": a sky, a horizon with ground below it, and a sun or a glow. The
        /// layout varies per index, so neighbouring tiles never repeat.
        static func drawPhoto(_ index: Int, in rect: CGRect, context: CGContext) {
            var random = GallerySeededRandom(seed: index)
            let palette = palettes[(index * 7 + 3) % palettes.count]
            context.saveGState()
            context.clip(to: rect)
            GalleryPaint.linear(
                context,
                colors: [GalleryPaint.color(palette.skyTop), GalleryPaint.color(palette.skyBottom)],
                from: CGPoint(x: rect.midX, y: rect.minY),
                to: CGPoint(x: rect.midX, y: rect.maxY),
            )
            let sun = CGPoint(
                x: rect.minX + rect.width * random.next(in: 0.2 ... 0.8),
                y: rect.minY + rect.height * random.next(in: 0.2 ... 0.5),
            )
            let bloom = rect.width * random.next(in: 0.3 ... 0.6)
            GalleryPaint.glow(context, at: sun, radius: bloom, color: GalleryPaint.color(palette.light), alpha: 0.85)
            GalleryPaint.glow(context, at: sun, radius: rect.width * 0.07, color: .white, alpha: 0.9)

            let horizon = rect.minY + rect.height * random.next(in: 0.58 ... 0.8)
            let ground = CGRect(x: rect.minX, y: horizon, width: rect.width, height: rect.maxY - horizon)
            context.saveGState()
            context.clip(to: ground)
            GalleryPaint.linear(
                context,
                colors: [GalleryPaint.color(palette.ground, alpha: 0.75), GalleryPaint.color(palette.ground)],
                from: CGPoint(x: rect.midX, y: horizon),
                to: CGPoint(x: rect.midX, y: rect.maxY),
            )
            context.restoreGState()
            context.restoreGState()
        }

        // MARK: - Bright

        /// A pale sky: white at the top, a soft blue below, faint peach and lemon blooms and a white
        /// hotspot. Glass over it turns light and asks for dark text; white text on it disappears —
        /// the complaint about iOS 26 glass, made reproducible.
        static func drawBright(in bounds: CGRect, context: CGContext) {
            GalleryPaint.linear(
                context,
                colors: [GalleryPaint.color(0xFFFFFF), GalleryPaint.color(0xE6F1FF)],
                from: CGPoint(x: bounds.midX, y: bounds.minY),
                to: CGPoint(x: bounds.midX, y: bounds.maxY),
            )
            let blooms = [
                Bloom(x: 0.12, y: 0.18, radius: 0.75, color: 0xFFE3D3, alpha: 0.9),
                Bloom(x: 0.9, y: 0.34, radius: 0.7, color: 0xFFF3BF, alpha: 0.85),
                Bloom(x: 0.55, y: 0.62, radius: 0.8, color: 0xDDEBFF, alpha: 0.9),
                Bloom(x: 0.2, y: 0.86, radius: 0.65, color: 0xFFEFF6, alpha: 0.8),
                Bloom(x: 0.62, y: 0.22, radius: 0.45, color: 0xFFFFFF, alpha: 1),
            ]
            draw(blooms, in: bounds, context: context)
        }

        private static func draw(_ blooms: [Bloom], in bounds: CGRect, context: CGContext) {
            for bloom in blooms {
                GalleryPaint.glow(
                    context,
                    at: CGPoint(x: bounds.minX + bounds.width * bloom.x, y: bounds.minY + bounds.height * bloom.y),
                    radius: bounds.width * bloom.radius,
                    color: GalleryPaint.color(bloom.color),
                    alpha: bloom.alpha,
                )
            }
        }

        // MARK: - Night

        /// Deep blue going to navy, violet and teal glows, and a scatter of stars — dark media with
        /// just enough detail that glass over it has something to refract.
        static func drawNight(in bounds: CGRect, context: CGContext) {
            GalleryPaint.linear(
                context,
                colors: [GalleryPaint.color(0x03050C), GalleryPaint.color(0x0B1633)],
                from: CGPoint(x: bounds.midX, y: bounds.minY),
                to: CGPoint(x: bounds.midX, y: bounds.maxY),
            )
            let width = bounds.width
            let glows = [
                Bloom(x: 0.18, y: 0.22, radius: 0.7, color: 0x4B2A8C, alpha: 0.7),
                Bloom(x: 0.9, y: 0.55, radius: 0.75, color: 0x0F5C73, alpha: 0.6),
                Bloom(x: 0.45, y: 0.95, radius: 0.8, color: 0x6A1F4A, alpha: 0.55),
            ]
            draw(glows, in: bounds, context: context)
            var random = GallerySeededRandom(seed: 42)
            let stars = Int(bounds.width * bounds.height / 2600)
            for _ in 0 ..< stars {
                let size = random.next(in: 0.6 ... 1.8)
                let point = CGPoint(
                    x: bounds.minX + random.next(in: 0 ... 1) * width,
                    y: bounds.minY + random.next(in: 0 ... 1) * bounds.height,
                )
                UIColor.white.withAlphaComponent(random.next(in: 0.25 ... 0.9)).setFill()
                context.fillEllipse(in: CGRect(x: point.x, y: point.y, width: size, height: size))
            }
        }
    }
#endif
