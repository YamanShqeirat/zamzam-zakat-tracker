import Charts
import SwiftUI
import WidgetKit

/// Home-screen counterpart of the app's "Wealth vs nisab" chart: zakatable
/// wealth over time against the (moving) nisab threshold.
struct WealthTrendWidget: Widget {
    let kind = "WealthTrendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakatWidgetProvider()) { entry in
            WealthTrendWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wealth vs Nisab")
        .description("Your zakatable wealth plotted against the nisab threshold.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WealthTrendWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ZakatWidgetEntry

    private var points: [SharedAppGroup.WealthPoint] { entry.snapshot.wealthHistory }

    /// Change since the earliest stored point — the same figure the app's
    /// "Wealth Δ" tile shows.
    private var change: Decimal? {
        guard let first = points.first?.wealth, let last = points.last?.wealth else { return nil }
        return last - first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "WEALTH VS NISAB", trailing: changeLabel)

            if points.count < 2 {
                WidgetEmptyState(
                    symbol: "chart.xyaxis.line",
                    text: "Your wealth trajectory appears here as daily snapshots accumulate."
                )
            } else {
                headline
                chart
                legend
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var changeLabel: String? {
        change.map { $0.widgetSignedCurrency }
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(entry.snapshot.totalZakatableWealth.widgetCurrency)
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(entry.snapshot.isAboveNisab ? "above nisab" : "below nisab")
                .font(.caption2)
                .foregroundStyle(entry.snapshot.isAboveNisab ? WidgetTheme.accent : .secondary)
            Spacer(minLength: 0)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(points, id: \.date) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("Wealth", p.wealth.widgetDouble)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [WidgetTheme.accent.opacity(0.35), WidgetTheme.accent.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }
            ForEach(points, id: \.date) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Wealth", p.wealth.widgetDouble)
                )
                .foregroundStyle(WidgetTheme.accent)
                .interpolationMethod(.monotone)
            }
            ForEach(points, id: \.date) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Nisab", p.nisab.widgetDouble)
                )
                .foregroundStyle(WidgetTheme.nisab)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(widgetCompactCurrency(v))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            WidgetLegendDot(color: WidgetTheme.accent, label: "Zakatable wealth")
            WidgetLegendDot(color: WidgetTheme.nisab, label: "Nisab", dashed: true)
            Spacer(minLength: 0)
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
    }
}

/// Legend swatch — solid dot for a line, a dashed rule for the nisab.
struct WidgetLegendDot: View {
    let color: Color
    let label: String
    var dashed: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if dashed {
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 1.5)
                    .mask(
                        HStack(spacing: 2) {
                            Rectangle().frame(width: 4)
                            Rectangle().frame(width: 4)
                        }
                    )
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(label)
        }
    }
}

#Preview(as: .systemMedium) {
    WealthTrendWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemLarge) {
    WealthTrendWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
}
