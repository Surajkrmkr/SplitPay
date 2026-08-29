//
//  RecentTransactionsWidget.swift
//  DimeWidgets
//
//  Reads rt_* keys + the `recent_transactions` JSON array written by
//  lib/core/services/home_widget_service.dart.
//

import SwiftUI
import WidgetKit

struct RecentTransactionsEntry: TimelineEntry {
    let date: Date
    let hasData: Bool
    let netWeek: String
    let currency: String
    let transactions: [RecentTransaction]
}

struct RecentTransactionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentTransactionsEntry {
        .init(date: Date(), hasData: true, netWeek: "0.00", currency: "₹", transactions: [
            RecentTransaction(id: "1", amount: "+₹500.00", type: "income", note: "Salary", date: ""),
            RecentTransaction(id: "2", amount: "-₹120.00", type: "expense", note: "Groceries", date: ""),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentTransactionsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentTransactionsEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> RecentTransactionsEntry {
        let hasData = SharedStore.bool("rt_has_data")
        let netRaw = SharedStore.string("rt_net_week", default: "0.00")
        let currency = SharedStore.string("currency", default: "₹")
        return RecentTransactionsEntry(
            date: Date(),
            hasData: hasData,
            netWeek: Self.formattedNet(netRaw, currency: currency),
            currency: currency,
            transactions: Array(RecentTransactionsDecoder.decode().prefix(3))
        )
    }

    /// Formats the signed decimal `rt_net_week` string with the currency
    /// symbol: plain `₹0.00` at zero, `+₹123.00` / `-₹123.00` otherwise.
    private static func formattedNet(_ raw: String, currency: String) -> String {
        let value = Double(raw) ?? 0
        let magnitude = abs(value)
        let formatted = String(format: "%.2f", magnitude)
        if value > 0 { return "+\(currency)\(formatted)" }
        if value < 0 { return "-\(currency)\(formatted)" }
        return "\(currency)\(formatted)"
    }
}

struct RecentTransactionsWidgetEntryView: View {
    var entry: RecentTransactionsEntry

    var body: some View {
        WidgetCard {
            if entry.hasData && !entry.transactions.isEmpty {
                dataView
            } else {
                emptyView
            }
        }
        .widgetURL(DimeDeepLink.transactions)
    }

    private var dataView: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                CaptionText(text: "Net This Week")
                Text(entry.netWeek)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DimeColors.primaryText)
            }

            VStack(spacing: 6) {
                ForEach(entry.transactions) { tx in
                    HStack {
                        Text(tx.note)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DimeColors.primaryText)
                            .lineLimit(1)
                        Spacer()
                        Text(tx.amount)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(tx.isIncome ? DimeColors.income : DimeColors.expense)
                    }
                }
            }
        }
        .padding(14)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("No Recent Expenses")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DimeColors.caption)
            DimePillLabel(text: "+ New Expense")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }
}

struct RecentTransactionsWidget: Widget {
    let kind: String = "RecentTransactionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentTransactionsProvider()) { entry in
            RecentTransactionsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recent Transactions")
        .description("Your net spend this week and latest transactions.")
        .supportedFamilies([.systemMedium])
    }
}
