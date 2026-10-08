#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// Bench for the BNTabBar control: every knob maps to a spec dimension, so the acceptance
    /// checklist can be walked without building a host screen.
    ///
    /// Motion is split by who moves the lens. A finger rides **lift** (to the finger) and **settle**
    /// (onto a section after a drag); a host calling `setSelectedID` rides the **selection** spring,
    /// which is why that group carries a button that selects as a host would.
    struct BNTabBarGalleryPage: GalleryPage {
        let title = "TabBar"
        let symbol = "dock.rectangle"
        let summary: String? = "Sections, lens, action and accessory"
        let fillsDemoArea = true
        /// A bar floats over a list most of the time; that is where it is judged first.
        let backdrop = GalleryBackdrop.interface

        func makeDemoView() -> UIView {
            BNTabBarDemoView()
        }

        func resetDemo(_ demoView: UIView) {
            (demoView as? BNTabBarDemoView)?.reset()
        }

        func makeKnobs(for demoView: UIView) -> [GalleryKnob] {
            guard let demo = demoView as? BNTabBarDemoView else { return [] }
            return composition(demo) + appearance(demo) + fingerMotion(demo) + hostMotion(demo) + state(demo)
        }

        private func composition(_ demo: BNTabBarDemoView) -> [GalleryKnob] {
            [
                .header("Composition"),
                GalleryKnob(
                    label: "Sections",
                    control: .segmented(
                        options: ["2", "3", "4", "5", "6", "7"],
                        initial: BNTabBarDemoView.Defaults.sections - 2,
                        onChange: { demo.setSectionCount($0 + 2) },
                    ),
                    note: "Crowded, the bar narrows sections, then shrinks labels, then drops them. "
                        + "Past what the width holds, the last slot is More and opens the rest in a menu.",
                ),
                GalleryKnob(
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
                GalleryKnob(
                    label: "Action button",
                    control: .segmented(
                        options: ["Off", "Standard", "Prominent", "Yellow"],
                        initial: BNTabBarDemoView.Defaults.action,
                        onChange: { demo.setAction(index: $0) },
                    ),
                    note: "Made of the bar's material: glass beside glass, blur beside blur, paint beside paint. "
                        + "Prominent takes the accent; Yellow passes its own fill and glyph.",
                ),
                GalleryKnob(label: "Accessory", control: .toggle(
                    initial: BNTabBarDemoView.Defaults.accessory,
                    onChange: { demo.setAccessory($0) },
                )),
                GalleryKnob(
                    label: "Alignment",
                    control: .segmented(
                        options: ["Leading", "Center", "Trailing"],
                        initial: BNTabBarDemoView.Defaults.alignment,
                        onChange: { demo.setAlignment(index: $0) },
                    ),
                    note: "Ignored while the action button is on: sections go leading, the action trailing.",
                ),
            ]
        }

        private func appearance(_ demo: BNTabBarDemoView) -> [GalleryKnob] {
            [
                .header("Appearance"),
                GalleryKnob(label: "Material", control: .segmented(
                    options: BNTabBarDemoView.materials.map(\.name),
                    initial: BNTabBarDemoView.Defaults.material,
                    onChange: { demo.setMaterial(index: $0) },
                )),
                GalleryKnob(label: "Labels", control: .segmented(
                    options: ["Always", "Selected", "Never"],
                    initial: BNTabBarDemoView.Defaults.labels,
                    onChange: { demo.setLabelMode(index: $0) },
                )),
                GalleryKnob(label: "Badge", control: .toggle(
                    initial: BNTabBarDemoView.Defaults.badge,
                    onChange: { demo.setBadge($0) },
                )),
                GalleryKnob(label: "Symbol effect", control: .segmented(
                    options: ["Bounce", "Pulse", "Wiggle", "Rotate", "Breathe", "Off"],
                    initial: BNTabBarDemoView.Defaults.selectionAnimation,
                    onChange: { demo.setSelectionAnimation(index: $0) },
                )),
            ]
        }

        private func fingerMotion(_ demo: BNTabBarDemoView) -> [GalleryKnob] {
            let motion = BNTabBarDemoView.Defaults.motion
            return [
                .header("Finger"),
                GalleryKnob(
                    label: "To the finger",
                    control: .slider(min: 0.15, max: 0.7, initial: motion.lift.duration, onChange: { demo.setLift(duration: $0) }),
                    unit: "s",
                    note: "The lens darting to the section under a touch-down.",
                ),
                GalleryKnob(
                    label: "To the finger, bounce",
                    control: .slider(min: 0, max: 0.6, initial: motion.lift.bounce, onChange: { demo.setLift(bounce: $0) }),
                ),
                GalleryKnob(
                    label: "Settle",
                    control: .slider(min: 0.2, max: 0.8, initial: motion.unlift.duration, onChange: { demo.setUnlift(duration: $0) }),
                    unit: "s",
                    note: "The lens landing on a section when the finger lets go.",
                ),
                GalleryKnob(
                    label: "Settle, bounce",
                    control: .slider(min: 0, max: 0.6, initial: motion.unlift.bounce, onChange: { demo.setUnlift(bounce: $0) }),
                ),
                GalleryKnob(
                    label: "Lift scale",
                    control: .slider(min: 1, max: 1.3, initial: BNTabBarDemoView.Defaults.liftScale, onChange: { demo.setLiftScale($0) }),
                    unit: "×",
                    note: "No growth over glass flat, blur or solid, or under Reduce Motion.",
                ),
            ]
        }

        private func hostMotion(_ demo: BNTabBarDemoView) -> [GalleryKnob] {
            let motion = BNTabBarDemoView.Defaults.motion
            return [
                .header("Host"),
                GalleryKnob(label: "Select next, as the host", control: .button(onTap: { demo.selectNextFromHost() })),
                GalleryKnob(
                    label: "Selection",
                    control: .slider(
                        min: 0.15, max: 0.8,
                        initial: motion.selection.duration,
                        onChange: { demo.setSelection(duration: $0) },
                    ),
                    unit: "s",
                ),
                GalleryKnob(
                    label: "Selection, bounce",
                    control: .slider(min: 0, max: 0.6, initial: motion.selection.bounce, onChange: { demo.setSelection(bounce: $0) }),
                ),
            ]
        }

        private func state(_ demo: BNTabBarDemoView) -> [GalleryKnob] {
            [
                .header("State"),
                GalleryKnob(label: "Presentation", control: .segmented(
                    options: ["Expanded", "Hidden"],
                    initial: BNTabBarDemoView.Defaults.presentation,
                    onChange: { demo.setPresentation(index: $0) },
                )),
                GalleryKnob(label: "Haptics", control: .toggle(
                    initial: BNTabBarDemoView.Defaults.haptics,
                    onChange: { demo.setHaptics($0) },
                )),
            ]
        }
    }
#endif
