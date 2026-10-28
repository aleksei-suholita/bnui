#if canImport(UIKit)
    import BNUI
    import UIKit

    /// Gallery page for ``BNButton``.
    struct BNButtonGalleryPage: BNGalleryPage {
        let title = "Button"
        let symbol = "capsule"
        let layout = BNGalleryLayout.fill(share: 0.42)

        func makeDemoView() -> UIView {
            BNButtonDemoView()
        }

        func resetDemo(_ demoView: UIView) {
            (demoView as? BNButtonDemoView)?.reset()
        }

        func makeKnobs(for demoView: UIView) -> [BNGalleryKnob] {
            guard let demo = demoView as? BNButtonDemoView else { return [] }
            return content(demo) + appearance(demo) + state(demo) + refusal(demo) + haptics(demo) + bench(demo)
        }
    }

    // MARK: - Sections

    //
    // One builder per section of the inspector, in an extension so the page itself reads as the
    // list of sections rather than as the knobs in them.

    private extension BNButtonGalleryPage {
        func content(_ demo: BNButtonDemoView) -> [BNGalleryKnob] {
            [
                .header("Content"),
                BNGalleryKnob(label: "Title", control: .textField(
                    initial: BNButtonDemoView.Defaults.title,
                    onChange: { demo.setTitle($0) },
                )),
                BNGalleryKnob(label: "Content", control: .segmented(
                    options: ["Title", "+Lead", "+Trail", "Icon", "Custom"],
                    initial: BNButtonDemoView.Defaults.contentIndex,
                    onChange: { demo.setContentKind(index: $0) },
                )),
                BNGalleryKnob(label: "Icon", control: .segmented(
                    options: ["Gear", "Plus", "Chevron", "Tall", "Wide", "Wider", "Picture"],
                    initial: BNButtonDemoView.Defaults.iconIndex,
                    onChange: { demo.setIcon(index: $0) },
                )),
                BNGalleryKnob(label: "Long title", control: .toggle(
                    initial: BNButtonDemoView.Defaults.usesLongTitle,
                    onChange: { demo.setLongTitle($0) },
                )),
                BNGalleryKnob(label: "Title behavior", control: .segmented(
                    options: ["Truncate", "Wrap 2", "Wrap ∞"],
                    initial: BNButtonDemoView.Defaults.titleBehaviorIndex,
                    onChange: { demo.setTitleBehavior(index: $0) },
                )),
            ]
        }

        func appearance(_ demo: BNButtonDemoView) -> [BNGalleryKnob] {
            [
                .header("Appearance"),
                BNGalleryKnob(label: "Style", control: .segmented(
                    options: ["Primary", "Secondary", "Ghost", "Destructive"],
                    initial: BNButtonDemoView.Defaults.styleIndex,
                    onChange: { demo.setStyle(index: $0) },
                )),
                BNGalleryKnob(label: "Material", control: .segmented(
                    options: BNButtonDemoView.materials.map(\.name),
                    initial: BNButtonDemoView.Defaults.materialIndex,
                    onChange: { demo.setMaterial(index: $0) },
                )),
                BNGalleryKnob(label: "Corner", control: .segmented(
                    options: ["Capsule", "Rounded"],
                    initial: BNButtonDemoView.Defaults.cornerIndex,
                    onChange: { demo.setCorner(index: $0) },
                )),
                BNGalleryKnob(label: "Size", control: .segmented(
                    options: ["S", "M", "L"],
                    initial: BNButtonDemoView.Defaults.sizeIndex,
                    onChange: { demo.setSize(index: $0) },
                )),
                BNGalleryKnob(label: "Width", control: .segmented(
                    options: ["Hug", "Fill", "200"],
                    initial: BNButtonDemoView.Defaults.widthIndex,
                    onChange: { demo.setWidth(index: $0) },
                )),
                BNGalleryKnob(
                    label: "Alignment",
                    control: .segmented(
                        options: ["Leading", "Center", "Trailing"],
                        initial: BNButtonDemoView.Defaults.alignmentIndex,
                        onChange: { demo.setAlignment(index: $0) },
                    ),
                    note: "Seen with Width Fill or 200.",
                ),
            ]
        }

        func state(_ demo: BNButtonDemoView) -> [BNGalleryKnob] {
            [
                .header("State"),
                BNGalleryKnob(label: "Status", control: .segmented(
                    options: ["Enabled", "Disabled", "Loading"],
                    initial: BNButtonDemoView.Defaults.statusIndex,
                    onChange: { demo.setStatus(index: $0) },
                )),
                BNGalleryKnob(label: "Badge", control: .segmented(
                    options: ["None", "3", "120", "New", "Dot"],
                    initial: BNButtonDemoView.Defaults.badgeIndex,
                    onChange: { demo.setBadge(index: $0) },
                )),
                BNGalleryKnob(label: "Badge corner", control: .segmented(
                    options: ["Top", "Bottom"],
                    initial: 0,
                    onChange: { demo.setBadgePosition(index: $0) },
                )),
                BNGalleryKnob(label: "Menu", control: .segmented(
                    options: ["None", "Tap", "Long press"],
                    initial: BNButtonDemoView.Defaults.menuIndex,
                    onChange: { demo.setMenu(index: $0) },
                )),
                BNGalleryKnob(
                    label: "Cooldown",
                    control: .slider(
                        min: 0, max: 1,
                        initial: BNButtonDemoView.Defaults.cooldown,
                        onChange: { demo.setCooldown($0) },
                    ),
                    unit: "s",
                ),
            ]
        }

        /// Set Status to Disabled and tap the button to see these.
        func refusal(_ demo: BNButtonDemoView) -> [BNGalleryKnob] {
            [
                .header("Refusal"),
                BNGalleryKnob(
                    label: "Refuse disabled taps",
                    control: .toggle(
                        initial: BNButtonDemoView.Defaults.rejectionEnabled,
                        onChange: { demo.setRejection($0) },
                    ),
                    note: "Set Status to Disabled, then tap the button.",
                ),
                BNGalleryKnob(label: "Refusal haptic", control: .toggle(
                    initial: BNButtonDemoView.Defaults.rejectionHaptic,
                    onChange: { demo.setRejectionHaptic($0) },
                )),
            ]
        }

        func haptics(_ demo: BNButtonDemoView) -> [BNGalleryKnob] {
            [
                .header("Haptics"),
                BNGalleryKnob(label: "Haptics", control: .toggle(
                    initial: BNButtonDemoView.Defaults.hapticsEnabled,
                    onChange: { demo.setHapticsEnabled($0) },
                )),
                BNGalleryKnob(
                    label: "Haptic merge window",
                    control: .slider(
                        min: 0, max: 0.40,
                        initial: BNButtonDemoView.Defaults.hapticMergeWindow,
                        onChange: { demo.setHapticMergeWindow($0) },
                    ),
                    unit: "s",
                    note: "Taps held shorter than this answer with one tick instead of two. 0 — always two.",
                ),
            ]
        }

        func bench(_ demo: BNButtonDemoView) -> [BNGalleryKnob] {
            [
                .header("Bench"),
                BNGalleryKnob(label: "Show hit target", control: .toggle(
                    initial: BNButtonDemoView.Defaults.showsHitTarget,
                    onChange: { demo.setShowsHitTarget($0) },
                )),
            ]
        }
    }
#endif
