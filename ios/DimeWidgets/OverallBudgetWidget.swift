//
//  OverallBudgetWidget.swift
//  DimeWidgets
//
//  Reads ob_* keys written by lib/core/services/home_widget_service.dart.
//

import SwiftUI
import WidgetKit

struct OverallBudgetEntry: TimelineEntry {
    let date: Date
    let hasData: Bool
    let periodLabel: String
    let percent: Int
    let spent: String
    let limit: String
    let remaining: String
    let currency: String
}

struct OverallBudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> OverallBudgetEntry {
        .init(date: Date(), hasData: true, periodLabel: "1 - 31 AUG", percent: 42,
              spent: "12,252", limit: "30,000", remaining: "17,748", currency: "₹")
    }

    func getSnapshot(in context: Context, completion: @escaping (OverallBudgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OverallBudgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> OverallBudgetEntry {
        let hasData = SharedStore.bool("ob_has_data")
        let percent = Int(SharedStore.string("ob_percent", default: "0")) ?? 0
        return OverallBudgetEntry(
            date: Date(),
            hasData: hasData,
            periodLabel: SharedStore.string("ob_period_label", default: ""),
            percent: max(0, min(100, percent)),
            spent: SharedStore.string("ob_spent", default: "0"),
            limit: SharedStore.string("ob_limit", default: "0"),
            remaining: SharedStore.string("ob_remaining", default: "0"),
            currency: SharedStore.string("currency", default: "₹")
        )
    }
}

/// Thick semicircular/arc "speedometer" gauge, ~270° opening at the bottom,
/// track in light gray, filled portion in the user's accent color
/// proportional to percent.
///
/// Fixed to an explicit `diameter` (rather than filling whatever flexible
/// space its parent offers) so the ring never grows large/thick enough to
/// crowd out the amount text centered inside it.
///
/// The track only draws its *remaining* (untraveled) portion — starting
/// exactly where the fill arc ends — rather than drawing the full 270°
/// underneath the fill. That way the two arcs' round caps meet at a single
/// shared point instead of the fill's rounded tip overlapping a flat
/// mid-stroke point on the track, which is what produced the stray
/// "floating dot" artifact where the two colors met.
struct BudgetArcGauge: View {
    let percent: Int
    var accentColor: Color = DimeColors.defaultAccent
    var diameter: CGFloat = 76
    var lineWidth: CGFloat = 9

    private let startAngle: Double = 135
    private let totalDegrees: Double = 270

    var body: some View {
        let totalFraction = totalDegrees / 360
        let fillFraction = totalFraction * (Double(percent.clamped(0, 100)) / 100)

        ZStack {
            Circle()
                .trim(from: fillFraction, to: totalFraction)
                .stroke(DimeColors.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(startAngle))

            Circle()
                .trim(from: 0, to: fillFraction)
                .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(startAngle))
        }
        .frame(width: diameter, height: diameter)
    }
}

private extension Int {
    func clamped(_ lower: Int, _ upper: Int) -> Int { Swift.min(Swift.max(self, lower), upper) }
}

struct OverallBudgetWidgetEntryView: View {
    var entry: OverallBudgetEntry

    var body: some View {
        WidgetCard {
            if entry.hasData {
                dataView
            } else {
                emptyView
            }
        }
        .widgetURL(DimeDeepLink.budget)
    }

    private var dataView: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                Text(entry.periodLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DimeColors.primaryText)
                Spacer()
                RingGlyph()
            }

            CaptionText(text: "SPENT: \(entry.percent)%")
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                BudgetArcGauge(percent: entry.percent, accentColor: SharedStore.accentColor)

                VStack(spacing: 1) {
                    Text("\(entry.currency)\(entry.remaining)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DimeColors.primaryText)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("left this month")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(DimeColors.caption)
                }
                .frame(width: 56)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text(entry.spent)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DimeColors.caption)
                Spacer()
                Text(entry.limit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DimeColors.caption)
            }
        }
        .padding(14)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("No budgets yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DimeColors.caption)
            DimePillLabel(text: "+ Add Budget")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }
}

struct OverallBudgetWidget: Widget {
    let kind: String = "OverallBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OverallBudgetProvider()) { entry in
            OverallBudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Overall Budget")
        .description("See how much of your monthly budget is left.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
