#if canImport(UIKit)
    import BNUI
    import UIKit

    /// Bench for the BNTabBar control: every knob maps to a spec dimension, so the acceptance
    /// checklist can be walked without building a host screen.
    ///
    /// Motion is split by who moves the lens. A finger rides **lift** (to the finger) and **settle**
    /// (onto a section after a drag); a host calling `setSelectedID` rides the **selection** spring,
    /// which is why that group carries a button that selects as a host would.
    struct BNTabBarGalleryPage: BNGalleryPage {
        let title = "TabBar"
        let symbol = "dock.rectangle"
        let summary: String? = "Sections, lens, action and accessory"
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
            return composition(demo) + placement(demo) + appearance(demo) + icons(demo)
                + fingerMotion(demo) + hostMotion(demo) + state(demo)
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
                    note: "Crowded, the bar narrows sections, then shrinks labels, then drops them. "
                        + "Past what the width holds, the last slot is More and opens the rest in a menu.",
                ),
                BNGalleryKnob(
                    label: "Minimum width",
                    control: .slider(
                        min: 44, max: 100,
                        initial: BNTabBarDemoView.Defaults.minimumItemWidth,
                        onChange: { demo.setMinimumItemWidth($0) },
                    ),
                    unit: "pt",
                    note: "Narrowest a section gets before the tail goes behind More. "
                        + "The action takes its width first, so it brings More sooner.",
                ),
                BNGalleryKnob(
                    label: "Action button",
                    control: .segmented(
                        options: ["Off", "Standard", "Prominent", "Yellow"],
                        initial: BNTabBarDemoView.Defaults.action,
                        onChange: { demo.setAction(index: $0) },
                    ),
                    note: "Made of the bar's material: glass beside glass, blur beside blur, paint beside paint. "
                        + "Prominent takes the accent; Yellow passes its own fill and glyph.",
                ),
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
                    note: "A column is the bar in the strip iPhone Duo keeps for bars beside the content: "
                        + "icons, the action under them, no accessory. The container puts it there by itself — "
                        + "see TabBar container.",
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
                BNGalleryKnob(
                    label: "Badge corner",
                    control: .segmented(options: ["Top", "Bottom"], initial: 0, onChange: { demo.setBadgePosition(index: $0) }),
                    note: "A badge stays inside its section: try 120 with five sections. At the bottom it lies over a shown title.",
                ),
                BNGalleryKnob(label: "Ticking count", control: .toggle(
                    initial: false,
                    onChange: { demo.setTickingBadge($0) },
                )),
            ]
        }

        private func icons(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            [
                .header("Icons"),
                BNGalleryKnob(
                    label: "Last icon",
                    control: .segmented(
                        options: ["Symbol", "80 pt glyph", "Photo", "Symbol image"],
                        initial: BNTabBarDemoView.Defaults.lastIcon,
                        onChange: { demo.lastIcon = $0 },
                    ),
                    note: "An image fits a box the size of a round symbol, so a large asset does not grow the bar. "
                        + "A photo keeps its colours; only the lens says it is chosen.",
                ),
                BNGalleryKnob(
                    label: "Symbol scale",
                    control: .segmented(
                        options: ["Small", "Medium", "Large"],
                        initial: 1,
                        onChange: { demo.setSymbolScale(index: $0) },
                    ),
                    note: "The system's tab bar on iOS 26 draws its symbols large. A symbol image takes the scale too.",
                ),
                BNGalleryKnob(
                    label: "Symbol effect",
                    control: .segmented(
                        options: BNTabBarDemoView.selectionEffects.map(\.name),
                        initial: BNTabBarDemoView.Defaults.selectionAnimation,
                        onChange: { demo.setSelectionAnimation(index: $0) },
                    ),
                    note: "Plays on a symbol — the last icon as a symbol image stands for an app's own. "
                        + "Wiggle, rotate and breathe bounce before iOS 18, drawing on before iOS 26.",
                ),
            ]
        }

        private func fingerMotion(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            let motion = BNTabBarDemoView.Defaults.motion
            return [
                .header("Finger"),
                BNGalleryKnob(
                    label: "To the finger",
                    control: .slider(min: 0.15, max: 0.7, initial: motion.lift.duration, onChange: { demo.setLift(duration: $0) }),
                    unit: "s",
                    note: "The lens darting to the section under a touch-down.",
                ),
                BNGalleryKnob(
                    label: "To the finger, bounce",
                    control: .slider(min: 0, max: 0.6, initial: motion.lift.bounce, onChange: { demo.setLift(bounce: $0) }),
                ),
                BNGalleryKnob(
                    label: "Settle",
                    control: .slider(min: 0.2, max: 0.8, initial: motion.unlift.duration, onChange: { demo.setUnlift(duration: $0) }),
                    unit: "s",
                    note: "The lens landing on a section when the finger lets go.",
                ),
                BNGalleryKnob(
                    label: "Settle, bounce",
                    control: .slider(min: 0, max: 0.6, initial: motion.unlift.bounce, onChange: { demo.setUnlift(bounce: $0) }),
                ),
            ]
        }

        private func hostMotion(_ demo: BNTabBarDemoView) -> [BNGalleryKnob] {
            let motion = BNTabBarDemoView.Defaults.motion
            return [
                .header("Host"),
                BNGalleryKnob(label: "Select next, as the host", control: .button(onTap: { demo.selectNextFromHost() })),
                BNGalleryKnob(
                    label: "Selection",
                    control: .slider(
                        min: 0.15, max: 0.8,
                        initial: motion.selection.duration,
                        onChange: { demo.setSelection(duration: $0) },
                    ),
                    unit: "s",
                ),
                BNGalleryKnob(
                    label: "Selection, bounce",
                    control: .slider(min: 0, max: 0.6, initial: motion.selection.bounce, onChange: { demo.setSelection(bounce: $0) }),
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
