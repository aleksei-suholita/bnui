#if canImport(UIKit)
    import UIKit

    // MARK: - Tabs and selection

    // Which tabs there are and which one is on screen: the bar's reports turned into swaps, the
    // children kept for every tab.

    extension BNTabBarController {
        func wireBar() {
            tabBar.shouldSelect = { [weak self] id in self?.shouldSelect?(id) ?? true }
            tabBar.onSelect = { [weak self] id in self?.userSelected(id) }
            tabBar.onReselect = { [weak self] id in self?.userReselected(id) }
            tabBar.onMultiTap = { [weak self] id, count in self?.onMultiTap?(id, count) }
            tabBar.onAction = { [weak self] in self?.onAction?() }
            tabBar.onEffectiveHeightChange = { [weak self] height in
                // Nothing while the bar is hidden or under the keyboard: a screen the bar is
                // hidden for drops its inset by rule, and the rest keep the bar they will get back.
                guard let self, height > 0, height != expandedHeight else { return }
                expandedHeight = height
                applyContentInsets()
            }
        }

        private func userSelected(_ id: String) {
            guard storedTabs.contains(where: { $0.item.id == id }) else { return }
            selectedTabID = id
            showSelected()
            onSelect?(id)
        }

        /// A second tap on the tab on screen takes its stack back to the root, as under
        /// `UITabBarController`; ``shouldSelect`` has already had its say.
        private func userReselected(_ id: String) {
            guard let tab = storedTabs.first(where: { $0.item.id == id }) else { return }
            (tab.viewController as? UINavigationController)?.popToRootViewController(animated: true)
            onReselect?(id)
        }

        func replaceTabs(with newTabs: [Tab]) {
            guard !newTabs.isEmpty else {
                assertionFailure("BNTabBarController needs at least one tab")
                return
            }
            let leaving = storedTabs.map(\.viewController).filter { old in
                !newTabs.contains { $0.viewController === old }
            }
            storedTabs = newTabs
            leaving.forEach(release)
            newTabs.forEach { adopt($0.viewController) }

            let selected = BNTabBarControllerRules.selection(keeping: selectedTabID, in: newTabs.map(\.item.id))
            let fellBack = selected != selectedTabID
            selectedTabID = selected
            tabBar.items = newTabs.map(\.item)
            if let selected {
                tabBar.setSelectedID(selected, animated: false)
            }
            showSelected()
            applyContentInsets()
            if fellBack, let selected {
                onSelect?(selected)
            }
        }

        func adopt(_ controller: UIViewController) {
            guard controller.parent !== self else { return }
            addChild(controller)
            controller.didMove(toParent: self)
        }

        private func release(_ controller: UIViewController) {
            controller.willMove(toParent: nil)
            if controller === currentChild {
                forwardDisappearance(of: controller) {
                    controller.view.removeFromSuperview()
                }
                currentChild = nil
            }
            controller.removeFromParent()
        }

        /// Puts the selected tab on screen, once there is a screen to put it on.
        func showSelected() {
            guard isViewLoaded, let selectedViewController else { return }
            show(selectedViewController)
            updateBarPresentation(animated: false)
        }

        /// Swaps the tab on screen. Every tab stays a child, so taking a view off and putting
        /// another on is the whole swap: the controllers are long-lived, and scroll positions and
        /// navigation stacks survive the round trip. The appearance callbacks are the controller's
        /// to hand out, as `UITabBarController` hands them out.
        private func show(_ viewController: UIViewController) {
            guard viewController !== currentChild else { return }
            let previous = currentChild
            forwardAppearance(from: previous, to: viewController) {
                place(viewController, replacing: previous)
            }
        }

        private func place(_ viewController: UIViewController, replacing previous: UIViewController?) {
            viewController.view.translatesAutoresizingMaskIntoConstraints = false
            // Below the capsule so the bar always floats on top of the content.
            view.insertSubview(viewController.view, belowSubview: tabBar)
            NSLayoutConstraint.activate([
                viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            previous?.view.removeFromSuperview()
            currentChild = viewController
            setNeedsStatusBarAppearanceUpdate()
            // The tab on screen speaks for the vertical bar, and it has just changed.
            verticalBarChildDidChange()
        }
    }
#endif
