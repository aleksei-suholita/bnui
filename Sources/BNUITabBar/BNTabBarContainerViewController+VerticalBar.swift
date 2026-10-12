#if canImport(UIKit)
    import UIKit

    // MARK: - The vertical bar

    // iPhone Duo moves an app's bars into a strip beside the content: the status bar, the
    // navigation bar's buttons, the tab bar. The API that says so arrives with the iOS 27.1 SDK, so
    // it is compiled only by a toolchain that has it — UIKit's own module version tells — and an
    // older one builds a container that always keeps the bar a row.

    #if canImport(UIKit, _version: 9127.1)
        extension BNTabBarContainerViewController {
            /// The tab on screen decides whether its bars go vertical, as under
            /// `UITabBarController`. Kept out of the documented API: it is UIKit's contract, and
            /// the API listing would otherwise change with the SDK the kit is built against.
            @_documentation(visibility: internal)
            override public var childForPreferredVerticalBarBehavior: UIViewController? {
                currentChild
            }

            /// The strip the system keeps for bars beside the content, while the bars here go
            /// there; nil everywhere else.
            func verticalBarStrip() -> BNTabBarStrip? {
                guard #available(iOS 27.1, *) else { return nil }
                let edge = traitCollection.verticalBarEdge
                guard edge != .unspecified, resolvedVerticalBarBehavior == .automatic else { return nil }
                // The system keeps the strip on one side of the hardware whatever the language
                // reads in, so in a right-to-left one the same side is the leading edge.
                let rightToLeft = traitCollection.layoutDirection == .rightToLeft
                let side: BNTabBarStrip.Side = (edge == .trailing) != rightToLeft ? .right : .left
                let width = side == .left ? view.safeAreaInsets.left : view.safeAreaInsets.right
                let stripX = side == .left ? view.bounds.minX : view.bounds.maxX - width
                let reserved = (view.reservedRegions(kind: .occlusion) + view.reservedRegions(kind: .division)).map(\.frame)
                let buttons = systemButtonFrames(stripX: stripX, width: width, reserved: reserved)
                return BNTabBarStrip(side: side, width: width, reserved: reserved + buttons)
            }

            /// Where the system's own buttons stand in the strip.
            ///
            /// The system reserves only the status bar there: the buttons of the screen on show —
            /// its navigation items under the status bar, its toolbar's at the strip's bottom — are
            /// not counted, so each is asked where it is. A back button is the system's own, with no
            /// item to ask; it is given the first place under the status bar, the size of a section.
            @available(iOS 27.1, *)
            private func systemButtonFrames(stripX: CGFloat, width: CGFloat, reserved: [CGRect]) -> [CGRect] {
                guard let navigation = currentChild as? UINavigationController,
                      let screen = navigation.topViewController
                else { return [] }
                let item = screen.navigationItem
                let groups = item.leadingItemGroups + item.centerItemGroups + item.trailingItemGroups
                    + [item.pinnedTrailingGroup].compactMap(\.self)
                let toolbar = navigation.isToolbarHidden ? [] : screen.toolbarItems ?? []
                let items = groups.flatMap(\.barButtonItems) + (item.leftBarButtonItems ?? [])
                    + (item.rightBarButtonItems ?? []) + toolbar
                let inStrip = { (frame: CGRect) in frame.maxX > stripX && frame.minX < stripX + width }
                var frames = items.compactMap { $0.frame(in: view) }.filter { !$0.isEmpty && inStrip($0) }
                if navigation.viewControllers.count > 1, !item.hidesBackButton {
                    let top = reserved.filter { inStrip($0) && $0.minY <= view.bounds.minY + 1 }.map(\.maxY).max()
                    frames.append(CGRect(x: stripX, y: top ?? view.bounds.minY, width: width, height: tabBar.columnThickness))
                }
                return frames
            }

            /// The tab on screen has changed, and with it the say on the vertical bar.
            func verticalBarChildDidChange() {
                guard #available(iOS 27.1, *) else { return }
                setNeedsUpdateOfVerticalBarConfiguration()
            }

            /// A change of what decides the strip's edge — a rotation, opening or closing the
            /// phone — places the bar again.
            func observeVerticalBar() {
                guard #available(iOS 27.1, *) else { return }
                let traits = UITraitCollection.systemTraitsAffectingVerticalBarEdge
                registerForTraitChanges(traits) { (controller: BNTabBarContainerViewController, _: UITraitCollection) in
                    controller.view.setNeedsLayout()
                }
            }

            /// What the chain of controllers below this one asks for, followed the way the system
            /// follows it: each one deferring to the child it names.
            @available(iOS 27.1, *)
            private var resolvedVerticalBarBehavior: UIVerticalBarBehavior {
                var controller: UIViewController = self
                while let child = controller.childForPreferredVerticalBarBehavior {
                    controller = child
                }
                return controller.preferredVerticalBarBehavior
            }
        }
    #else
        extension BNTabBarContainerViewController {
            /// Built without the iOS 27.1 SDK: no strip is known, and the bar stays a row.
            func verticalBarStrip() -> BNTabBarStrip? {
                nil
            }

            func verticalBarChildDidChange() {}

            func observeVerticalBar() {}
        }
    #endif
#endif
