//
//  Haptics.swift
//  Distributed-Social
//
//  Tiny helper for tactile feedback on key interactions (swipe commits,
//  queueing, favoriting).
//

import UIKit

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
