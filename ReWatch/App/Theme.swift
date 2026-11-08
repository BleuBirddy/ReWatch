import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The app's colour themes. Picked from the palette menu in the library and
/// remembered with @AppStorage("theme"), so every screen reads the same value.
enum AppTheme: String, CaseIterable, Identifiable {
    /// The ReWatch look: #ADFFFF on #9B666B, matching the icon.
    case standard
    /// Near-black, for watching in a dark room.
    case dark
    /// Amber on brown: no blue light, for late at night.
    case warm

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: "ReWatch"
        case .dark: "Dark"
        case .warm: "Warm"
        }
    }

    /// Screen background.
    var background: Color {
        switch self {
        case .standard: Color(hex: 0x9B666B)
        case .dark: Color(hex: 0x0E0E10)
        case .warm: Color(hex: 0x2A1B12)
        }
    }

    /// List rows and cards. On ReWatch it's darker than the background on
    /// purpose: #ADFFFF on #9B666B is just under the 4.5:1 contrast that
    /// small text needs, and on #7E4E53 it's comfortably over.
    var surface: Color {
        switch self {
        case .standard: Color(hex: 0x7E4E53)
        case .dark: Color(hex: 0x1C1C1F)
        case .warm: Color(hex: 0x3B281C)
        }
    }

    /// Buttons, icons and text.
    var accent: Color {
        switch self {
        case .standard, .dark: Color(hex: 0xADFFFF)
        case .warm: Color(hex: 0xFFC98B)
        }
    }

    /// Navigation bar titles are UIKit, outside SwiftUI's styling, so they
    /// are set through UIAppearance. That only affects bars created
    /// afterwards, which is why LibraryView rebuilds its NavigationStack
    /// (`.id(theme)`) when the theme changes.
    func applyToNavigationBars() {
        #if os(iOS)
        let text = UIColor(accent)
        let opaque = UINavigationBarAppearance()
        opaque.configureWithOpaqueBackground()
        opaque.backgroundColor = UIColor(background)
        opaque.shadowColor = .clear
        opaque.titleTextAttributes = [.foregroundColor: text]
        opaque.largeTitleTextAttributes = [.foregroundColor: text]

        let edge = opaque.copy()
        edge.configureWithTransparentBackground()
        edge.titleTextAttributes = opaque.titleTextAttributes
        edge.largeTitleTextAttributes = opaque.largeTitleTextAttributes

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = opaque
        bar.compactAppearance = opaque
        bar.scrollEdgeAppearance = edge
        bar.tintColor = text
        #endif
        // The Mac has no large navigation titles to colour.
    }
}

extension Color {
    /// Color(hex: 0x9B666B), so themes read like the hex codes they came from.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
