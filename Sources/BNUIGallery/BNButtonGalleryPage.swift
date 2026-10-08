#if DEBUG && canImport(UIKit)
    import BNUI
    import UIKit

    /// Gallery page for ``BNButton``.
    ///
    /// Kit rule: a control is not done until it has a page of its own. For the button that
    /// page is also the calibration bench — the motion numbers in the theme are placeholders until
    /// someone has moved these sliders on a device with a system button next to them.
    struct BNButtonGalleryPage: GalleryPage {
        let title = "Button"
        let symbol = "capsule"
        let summary: String? = "Styles, materials, press motion and refusal"
        let fillsDemoArea = true
        let demoAreaFraction: CGFloat = 0.42

        func makeDemoView() -> UIView {
            BNButtonDemoView()
        }

        func resetDemo(_ demoView: UIView) {
            (demoView as? BNButtonDemoView)?.reset()
        }

        func makeKnobs(for demoView: UIView) -> [GalleryKnob] {
            guard let demo = demoView as? BNButtonDemoView else { return [] }
            return content(demo) + appearance(demo) + motion(demo) + release(demo) + state(demo)
                + refusal(demo) + haptics(demo) + bench(demo) + environment(demo)
        }
    }

    // MARK: - Sections

    //
    // One builder per section of the inspector, in an extension so the page itself reads as the
    // list of sections rather than as the knobs in them.

    private extension BNButtonGalleryPage {
        func content(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                .header("Content"),
                GalleryKnob(label: "Title", control: .textField(
                    initial: BNButtonDemoView.Defaults.title,
                    onChange: { demo.setTitle($0) },
                )),
                GalleryKnob(label: "Content", control: .segmented(
                    options: ["Title", "+Lead", "+Trail", "Icon", "Custom"],
                    initial: BNButtonDemoView.Defaults.contentIndex,
                    onChange: { demo.setContentKind(index: $0) },
                )),
                GalleryKnob(label: "Icon", control: .segmented(
                    options: ["Gear", "Plus", "Chevron", "Tall", "Wide", "Wider"],
                    initial: BNButtonDemoView.Defaults.iconIndex,
                    onChange: { demo.setIcon(index: $0) },
                )),
                GalleryKnob(label: "Long title", control: .toggle(
                    initial: BNButtonDemoView.Defaults.usesLongTitle,
                    onChange: { demo.setLongTitle($0) },
                )),
                GalleryKnob(label: "Title behavior", control: .segmented(
                    options: ["Truncate", "Wrap 2", "Wrap ∞"],
                    initial: BNButtonDemoView.Defaults.titleBehaviorIndex,
                    onChange: { demo.setTitleBehavior(index: $0) },
                )),
            ]
        }

        func appearance(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                .header("Appearance"),
                GalleryKnob(label: "Style", control: .segmented(
                    options: ["Primary", "Secondary", "Ghost", "Destructive"],
                    initial: BNButtonDemoView.Defaults.styleIndex,
                    onChange: { demo.setStyle(index: $0) },
                )),
                GalleryKnob(label: "Material", control: .segmented(
                    options: BNButtonDemoView.materials.map(\.name),
                    initial: BNButtonDemoView.Defaults.materialIndex,
                    onChange: { demo.setMaterial(index: $0) },
                )),
                GalleryKnob(label: "Corner", control: .segmented(
                    options: ["Capsule", "Rounded"],
                    initial: BNButtonDemoView.Defaults.cornerIndex,
                    onChange: { demo.setCorner(index: $0) },
                )),
                GalleryKnob(label: "Size", control: .segmented(
                    options: ["S", "M", "L"],
                    initial: BNButtonDemoView.Defaults.sizeIndex,
                    onChange: { demo.setSize(index: $0) },
                )),
                GalleryKnob(label: "Width", control: .segmented(
                    options: ["Hug", "Fill", "200"],
                    initial: BNButtonDemoView.Defaults.widthIndex,
                    onChange: { demo.setWidth(index: $0) },
                )),
            ]
        }

        func motion(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                .header("Motion"),
                GalleryKnob(
                    label: "Pressed scale",
                    control: .slider(
                        min: 0.90, max: 1.0,
                        initial: BNButtonDemoView.Defaults.pressedScale,
                        onChange: { demo.setPressedScale($0) },
                    ),
                    unit: "×",
                    note: "Glass draws its own press, so this section acts on Glass static, Blur and Solid only.",
                ),
                GalleryKnob(
                    label: "Press duration",
                    control: .slider(
                        min: 0.06, max: 0.40,
                        initial: BNButtonDemoView.Defaults.pressDuration,
                        onChange: { demo.setPressDuration($0) },
                    ),
                    unit: "s",
                ),
            ]
        }

        /// Still the Motion section, apart only for length: the return after the finger lifts,
        /// springier the quicker the press was.
        func release(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                GalleryKnob(
                    label: "Fast release bounce",
                    control: .slider(
                        min: 0, max: 0.7,
                        initial: BNButtonDemoView.Defaults.fastBounce,
                        onChange: { demo.setFastBounce($0) },
                    ),
                    note: "Overshoot of the return after an instant click.",
                ),
                GalleryKnob(
                    label: "Slow release bounce",
                    control: .slider(
                        min: 0, max: 0.4,
                        initial: BNButtonDemoView.Defaults.slowBounce,
                        onChange: { demo.setSlowBounce($0) },
                    ),
                    note: "Overshoot of the return after a press held past the snap window.",
                ),
                GalleryKnob(
                    label: "Snap window",
                    control: .slider(
                        min: 0.05, max: 0.60,
                        initial: BNButtonDemoView.Defaults.snapWindow,
                        onChange: { demo.setSnapWindow($0) },
                    ),
                    unit: "s",
                    note: "How long a press may last and still count as a click. In between, the return blends fast into slow.",
                ),
                GalleryKnob(
                    label: "Max release velocity",
                    control: .slider(
                        min: 0, max: 12,
                        initial: BNButtonDemoView.Defaults.maxVelocity,
                        onChange: { demo.setMaxVelocity($0) },
                    ),
                    note: "The push an instant click gives the return; a held press gives none.",
                ),
            ]
        }

        func state(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                .header("State"),
                GalleryKnob(label: "Status", control: .segmented(
                    options: ["Enabled", "Disabled", "Loading"],
                    initial: BNButtonDemoView.Defaults.statusIndex,
                    onChange: { demo.setStatus(index: $0) },
                )),
                GalleryKnob(
                    label: "Cooldown",
                    control: .slider(
                        min: 0, max: 1,
                        initial: BNButtonDemoView.Defaults.cooldown,
                        onChange: { demo.setCooldown($0) },
                    ),
                    unit: "s",
                    note: "A tap this soon after the last one that fired is swallowed, silently. 0 — off.",
                ),
            ]
        }

        /// Set Status to Disabled and tap the button to see these.
        func refusal(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                .header("Refusal"),
                GalleryKnob(
                    label: "Refuse disabled taps",
                    control: .toggle(
                        initial: BNButtonDemoView.Defaults.rejectionEnabled,
                        onChange: { demo.setRejection($0) },
                    ),
                    note: "Set Status to Disabled, then tap the button.",
                ),
                GalleryKnob(
                    label: "Refusal travel",
                    control: .slider(
                        min: 0, max: 16,
                        initial: BNButtonDemoView.Defaults.rejectionTravel,
                        onChange: { demo.setRejectionTravel($0) },
                    ),
                    unit: "pt",
                    note: "How far the shake goes sideways. 0 — no shake.",
                ),
                GalleryKnob(
                    label: "Refusal hold",
                    control: .slider(
                        min: 0, max: 1.2,
                        initial: BNButtonDemoView.Defaults.rejectionHold,
                        onChange: { demo.setRejectionHold($0) },
                    ),
                    unit: "s",
                    note: "How long the flash stays at full strength before it fades.",
                ),
                GalleryKnob(
                    label: "Refusal flash",
                    control: .slider(
                        min: 0, max: 1,
                        initial: BNButtonDemoView.Defaults.rejectionFlashAlpha,
                        onChange: { demo.setRejectionFlashAlpha($0) },
                    ),
                    note: "Peak strength of the red flash. 0 — no flash.",
                ),
                GalleryKnob(
                    label: "Refusal haptic",
                    control: .toggle(
                        initial: BNButtonDemoView.Defaults.rejectionHaptic,
                        onChange: { demo.setRejectionHaptic($0) },
                    ),
                    note: "The error buzz. Off — the refusal is seen, not felt.",
                ),
            ]
        }

        func haptics(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                .header("Haptics"),
                GalleryKnob(label: "Haptics", control: .toggle(
                    initial: BNButtonDemoView.Defaults.hapticsEnabled,
                    onChange: { demo.setHapticsEnabled($0) },
                )),
                GalleryKnob(
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

        func bench(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                .header("Bench"),
                GalleryKnob(label: "Show hit target", control: .toggle(
                    initial: BNButtonDemoView.Defaults.showsHitTarget,
                    onChange: { demo.setShowsHitTarget($0) },
                )),
                GalleryKnob(label: "System button beside", control: .toggle(
                    initial: BNButtonDemoView.Defaults.showsSystemButton,
                    onChange: { demo.setShowsSystemButton($0) },
                )),
            ]
        }

        /// Forcing the accessibility settings here rather than in Settings.app: two checklist
        /// items depend on them, and a trip out of the app is how those items get skipped.
        func environment(_ demo: BNButtonDemoView) -> [GalleryKnob] {
            [
                .header("Accessibility"),
                GalleryKnob(label: "Reduce Motion", control: .toggle(
                    initial: BNButtonDemoView.Defaults.forcedAccessibility,
                    onChange: { demo.setReduceMotion($0) },
                )),
                GalleryKnob(label: "Reduce Transparency", control: .toggle(
                    initial: BNButtonDemoView.Defaults.forcedAccessibility,
                    onChange: { demo.setReduceTransparency($0) },
                )),
            ]
        }
    }
#endif
