//
//  Haptics.swift
//  Distributed-Social
//
//  Tiny helper for tactile feedback on key interactions (swipe commits,
//  queueing, favoriting).
//

import UIKit

enum Haptics {
    // Reused generators: allocating one per tap re-engages the Taptic
    // Engine cold every time (slower response, more power).
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func light() {
        lightGenerator.impactOccurred()
    }

    static func medium() {
        mediumGenerator.impactOccurred()
    }

    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }
}
