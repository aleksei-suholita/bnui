#if canImport(UIKit)
    import BNUICore
    import Combine
    import SwiftUI
    import UIKit

    extension BNButton {
        // MARK: - Roll

        /// Carries the old content into the new one through SwiftUI's numeric text transition: the
        /// characters that change roll into their new ones, the rest slide to where they now stand,
        /// an icon that comes grows in where it will stand, and one that goes shrinks by the edge it
        /// stood at as its room closes.
        ///
        /// UIKit's label has no such transition, so SwiftUI draws the row again over the content —
        /// in the same font, colours and sizes — until the change has settled; then the content is
        /// shown again. A change that lands meanwhile turns the drawing towards it from wherever it
        /// has got to, the way SwiftUI retargets an animation: a run of changes rolls on without a
        /// jump. Centred content only, like the blur.
        ///
        /// Text into text only. Content with no title, a lone icon, has nothing to roll: the
        /// title would only fade out where it stood, wider than the outline shrinking under it.
        ///
        /// - Returns: `false` when the change cannot be drawn so; it then blurs instead.
        func rollText(
            from outgoing: UIView?,
            to incoming: UIView,
            timing: BNButtonContentTiming,
            startCentre: CGPoint,
        ) -> Bool {
            guard configuration.alignment == .center,
                  let container = surface?.contentContainer,
                  let newRow = (incoming as? BNButtonContentView)?.rollRow(), newRow.title != nil
            else { return false }
            let roll: BNButtonRoll
            if let running = contentDrawing {
                roll = running
            } else {
                guard let oldRow = (outgoing as? BNButtonContentView)?.rollRow(), oldRow.title != nil else { return false }
                roll = BNButtonRoll(row: oldRow, reducesMotion: reducesMotion)
                roll.view.center = startCentre
                container.insertSubview(roll.view, aboveSubview: incoming)
                // Drawn now, before the old content is taken away: left to the next layout pass,
                // the button could show a frame with neither.
                UIView.performWithoutAnimation { roll.view.layoutIfNeeded() }
                contentDrawing = roll
            }
            UIView.performWithoutAnimation {
                incoming.alpha = 0
                roll.makeRoom(for: newRow)
            }
            if let outgoing {
                finishLeaving(outgoing)
            }
            // The row is laid out again as it changes, so it moves on the outline's spring when the
            // kit moves the outline: on a spring of its own, an icon beside the title would drift
            // against the edge it stands by.
            let spring = timing == .own && animatesSizeChanges ? sizeSpring : contentSpring(for: timing)
            roll.model.turn(to: newRow, animation: spring.animation)
            follow(roll.view, to: contentCentre, timing: timing)
            handBack(roll, after: spring.duration * Self.settlingFactor)
            return true
        }
    }

    /// The content as SwiftUI draws it again for the roll style: one row, an icon, a title,
    /// an icon — any of them optional — in the font, colours and sizes the content stands in.
    struct BNButtonRollRow {
        struct Icon {
            /// What the icon is, so that a different one in the same slot comes and goes rather
            /// than turning into the next.
            let key: String
            /// The icon view's own pixels, tinted as it shows them: a symbol drawn again by
            /// SwiftUI is fitted to its frame by other rules, and stood a little off the one
            /// under it.
            let picture: UIImage
            let size: CGSize
            let alpha: CGFloat
        }

        var leading: Icon?
        var title: String?
        /// The label's width: the title is drawn from its leading edge, as the label draws it.
        var titleWidth: CGFloat
        var font: UIFont
        var titleColour: UIColor
        var trailing: Icon?
        var spacing: CGFloat
        /// The whole row's size, for the box the drawing stands in.
        var size: CGSize

        init(title: String?, titleWidth: CGFloat, font: UIFont, titleColour: UIColor, spacing: CGFloat, size: CGSize) {
            self.title = title
            self.titleWidth = titleWidth
            self.font = font
            self.titleColour = titleColour
            self.spacing = spacing
            self.size = size
        }
    }

    extension BNButtonIconView {
        /// The icon as the roll style draws it again: its picture, at the size it is laid
        /// out at, in the colour it shows.
        func rollIcon(showing icon: BNButtonIcon) -> BNButtonRollRow.Icon? {
            guard image != nil, bounds.width > 0, bounds.height > 0 else { return nil }
            let key = switch icon {
            case let .symbol(name): "symbol \(name)"
            case let .image(image, _, _): "image \(ObjectIdentifier(image))"
            }
            return BNButtonRollRow.Icon(
                key: key,
                picture: pictureAtRest(),
                size: bounds.size,
                alpha: keepsOwnColours ? alpha : 1,
            )
        }
    }

    /// A change the roll style is drawing: the SwiftUI row over the content, and the model
    /// it draws from.
    final class BNButtonRoll {
        let model: BNButtonRollModel
        let view: BNHostingView<BNButtonRollView>
        /// Counts the changes the roll has turned to, so that only the latest one ends it.
        var generation = 0

        init(row: BNButtonRollRow, reducesMotion: Bool) {
            model = BNButtonRollModel(row: row, reducesMotion: reducesMotion)
            view = BNHostingView(BNButtonRollView(model: model))
            view.isUserInteractionEnabled = false
            view.translatesAutoresizingMaskIntoConstraints = true
            view.bounds = CGRect(origin: .zero, size: Self.box(around: row.size))
        }

        nonisolated deinit {}

        /// Widens the box to hold `row` as well. The row is centred in it, and the box keeps its
        /// centre, so the drawing does not move.
        func makeRoom(for row: BNButtonRollRow) {
            let needed = Self.box(around: row.size)
            let current = view.bounds.size
            guard needed.width > current.width || needed.height > current.height else { return }
            view.bounds.size = CGSize(width: max(needed.width, current.width), height: max(needed.height, current.height))
        }

        /// Room around the row for the characters rolling in and out above and below it, and for
        /// an icon growing in beside it.
        private static func box(around size: CGSize) -> CGSize {
            CGSize(width: size.width + 2 * horizontalRoom, height: size.height * 2)
        }

        private static let horizontalRoom: CGFloat = 16
    }

    /// What one side of the drawing holds: the icon it shows, and those it showed that are going.
    struct BNButtonRollSlot {
        struct Entry: Identifiable {
            var icon: BNButtonRollRow.Icon
            var shown: Bool

            var id: String {
                icon.key
            }
        }

        private(set) var entries: [Entry] = []

        init(showing icon: BNButtonRollRow.Icon?) {
            if let icon {
                entries = [Entry(icon: icon, shown: true)]
            }
        }

        /// The icon the side shows, the one it takes room for.
        var shown: BNButtonRollRow.Icon? {
            entries.first(where: \.shown)?.icon
        }

        /// Turns the side to `icon`. One it shows already stays as it is drawn: a new picture of
        /// it, alike to the pixel, would still cross-fade into it, and the icon would blink. One it
        /// showed is kept, hidden, until the drawing ends: taken out, it would be left where it
        /// stood while the row closed up without it.
        mutating func turn(to icon: BNButtonRollRow.Icon?) {
            for index in entries.indices {
                entries[index].shown = entries[index].icon.key == icon?.key
            }
            guard let icon else { return }
            guard let index = entries.firstIndex(where: { $0.icon.key == icon.key }) else {
                entries.append(Entry(icon: icon, shown: true))
                return
            }
            let drawn = entries[index].icon
            entries[index].icon = BNButtonRollRow.Icon(
                key: icon.key,
                picture: drawn.size == icon.size ? drawn.picture : icon.picture,
                size: icon.size,
                alpha: icon.alpha,
            )
        }
    }

    /// What the drawing shows and which way its numbers roll.
    final class BNButtonRollModel: ObservableObject {
        @Published private(set) var row: BNButtonRollRow
        @Published private(set) var leading: BNButtonRollSlot
        @Published private(set) var trailing: BNButtonRollSlot
        @Published private(set) var countsDown = false
        let reducesMotion: Bool
        private var hasAppeared = false
        private var pending: (row: BNButtonRollRow, animation: Animation)?

        init(row: BNButtonRollRow, reducesMotion: Bool) {
            self.row = row
            leading = BNButtonRollSlot(showing: row.leading)
            trailing = BNButtonRollSlot(showing: row.trailing)
            self.reducesMotion = reducesMotion
        }

        nonisolated deinit {}

        /// Turns the drawing to `newRow` on `animation`. Before the drawing is on screen the change
        /// waits for it: changed before its first frame, the old row would never be seen.
        func turn(to newRow: BNButtonRollRow, animation: Animation) {
            guard hasAppeared else {
                pending = (newRow, animation)
                return
            }
            let down = BNButtonRollDirection.countsDown(from: row.title, to: newRow.title)
            withAnimation(animation) {
                countsDown = down
                row = newRow
                leading.turn(to: newRow.leading)
                trailing.turn(to: newRow.trailing)
            }
        }

        func appeared() {
            hasAppeared = true
            guard let pending else { return }
            self.pending = nil
            turn(to: pending.row, animation: pending.animation)
        }
    }

    /// The row drawn by SwiftUI, whose numeric text transition is what UIKit's label lacks.
    struct BNButtonRollView: View {
        @ObservedObject var model: BNButtonRollModel

        var body: some View {
            let row = model.row
            HStack(spacing: 0) {
                slot(model.leading, by: .leading, spacing: row.spacing)
                if let title = row.title {
                    Text(title)
                        .font(Font(row.font as CTFont))
                        .foregroundStyle(Color(uiColor: row.titleColour))
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: row.titleWidth > 0 ? row.titleWidth : nil, alignment: .leading)
                        .contentTransition(model.reducesMotion ? .opacity : .numericText(countsDown: model.countsDown))
                        .transition(.opacity)
                }
                slot(model.trailing, by: .trailing, spacing: row.spacing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A drawing of what the button already says: the button speaks for itself.
            .accessibilityHidden(true)
            .onAppear { model.appeared() }
        }

        /// One side's icons, by the outer edge of the room the shown one takes. The room of one
        /// that goes closes under it, and it shrinks there, by the edge of the outline, as the
        /// button keeps an icon it lets go; one that comes grows in where it will stand.
        private func slot(_ slot: BNButtonRollSlot, by edge: HorizontalEdge, spacing: CGFloat) -> some View {
            let alignment: Alignment = edge == .leading ? .leading : .trailing
            let room = slot.shown
            return ZStack(alignment: alignment) {
                ForEach(slot.entries) { entry in
                    icon(entry)
                }
            }
            .frame(width: room?.size.width ?? 0, alignment: alignment)
            .padding(edge == .leading ? .trailing : .leading, room == nil ? 0 : spacing)
        }

        private func icon(_ entry: BNButtonRollSlot.Entry) -> some View {
            let away = model.reducesMotion ? 1 : Self.iconAway
            return Image(uiImage: entry.icon.picture)
                .frame(width: entry.icon.size.width, height: entry.icon.size.height)
                .scaleEffect(entry.shown ? 1 : away)
                .opacity(entry.shown ? entry.icon.alpha : 0)
                .accessibilityHidden(true)
                .transition(model.reducesMotion ? .opacity : .opacity.combined(with: .scale(scale: Self.iconAway)))
        }

        /// How small an icon is when it comes and when it goes, as the button's own icons.
        private static let iconAway: CGFloat = 0.5
    }
#endif
