//
//  Theme.swift
//  Distributed-Social
//
//  Summery Japanese palette: soft white, sky blue, and sakura pink.
//

import SwiftUI

extension Color {
    /// Sky blue — primary accent (matches the AccentColor asset).
    static let skyBlue = Color(red: 0.486, green: 0.773, blue: 0.910)
    /// A slightly deeper sky blue for text/icons that need more contrast.
    static let deepSky = Color(red: 0.243, green: 0.565, blue: 0.722)
    /// Sakura (cherry blossom) pink — secondary accent.
    static let sakuraPink = Color(red: 1.0, green: 0.718, blue: 0.773)
    /// A softer, near-white background tint.
    static let softWhite = Color(red: 0.980, green: 0.992, blue: 1.0)
    /// Dimmed light blue for secondary text on the black background.
    static let inkSecondary = Color.skyBlue.opacity(0.62)

    /// Deterministic pastel hue derived from a UUID, so every media item
    /// gets its own stable artwork color across launches.
    static func artworkHue(for id: UUID, offset: Double = 0) -> Color {
        var seed = 0
        for scalar in id.uuidString.unicodeScalars {
            seed = (seed &* 31 &+ Int(scalar.value)) & 0xFFFFFF
        }
        let hue = (Double(seed % 360) / 360 + offset).truncatingRemainder(dividingBy: 1)
        return Color(hue: hue, saturation: 0.50, brightness: 0.92)
    }
}

extension LinearGradient {
    /// Full-screen wash: black with a hint of midnight blue toward the
    /// bottom. Light-blue text sits on top of it everywhere.
    static var summerSky: LinearGradient {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.016, green: 0.035, blue: 0.059),
                Color(red: 0.031, green: 0.071, blue: 0.118)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// A reusable background view applying the summery gradient behind content.
struct SummerBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LinearGradient.summerSky.ignoresSafeArea())
    }
}

extension View {
    /// Applies the app's summery gradient background.
    func summerBackground() -> some View {
        modifier(SummerBackground())
    }
}
