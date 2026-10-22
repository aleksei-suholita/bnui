#if canImport(UIKit)
    import BNUI
    import UIKit

    // MARK: - Lens under the finger

    extension BNTabBarDemoView {
        func setLiftScale(_ value: Double) {
            tabBar?.theme.geometry.liftedScale = value
        }

        func setLensStretch(_ value: Double) {
            tabBar?.theme.geometry.lensStretch = value
        }
    }
#endif
