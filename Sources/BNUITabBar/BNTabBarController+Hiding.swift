#if canImport(UIKit)
    import BNUICore
    import UIKit

    // MARK: - Hiding the bar and keeping the content clear of it

    // The bar goes when the host hides it — a screen that is to be without it hides it as it appears
    // and shows it as it goes. Each tab keeps its content clear of the bar through its own
    // `additionalSafeAreaInsets.bottom`, which every screen in it inherits: up to the bar's top, or
    // nothing while the bar is hidden.

    public extension BNTabBarController {
        /// Whether ``setTabBarHidden(_:animated:)`` hid the bar. Setting it hides or shows the bar
        /// at once.
        var isTabBarHidden: Bool {
            get { isBarHidden }
            set { setTabBarHidden(newValue, animated: false) }
        }

        /// Hides the bar or shows it again — for a full-screen scene, or a screen that goes without
        /// it, which hides it as it appears and shows it as it goes:
        ///
        /// ```swift
        /// override func viewWillAppear(_ animated: Bool) {
        ///     super.viewWillAppear(animated)
        ///     bnTabBarController?.setTabBarHidden(true, animated: animated)
        /// }
        ///
        /// override func viewWillDisappear(_ animated: Bool) {
        ///     super.viewWillDisappear(animated)
        ///     bnTabBarController?.setTabBarHidden(false, animated: animated)
        /// }
        /// ```
        ///
        /// The bar slides past the bottom edge, and every tab's content drops its inset with it.
        /// Shown again in the middle of a swipe back in the tab on screen, it comes back only once
        /// the swipe completes: a cancelled one leaves the screen that hid it on top, and the bar
        /// hidden.
        ///
        /// The bar does not follow `hidesBottomBarWhenPushed`: a navigation controller says what it
        /// pushes to the system's tab bar controller alone.
        func setTabBarHidden(_ hidden: Bool, animated: Bool) {
            guard hidden != isBarHidden else { return }
            isBarHidden = hidden
            if !hidden, let coordinator = selectedViewController?.transitionCoordinator, coordinator.isInteractive {
                coordinator.animate(alongsideTransition: nil) { [weak self] context in
                    guard let self else { return }
                    // Cancelled: the screen that hid the bar is still on top.
                    if context.isCancelled {
                        isBarHidden = true
                    }
                    applyHiding(animated: true)
                }
                return
            }
            applyHiding(animated: animated)
        }
    }

    extension BNTabBarController {
        /// Puts the bar and the insets where ``isTabBarHidden`` says.
        private func applyHiding(animated: Bool) {
            let animated = animated && viewIfLoaded?.window != nil
            if animated {
                // On the bar's own curve, so the content follows it rather than racing it.
                BNTransition.curve(tabBar.theme.motion.visibility).run { [self] in
                    applyContentInsets()
                    view.layoutIfNeeded()
                }
            } else {
                applyContentInsets()
            }
            updateBarPresentation(animated: animated)
        }

        func updateBarPresentation(animated: Bool) {
            let presentation: BNTabBarPresentation = isBarHidden ? .hidden : .expanded
            guard tabBar.presentation != presentation else { return }
            tabBar.setPresentation(presentation, animated: animated && viewIfLoaded?.window != nil)
        }

        /// Every tab, the ones out of sight included: a tab coming back on screen is already laid
        /// out for the bar it gets. A column stands in a strip the content already keeps clear of,
        /// and takes nothing from the bottom.
        func applyContentInsets() {
            let inset = tabBar.axis == .vertical
                ? 0
                : BNTabBarControllerRules.bottomInset(
                    barTop: barTop,
                    inherited: viewIfLoaded?.safeAreaInsets.bottom ?? 0,
                    hidesBar: isBarHidden,
                )
            for tab in storedTabs where tab.viewController.additionalSafeAreaInsets.bottom != inset {
                tab.viewController.additionalSafeAreaInsets.bottom = inset
            }
        }

        /// How far the bar's top stands off the bottom edge while it is shown, with the gap above it.
        private var barTop: CGFloat {
            let base: CGFloat = switch placement {
            case .system: Self.systemMargin
            case .safeArea: viewIfLoaded?.safeAreaInsets.bottom ?? 0
            }
            return base + expandedHeight + contentGap
        }
    }
#endif
