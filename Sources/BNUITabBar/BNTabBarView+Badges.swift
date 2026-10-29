#if canImport(UIKit)
    import BNUICore
    import UIKit

    // MARK: - Badges and selected icons

    // What changes on a section without the bar being rebuilt — its badge, its selected icon — and
    // the layer the badges hang from the sections in, inside the glass.

    public extension BNTabBarView {
        /// Shows `badge` on the section with `id`, or takes its badge away with `nil` — drawn in
        /// place, as a change to ``items`` that touches only badges is. Found by id rather than by
        /// position, so it holds when the host orders its sections differently. Unknown ids are
        /// ignored rather than trapped: an id is data, and a stale one must not crash the app.
        func setBadge(_ badge: BNBadge?, for id: String) {
            guard let index = items.firstIndex(where: { $0.id == id }), items[index].badge != badge else { return }
            items[index].badge = badge
        }

        /// Shows `icon` on the section with `id` while it is selected, or its own icon again with
        /// `nil` — a camera's section showing the filter in use. Changed in place and animated: a
        /// symbol gives way by the system's replace effect, a picture cross-fades. Unknown ids are
        /// ignored, as in ``setBadge(_:for:)``.
        func setSelectedIcon(_ icon: BNTabBarItem.Icon?, for id: String) {
            guard let index = items.firstIndex(where: { $0.id == id }), items[index].selectedIcon != icon else { return }
            items[index].selectedIcon = icon
        }
    }

    extension BNTabBarView {
        /// What the More slot draws: the host's More item, with a dot while a section behind it
        /// has a badge — a badge in a closed menu would otherwise go unseen. What the dot stands
        /// for is said by the slot's accessibility value, not by the dot.
        var moreSlotItem: BNTabBarItem {
            let limit = activeTheme.badge.countLimit
            let hasBadge = overflowItems.contains { $0.badge?.appearance(countLimit: limit) != nil }
            var item = configuration.moreItem
            item.badge = hasBadge ? .dot(accessibilityLabel: "") : nil
            return item
        }

        /// The overlay the badges are drawn in: inside the material, above the lens, so a badge
        /// moves with its section when the glass rises under a finger. The badges are glass —
        /// system glass blends paint inside it into itself, and a painted badge, the reddest thing
        /// on the bar, came out washed; glass keeps its colour there.
        func buildBadgeOverlay(in surface: BNTabBarSurface) {
            let host = surface.contentContainer
            badgeOverlay.subviews.forEach { $0.removeFromSuperview() }
            badgeOverlay.isUserInteractionEnabled = false
            badgeOverlay.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(badgeOverlay)
            NSLayoutConstraint.activate([
                badgeOverlay.topAnchor.constraint(equalTo: host.topAnchor),
                badgeOverlay.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                badgeOverlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                badgeOverlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            ])
        }

        /// A slot's badge in the overlay, hung from the anchor its view gives and kept inside the
        /// view; `nil` for a view that draws its own badge.
        func makeBadge(for item: BNTabBarItem, on view: any BNTabBarItemRendering) -> BNBadgeView? {
            guard let anchor = view.badgeAnchor else { return nil }
            let badge = BNBadgeView(theme: activeTheme.badge, crossFade: activeTheme.motion.crossFade, material: .glass)
            badgeOverlay.addSubview(badge)
            badge.pin(toCornerOf: anchor)
            badge.keepInside(view)
            badge.show(item.badge, transition: .immediate)
            return badge
        }

        /// Shows new badges and selected icons on the sections already built, when nothing else
        /// changed. `false` when anything else did, or when a renderer cannot draw the change in
        /// place — the caller rebuilds then.
        func updateInPlace(from oldItems: [BNTabBarItem]) -> Bool {
            guard !baseItemViews.isEmpty,
                  oldItems.count == items.count,
                  zip(oldItems, items).allSatisfy({ old, new in new.differsOnlyInPlace(from: old) })
            else { return false }
            let more = moreSlotIndex == nil ? [] : [moreSlotItem]
            let slots = Array(visibleItems) + more
            let oldSlots = Array(oldItems.prefix(visibleItems.count)) + more
            guard slots.count == baseItemViews.count, slots.count == selectedItemViews.count, slots.count == badgeViews.count
            else { return false }

            // The pop and the replace are decoration, so Reduce Motion shows the change at once.
            let transition: BNTransition = bnReducesMotion
                ? .immediate
                : .spring(activeTheme.motion.itemAccent)
            for (index, item) in slots.enumerated() {
                guard baseItemViews[index].updateBadge(item.badge, transition: transition),
                      selectedItemViews[index].updateBadge(item.badge, transition: transition)
                else { return false }
                badgeViews[index]?.show(item.badge, transition: transition)
                guard item.selectedIcon != oldSlots[index].selectedIcon else { continue }
                guard baseItemViews[index].updateSelectedIcon(item.selectedIcon, transition: transition),
                      selectedItemViews[index].updateSelectedIcon(item.selectedIcon, transition: transition)
                else { return false }
            }
            // More's spoken value names the badges behind it, so it is said anew.
            refreshAccessibilitySelection()
            return true
        }
    }
#endif
