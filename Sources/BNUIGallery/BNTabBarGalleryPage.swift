#if canImport(UIKit)
    import BNUI
    import UIKit

    /// Bench for the BNTabBar control: every knob maps to a spec dimension, so the acceptance
    /// checklist can be walked without building a host screen. Present opens the same bar inside
    /// `BNTabBarController`, full screen, for what only the controller does.
    struct BNTabBarGalleryPage: BNGalleryPage {
        let title = "TabBar"
        let symbol = "dock.rectangle"
        let layout = BNGalleryLayout.fill()
        /// A bar floats over a list most of the time; that is where it is judged first.
        let backdrop = BNGalleryBackdrop.interface

        func makeDemoView() -> UIView {
            BNTabBarDemoView()
        }

        func resetDemo(_ demoView: UIView) {
            (demoView as? BNTabBarDemoView)?.reset()
        }

        func makeKnobs(for demoView: UIView) -> [BNGalleryKnob] {
            guard let demo = demoView as? BNTabBarDemoView else { return [] }
            return composition(demo) + placement(demo) + appearance(demo) + icons(demo) + host(demo) + state(demo)
                + controller(demo)
        }

        private func composition(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            [
                .header("Composition"),
                BNGalleryKnob(
                    label: "Sections",
                    control: .segmented(
                        options: ["2", "3", "4", "5", "6", "7"],
                        initial: BNTabBarDemoView.Defaults.sections - 2,
                        onChange: { demo.setSectionCount($0 + 2) },
                    ),
                    note: "Past what the width holds, the last slot is More and opens the rest in a menu.",
                ),
                BNGalleryKnob(label: "Last title", control: .textField(initial: "", onChange: { demo.lastTitle = $0 })),
                BNGalleryKnob(
                    label: "Minimum tab width",
                    control: .slider(
                        min: 44, max: 100,
                        initial: BNTabBarDemoView.Defaults.minimumItemWidth,
                        onChange: { demo.setMinimumItemWidth($0) },
                    ),
                    unit: "pt",
                ),
                BNGalleryKnob(label: "Action button", control: .segmented(
                    options: ["Off", "Standard", "Prominent"],
                    initial: BNTabBarDemoView.Defaults.action,
                    onChange: { demo.setAction(index: $0) },
                )),
                BNGalleryKnob(label: "Accessory", control: .toggle(
                    initial: BNTabBarDemoView.Defaults.accessory,
                    onChange: { demo.setAccessory($0) },
                )),
            ]
        }

        private func placement(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            [
                .header("Placement"),
                BNGalleryKnob(
                    label: "Axis",
                    control: .segmented(
                        options: ["Row", "Column"],
                        initial: BNTabBarDemoView.Defaults.axis,
                        onChange: { demo.setAxis(index: $0) },
                    ),
                    note: "A column is the bar in the strip iPhone Duo keeps for bars beside the content.",
                ),
                BNGalleryKnob(
                    label: "Alignment",
                    control: .segmented(
                        options: ["Leading", "Center", "Trailing"],
                        initial: BNTabBarDemoView.Defaults.alignment,
                        onChange: { demo.setAlignment(index: $0) },
                    ),
                    note: "A row's. Ignored while the action button is on — sections go leading, the action trailing — "
                        + "and in a column, which stands at the bottom of its strip.",
                ),
                BNGalleryKnob(
                    label: "Width",
                    control: .segmented(
                        options: ["Hug", "Fill"],
                        initial: BNTabBarDemoView.Defaults.width,
                        onChange: { demo.setWidth(index: $0) },
                    ),
                    note: "Fill shares the whole row among the sections, as the system's bar on iOS 26, up to the theme's "
                        + "maximum width. Hugging, the capsule fills beside an action only from three sections on.",
                ),
            ]
        }

        private func appearance(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            [
                .header("Appearance"),
                BNGalleryKnob(label: "Material", control: .segmented(
                    options: BNTabBarDemoView.materials.map(\.name),
                    initial: BNTabBarDemoView.Defaults.material,
                    onChange: { demo.setMaterial(index: $0) },
                )),
                BNGalleryKnob(label: "Labels", control: .segmented(
                    options: ["Always", "Selected", "Never"],
                    initial: BNTabBarDemoView.Defaults.labels,
                    onChange: { demo.setLabelMode(index: $0) },
                )),
                BNGalleryKnob(label: "Badge", control: .segmented(
                    options: ["Off", "Count", "120", "Text", "Dot"],
                    initial: BNTabBarDemoView.Defaults.badge,
                    onChange: { demo.setBadge(index: $0) },
                )),
                BNGalleryKnob(label: "Badge corner", control: .segmented(
                    options: ["Top", "Bottom"],
                    initial: 0,
                    onChange: { demo.setBadgePosition(index: $0) },
                )),
            ]
        }

        private func icons(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            [
                .header("Icons"),
                BNGalleryKnob(label: "Last icon", control: .segmented(
                    options: ["Symbol", "80 pt glyph", "Photo", "Symbol image"],
                    initial: BNTabBarDemoView.Defaults.lastIcon,
                    onChange: { demo.lastIcon = $0 },
                )),
                BNGalleryKnob(label: "Change the selected icon", control: .button(onTap: { demo.changeSelectedIcon() })),
                BNGalleryKnob(label: "Symbol effect", control: .segmented(
                    options: BNTabBarDemoView.selectionEffects.map(\.name),
                    initial: BNTabBarDemoView.Defaults.selectionAnimation,
                    onChange: { demo.setSelectionAnimation(index: $0) },
                )),
            ]
        }

        private func host(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            [
                .header("Host"),
                BNGalleryKnob(label: "Select next, as the host", control: .button(onTap: { demo.selectNextFromHost() })),
                BNGalleryKnob(label: "Lock the last section", control: .toggle(
                    initial: false,
                    onChange: { demo.setLocksLastSection($0) },
                )),
            ]
        }

        private func controller(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            [
                .header("Controller"),
                BNGalleryKnob(
                    label: "Vertical bar",
                    control: .segmented(
                        options: ["Automatic", "Disabled"],
                        initial: 0,
                        onChange: { demo.verticalBar = $0 == 1 ? .disabled : .automatic },
                    ),
                    note: "What every tab's screen asks of iPhone Duo's strip; on any other phone nothing changes.",
                ),
                BNGalleryKnob(
                    label: "Present",
                    control: .button(onTap: { demo.presentController() }),
                    note: "The bar inside BNTabBarController, full screen, as the knobs above set it. Axis, "
                        + "Accessory and Presentation stay with the bar on the stage.",
                ),
            ]
        }

        private func state(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            [
                .header("State"),
                BNGalleryKnob(label: "Presentation", control: .segmented(
                    options: ["Expanded", "Hidden"],
                    initial: BNTabBarDemoView.Defaults.presentation,
                    onChange: { demo.setPresentation(index: $0) },
                )),
                BNGalleryKnob(label: "Haptics", control: .toggle(
                    initial: BNTabBarDemoView.Defaults.haptics,
                    onChange: { demo.setHaptics($0) },
                )),
            ]
        }
    }
#endif
