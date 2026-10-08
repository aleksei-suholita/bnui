#if canImport(QuartzCore)
    @testable import BNUICore
    import CoreGraphics
    import QuartzCore
    import Testing

    @Suite("BNSpring physics")
    struct BNSpringPhysicsTests {
        /// iOS 16 is handed the physical form, iOS 17 and later the duration and bounce — the two
        /// have to be one spring. Core Animation runs both, so its own reading of a perceptual
        /// duration and a bounce is the reference.
        @Test(arguments: [(0.4, 0.0), (0.5, 0.3), (0.27, 0.15), (0.45, 0.45)])
        func `is the spring Core Animation makes of the same duration and bounce`(duration: Double, bounce: Double) {
            let physics = BNSpring(duration: duration, bounce: CGFloat(bounce)).physics
            let reference = CASpringAnimation(perceptualDuration: duration, bounce: bounce)
            #expect(abs(physics.mass - reference.mass) < 1e-9)
            #expect(abs(physics.stiffness - reference.stiffness) / reference.stiffness < 1e-6)
            #expect(abs(physics.damping - reference.damping) / reference.damping < 1e-6)
        }

        /// Set at creation and set later alike: a theme is built once, a gallery slider writes to
        /// it on every frame.
        @Test(arguments: [(-0.3, 0.0), (1.4, 1.0), (0.2, 0.2)])
        func `holds bounce between 0 and 1`(given: Double, held: Double) {
            var spring = BNSpring(duration: 0.4, bounce: CGFloat(given))
            #expect(spring.bounce == CGFloat(held))
            spring.bounce = 0.5
            spring.bounce = CGFloat(given)
            #expect(spring.bounce == CGFloat(held))
        }
    }
#endif
