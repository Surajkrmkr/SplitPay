//
//  DimeWidgetsShared.swift
//  DimeWidgets
//
//  Shared helpers used by all three widgets: the App Group UserDefaults
//  reader, the recent-transaction model, and a couple of small reusable
//  SwiftUI views (card container, empty state pill, deep-link URLs).
//

import SwiftUI
import WidgetKit

/// App Group identifier the `home_widget` Flutter plugin writes to on iOS.
/// Must match `group.com.splitpay.expensetracker` used on the Dart side
/// (see lib/core/services/home_widget_service.dart) and the entitlements
/// of both the Runner app target and this extension target.
let appGroupId = "group.com.splitpay.expensetracker"

/// Deep-link URL scheme used to open specific screens in the host app when a
/// widget is tapped. Matches the `dimeflow://widget/<key>` scheme registered
/// in `Info.plist` and handled on the Dart side by
/// `HomeWidgetLaunchHandler` (lib/core/services/home_widget_launch_handler.dart)
/// — and the equivalent Android `PendingIntent` URIs in the native widget
/// providers, which must stay in sync with these.
enum DimeDeepLink {
    static let budget = URL(string: "dimeflow://widget/budget")
    static let transactions = URL(string: "dimeflow://widget/transactions")
    static let insights = URL(string: "dimeflow://widget/insights")
}

/// Thin wrapper over the shared UserDefaults suite written by `home_widget`.
enum SharedStore {
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func string(_ key: String) -> String? {
        defaults?.string(forKey: key)
    }

    static func string(_ key: String, default def: String) -> String {
        string(key) ?? def
    }

    static func bool(_ key: String) -> Bool {
        string(key) == "true"
    }

    /// The user's Settings accent color (`accent_color`, written by
    /// `HomeWidgetService`), falling back to the app's default accent if it
    /// hasn't synced yet or fails to parse.
    static var accentColor: Color {
        string("accent_color").flatMap { Color(hex: $0) } ?? DimeColors.defaultAccent
    }
}

/// Mirrors the `recent_transactions` JSON array written by the Flutter side:
/// `{ id, amount, type, note, date }`. `amount`/`type` here are the raw,
/// already-formatted display strings (amount includes sign + currency
/// symbol), matching the shared spec.
struct RecentTransaction: Codable, Identifiable {
    let id: String
    let amount: String
    let type: String
    let note: String
    let date: String

    var isIncome: Bool { type == "income" }
}

enum RecentTransactionsDecoder {
    static func decode() -> [RecentTransaction] {
        guard let json = SharedStore.string("recent_transactions"),
              let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([RecentTransaction].self, from: data)) ?? []
    }
}

/// Shared rounded card container matching the app's large-corner-radius
/// widget language. Uses `containerBackground(for:.widget:)` on iOS 17+ (the
/// modern, recommended way to set widget backgrounds) and falls back to a
/// plain `.background()` + corner radius on iOS 15/16, since
/// `containerBackground` isn't available before iOS 17 and our deployment
/// target is 15.5.
struct WidgetCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content
                .containerBackground(DimeColors.cardBackground, for: .widget)
        } else {
            content
                .padding()
                .background(DimeColors.cardBackground)
        }
    }
}

/// Small pill button used by empty states ("+ Add Budget" / "+ New Expense").
struct DimePillLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(DimeColors.income)
            )
    }
}

/// Small decorative outline-ring glyph used in the corner of the Overall
/// Budget widget — purely cosmetic, not a data gauge.
struct RingGlyph: View {
    var diameter: CGFloat = 16

    var body: some View {
        Circle()
            .strokeBorder(DimeColors.primaryText.opacity(0.6), lineWidth: 1.6)
            .frame(width: diameter, height: diameter)
    }
}

/// Uppercase, letter-spaced caption text matching the app's secondary/gray
/// caption style.
struct CaptionText: View {
    let text: String
    var size: CGFloat = 10

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(DimeColors.caption)
            .tracking(0.6)
    }
}
