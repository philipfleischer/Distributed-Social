//
//  Theme.swift
//  Distributed-Social
//
//  Selectable color themes. The chosen theme persists via UserDefaults and
//  drives the background gradient, text colors, and light/dark chrome.
//

import SwiftUI
import Combine

// MARK: - Base palette (used by artwork tiles and the default theme)

extension Color {
    /// Sky blue — accent of the classic theme (matches the AccentColor asset).
    static let skyBlue = Color(red: 0.486, green: 0.773, blue: 0.910)
    /// A slightly deeper sky blue.
    static let deepSky = Color(red: 0.243, green: 0.565, blue: 0.722)
    /// Sakura (cherry blossom) pink.
    static let sakuraPink = Color(red: 1.0, green: 0.718, blue: 0.773)
    /// A softer, near-white background tint.
    static let softWhite = Color(red: 0.980, green: 0.992, blue: 1.0)
    /// Dimmed light blue (legacy secondary text; themed views use
    /// `AppTheme.textSecondary` instead).
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

// MARK: - Selectable themes

enum AppTheme: String, CaseIterable, Identifiable {
    case spotify
    case ember
    case skyNight
    case skyDay
    case sakura
    case evergreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .ember: return "Black & Orange"
        case .skyNight: return "Black & Sky Blue"
        case .skyDay: return "Sky Blue & Black"
        case .sakura: return "Sakura Pink"
        case .evergreen: return "White & Green"
        }
    }

    /// Main text / icon / accent color.
    var textPrimary: Color {
        switch self {
        case .spotify: return Color(red: 0.114, green: 0.725, blue: 0.329) // #1DB954
        case .ember: return Color(red: 1.0, green: 0.584, blue: 0.0)
        case .skyNight: return .skyBlue
        case .skyDay: return .black
        case .sakura: return .white
        case .evergreen: return Color(red: 0.043, green: 0.373, blue: 0.208)
        }
    }

    /// Dimmed variant for secondary text.
    var textSecondary: Color {
        switch self {
        case .sakura: return Color.white.opacity(0.78)
        case .skyDay: return Color.black.opacity(0.60)
        default: return textPrimary.opacity(0.62)
        }
    }

    /// Color for the currently playing row — must stand out from textPrimary.
    var textHighlight: Color {
        switch self {
        case .sakura: return .black
        case .evergreen: return .black
        case .skyDay: return .deepSky
        default: return .white
        }
    }

    /// Whether system chrome (nav bars, forms, sheets) renders dark or light.
    var colorScheme: ColorScheme {
        switch self {
        case .evergreen, .skyDay: return .light
        default: return .dark
        }
    }

    /// Background gradient colors, top to bottom.
    var backgroundColors: [Color] {
        switch self {
        case .spotify:
            return [.black,
                    Color(red: 0.008, green: 0.047, blue: 0.020),
                    Color(red: 0.016, green: 0.090, blue: 0.043)]
        case .ember:
            return [.black,
                    Color(red: 0.071, green: 0.035, blue: 0.0),
                    Color(red: 0.118, green: 0.059, blue: 0.0)]
        case .skyNight:
            return [.black,
                    Color(red: 0.016, green: 0.035, blue: 0.059),
                    Color(red: 0.031, green: 0.071, blue: 0.118)]
        case .skyDay:
            return [Color(red: 0.894, green: 0.949, blue: 0.984),
                    Color(red: 0.827, green: 0.914, blue: 0.965),
                    Color(red: 0.761, green: 0.878, blue: 0.949)]
        case .sakura:
            return [Color(red: 0.925, green: 0.494, blue: 0.612),
                    Color(red: 0.878, green: 0.412, blue: 0.545)]
        case .evergreen:
            return [.white,
                    Color(red: 0.937, green: 0.965, blue: 0.941)]
        }
    }

    var background: LinearGradient {
        LinearGradient(colors: backgroundColors, startPoint: .top, endPoint: .bottom)
    }

    /// Fill for small pill controls (e.g. the speed chip).
    var chipFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }
}

/// Holds the active theme and persists the selection.
final class ThemeStore: ObservableObject {
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? ""
        theme = AppTheme(rawValue: raw) ?? .skyNight
    }
}

// MARK: - Background modifier

/// Applies the active theme's full-screen background gradient.
struct SummerBackground: ViewModifier {
    @EnvironmentObject var themeStore: ThemeStore

    func body(content: Content) -> some View {
        content
            .background(themeStore.theme.background.ignoresSafeArea())
    }
}

extension View {
    /// Applies the app's themed background.
    func summerBackground() -> some View {
        modifier(SummerBackground())
    }
}
