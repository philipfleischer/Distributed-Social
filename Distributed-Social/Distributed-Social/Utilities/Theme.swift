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
}

extension LinearGradient {
    /// A gentle top-to-bottom wash: sakura pink fading into sky blue over white.
    /// Used as a full-screen background for a light, summery feel.
    static var summerSky: LinearGradient {
        LinearGradient(
            colors: [
                Color.sakuraPink.opacity(0.18),
                Color.softWhite,
                Color.skyBlue.opacity(0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
