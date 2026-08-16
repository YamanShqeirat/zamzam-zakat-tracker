import Charts
import SwiftUI
import WidgetKit

/// Home-screen counterpart of the app's "Zakat given" chart: recorded zakat
/// payments bucketed by Hijri year, with the lifetime total.
struct ZakatGivingWidget: Widget {
    let kind = "ZakatGivingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakatWidgetProvider()) { entry in
            ZakatGivingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Zakat Given")
        .description("What you've given each Hijri year, and your lifetime total.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ZakatGivingWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ZakatWidgetEntry

    private var buckets: [SharedAppGroup.GivingBucket] { entry.snapshot.giving }
    private var lifetime: Decimal { entry.snapshot.lifetimeZakatPaid }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "ZAKAT GIVEN")

            if buckets.isEmpty {
                WidgetEmptyState(
                    symbol: "hands.sparkles",
                    text: "Record a zakat payment and your giving history appears here."
                )
            } else if family == .systemSmall {
                small
            } else {
                medium
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Small: lifetime figure + sparkline bars

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lifetime")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(lifetime.widgetCurrency)
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(WidgetTheme.accent)

            chart(showsAxis: false)

            Text("\(buckets.count) Hijri year\(buckets.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Medium: bars by Hijri year

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lifetime")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(lifetime.widgetCurrency)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(WidgetTheme.accent)
            }

            chart(showsAxis: true)

            Text("Latest: \(latestLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var latestLabel: String {
        guard let last = buckets.last else { return "—" }
        return "\(last.amount.widgetCurrency) in \(last.hijriYear) AH"
    }

    private func chart(showsAxis: Bool) -> some View {
        Chart(buckets, id: \.hijriYear) { bucket in
            BarMark(
                x: .value("Year", "\(bucket.hijriYear)"),
                y: .value("Amount", bucket.amount.widgetDouble)
            )
            .foregroundStyle(WidgetTheme.accent)
            .cornerRadius(3)
        }
        .chartYAxis {
            if showsAxis {
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
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview(as: .systemSmall) {
    ZakatGivingWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemMedium) {
    ZakatGivingWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}
