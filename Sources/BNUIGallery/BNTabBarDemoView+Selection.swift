#if canImport(UIKit)
    import BNUI
    import UIKit

    // MARK: - The selected icon, a locked section, the action, the badge's corner

    extension BNTabBarDemoView {
        /// Gives the selected section its next selected icon, in place: its own filled symbol, its
        /// relative — `bell.slash.fill` for `bell.fill`, which iOS 18 morphs into rather than
        /// replaces — then two strangers, and round again. A picture's section takes a symbol and
        /// back, cross-fading.
        func changeSelectedIcon() {
            guard let tabBar, let id = tabBar.selectedID, let item = tabBar.items.first(where: { $0.id == id }) else { return }
            var symbols: [String?] = [nil, "star.fill"]
            if case let .symbol(name) = item.icon {
                let own = UIImage(systemName: "\(name).fill") == nil ? name : "\(name).fill"
                let relative = own.replacingOccurrences(of: ".fill", with: ".slash.fill")
                symbols = [own] + [relative, "camera.filters", "star.fill"]
                    .filter { $0 != own && UIImage(systemName: $0) != nil }
            }
            let current: String? = if case let .symbol(name)? = item.selectedIcon {
                name
            } else {
                nil
            }
            let index = symbols.firstIndex(of: current) ?? 0
            let next = symbols[(index + 1) % symbols.count]
            tabBar.setSelectedIcon(next.map { .symbol($0) }, for: id)
            report("selected icon of \(id): \(next ?? "its own")")
        }

        /// The last section turns the user away, the way a locked one does: asked before it is
        /// selected, the bar is told no, and the lens goes back.
        func setLocksLastSection(_ locks: Bool) {
            locksLastSection = locks
            tabBar?.shouldSelect = locks
                ? { [weak self] id in
                    guard let self, id == tabBar?.items.last?.id else { return true }
                    report("refused \(id)")
                    return false
                }
                : nil
        }

        func setAction(index: Int) {
            let styles: [BNTabBarAction.Style?] = [nil, .standard, .prominent]
            guard styles.indices.contains(index) else { return }
            tabBar?.action = styles[index].map {
                BNTabBarAction(icon: .symbol("plus"), accessibilityLabel: "Create", style: $0)
            }
        }

        func setBadgePosition(index: Int) {
            tabBar?.theme.badge.position = index == 1 ? .bottomTrailing : .topTrailing
        }
    }
#endif
