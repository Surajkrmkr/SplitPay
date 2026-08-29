//
//  DimeWidgetsColors.swift
//  DimeWidgets
//
//  Shared color language for all three widgets, matching
//  lib/core/constants/app_colors.dart. Colors adapt automatically for dark
//  mode via dynamic UIColor providers so we stay compatible back to iOS 15.5
//  without relying on asset-catalog named colors.
//

import SwiftUI

enum DimeColors {
    /// App primary accent / income color — #00D09C
    static let income = Color(
        light: UIColor(red: 0x00 / 255, green: 0xD0 / 255, blue: 0x9C / 255, alpha: 1),
        dark: UIColor(red: 0x00 / 255, green: 0xD0 / 255, blue: 0x9C / 255, alpha: 1)
    )

    /// Expense red — #FF6B6B
    static let expense = Color(
        light: UIColor(red: 0xFF / 255, green: 0x6B / 255, blue: 0x6B / 255, alpha: 1),
        dark: UIColor(red: 0xFF / 255, green: 0x6B / 255, blue: 0x6B / 255, alpha: 1)
    )

    /// Secondary / caption gray — #8B93A7
    static let caption = Color(
        light: UIColor(red: 0x8B / 255, green: 0x93 / 255, blue: 0xA7 / 255, alpha: 1),
        dark: UIColor(red: 0x8B / 255, green: 0x93 / 255, blue: 0xA7 / 255, alpha: 1)
    )

    /// Primary text — near-black in light mode, near-white in dark mode.
    static let primaryText = Color(
        light: UIColor(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255, alpha: 1),
        dark: UIColor(white: 0.96, alpha: 1)
    )

    /// Card background.
    static let cardBackground = Color(
        light: .white,
        dark: UIColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)
    )

    /// Light gray track / unfilled gauge & bar color.
    static let track = Color(
        light: UIColor(red: 0xEC / 255, green: 0xED / 255, blue: 0xF0 / 255, alpha: 1),
        dark: UIColor(red: 0x3A / 255, green: 0x3A / 255, blue: 0x3D / 255, alpha: 1)
    )

    /// Near-black gauge fill / bar fill for monochrome elements. Kept as a
    /// fallback for when `accent_color` hasn't been synced yet — the gauge
    /// and bar chart now prefer the user's Settings accent color instead
    /// (see `SharedStore.accentColor`).
    static let fillDark = Color(
        light: UIColor(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255, alpha: 1),
        dark: UIColor(white: 0.92, alpha: 1)
    )

    /// Default accent, matching the app's Emerald preset — used only until
    /// the Flutter side has synced the user's actual selected accent color.
    static let defaultAccent = income
}

extension Color {
    /// Convenience initializer producing a dynamic color that adapts between
    /// light and dark appearances, available back to iOS 13 (well below our
    /// 15.5 deployment target).
    init(light: UIColor, dark: UIColor) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Parses a `#RRGGBB` (or `#AARRGGBB`) hex string as written by
    /// `HomeWidgetService._hex` on the Dart side. Returns `nil` for anything
    /// malformed so callers can fall back to a default color.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard let value = UInt64(s, radix: 16) else { return nil }

        let r, g, b: Double
        switch s.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        case 8:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            return nil
        }
        self = Color(red: r, green: g, blue: b)
    }
}
