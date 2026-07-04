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
    /// Near-black used for secondary text so it stays readable on the
    /// light-blue background (regular `.secondary` grey blends too much).
    static let inkSecondary = Color.black.opacity(0.65)

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
    /// Full-screen wash: a light summer-day blue, slightly deeper toward the
    /// bottom. Black text sits on top of it everywhere for readability.
    static var summerSky: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.894, green: 0.949, blue: 0.984),
                Color(red: 0.827, green: 0.914, blue: 0.965),
                Color(red: 0.761, green: 0.878, blue: 0.949)
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
