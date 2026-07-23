//
//  Haptics.swift
//  Distributed-Social
//

import UIKit

enum Haptics {
    // Reused generators: allocating one per tap re-engages the Taptic
    // Engine cold every time (slower response, more power).
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Pre-warms the Taptic Engine at launch so the first haptic fires
    /// immediately rather than after a ~15 ms cold-start delay.
    static func prepareAll() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        notificationGenerator.prepare()
    }

    static func light() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare() // ready for the next tap
    }

    static func medium() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    static func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
}
