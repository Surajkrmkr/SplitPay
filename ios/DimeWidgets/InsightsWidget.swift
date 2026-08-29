//
//  InsightsWidget.swift
//  DimeWidgets
//
//  Reads in_* keys written by lib/core/services/home_widget_service.dart.
//

import SwiftUI
import WidgetKit

struct InsightsEntry: TimelineEntry {
    let date: Date
    let hasData: Bool
    let monthTotal: String
    let currency: String
    /// 5 buckets covering the current calendar month (days 1-7, 8-14, 15-21,
    /// 22-28, 29-31), in_bucket0...in_bucket4.
    let buckets: [Double]
    let accentColor: Color
}

struct InsightsProvider: TimelineProvider {
    func placeholder(in context: Context) -> InsightsEntry {
        .init(date: Date(), hasData: true, monthTotal: "0.00", currency: "₹",
              buckets: [4, 9, 2, 6, 1], accentColor: DimeColors.defaultAccent)
    }

    func getSnapshot(in context: Context, completion: @escaping (InsightsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InsightsEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> InsightsEntry {
        let hasData = SharedStore.bool("in_has_data")
        let buckets = (0...4).map { Double(SharedStore.string("in_bucket\($0)", default: "0")) ?? 0 }
        return InsightsEntry(
            date: Date(),
            hasData: hasData,
            monthTotal: SharedStore.string("in_month_total", default: "0.00"),
            currency: SharedStore.string("currency", default: "₹"),
            buckets: buckets,
            accentColor: SharedStore.accentColor
        )
    }
}

/// 5-bar bar chart, one per ~week of the current month, scaled against the
/// month's max bucket value. Bars keep a small minimum visible height even
/// at zero, and render light gray when zero vs. the user's accent color
/// when non-zero.
struct MonthBarChart: View {
    let buckets: [Double]
    let accentColor: Color

    private let bucketLabels = ["W1", "W2", "W3", "W4", "W5"]
    private let barMaxHeight: CGFloat = 46
    private let barMinHeight: CGFloat = 4

    private var maxValue: Double { max(buckets.max() ?? 0, 1) }

    // Both the y-axis labels and the bars-only zone share this fixed height,
    // aligned by their tops, so "0" lines up with the bars' baseline instead
    // of collapsing onto the label row underneath.
    private let axisWidth: CGFloat = 14
    private let axisSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .top, spacing: axisSpacing) {
                VStack {
                    Text("10").font(.system(size: 8)).foregroundColor(DimeColors.caption)
                    Spacer(minLength: 0)
                    Text("0").font(.system(size: 8)).foregroundColor(DimeColors.caption)
                }
                .frame(width: axisWidth, height: barMaxHeight)

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<bucketLabels.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(buckets[i] > 0 ? accentColor : DimeColors.track)
                            .frame(width: 10, height: barHeight(for: buckets[i]))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: barMaxHeight, alignment: .bottom)
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: axisWidth + axisSpacing)
                HStack(spacing: 0) {
                    ForEach(0..<bucketLabels.count, id: \.self) { i in
                        Text(bucketLabels[i])
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(DimeColors.caption)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func barHeight(for value: Double) -> CGFloat {
        guard value > 0 else { return barMinHeight }
        let ratio = CGFloat(value / maxValue)
        return max(barMinHeight, ratio * barMaxHeight)
    }
}

struct InsightsWidgetEntryView: View {
    var entry: InsightsEntry

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 6) {
                CaptionText(text: "Spent This Month")
                Text("\(entry.currency)\(entry.monthTotal)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DimeColors.primaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                MonthBarChart(buckets: entry.buckets, accentColor: entry.accentColor)
                    .frame(maxWidth: .infinity)

                if !entry.hasData {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No transactions this month")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(DimeColors.caption)
                        DimePillLabel(text: "+ New Expense")
                    }
                }
            }
            .padding(14)
        }
        .widgetURL(DimeDeepLink.insights)
    }
}

struct InsightsWidget: Widget {
    let kind: String = "InsightsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InsightsProvider()) { entry in
            InsightsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Monthly Insights")
        .description("Your spending pattern for the current month.")
        .supportedFamilies([.systemSmall])
    }
}
