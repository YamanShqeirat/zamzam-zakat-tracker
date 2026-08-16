import Charts
import SwiftUI
import WidgetKit

/// Home-screen counterpart of the Investments tab's "Bank account deltas"
/// chart: each account's end-of-month balance over time. The large family adds
/// the month-over-month change per account, mirroring the in-app "Monthly Δ"
/// mode of the same chart.
struct AccountBalancesWidget: Widget {
    let kind = "AccountBalancesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakatWidgetProvider()) { entry in
            AccountBalancesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Account Balances")
        .description("Each account's end-of-month balance, and how it moved.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AccountBalancesWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ZakatWidgetEntry

    private var points: [SharedAppGroup.AccountPoint] { entry.snapshot.accountHistory }

    /// Account names in the order they should be coloured — largest latest
    /// balance first, matching the order the snapshot was built in.
    private var accounts: [String] {
        var seen: [String] = []
        for point in points where !seen.contains(point.account) {
            seen.append(point.account)
        }
        return seen
    }

    private var colorScale: KeyValuePairs<String, Color> {
        // Charts needs a literal scale; build it from the first six accounts,
        // which is also the cap the snapshot writes.
        let names = accounts
        func name(_ i: Int) -> String { i < names.count ? names[i] : "—\(i)" }
        return [
            name(0): WidgetTheme.series[0],
            name(1): WidgetTheme.series[1],
            name(2): WidgetTheme.series[2],
            name(3): WidgetTheme.series[3],
            name(4): WidgetTheme.series[4],
            name(5): WidgetTheme.series[5],
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "ACCOUNT BALANCES", trailing: totalLabel)

            if points.count < 2 {
                WidgetEmptyState(
                    symbol: "chart.xyaxis.line",
                    text: "Balances are recorded at each month's end. Come back after a month or two."
                )
            } else {
                chart
                if family == .systemLarge {
                    deltaList
                } else {
                    legend
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Sum of every account's most recent balance.
    private var totalLabel: String? {
        let latest = latestBalances
        guard !latest.isEmpty else { return nil }
        return latest.values.reduce(Decimal.zero, +).widgetCurrency
    }

    private var latestBalances: [String: Decimal] {
        var out: [String: Decimal] = [:]
        for point in points {
            out[point.account] = point.balance // points are date-ordered
        }
        return out
    }

    /// Latest month-over-month change per account.
    private var deltas: [(account: String, delta: Decimal, balance: Decimal)] {
        accounts.compactMap { account in
            let series = points.filter { $0.account == account }
            guard let last = series.last else { return nil }
            let previous = series.dropLast().last?.balance ?? last.balance
            return (account, last.balance - previous, last.balance)
        }
    }

    private var chart: some View {
        Chart(points, id: \.self) { point in
            if let date = point.date {
                LineMark(
                    x: .value("Month", date, unit: .month),
                    y: .value("Balance", point.balance.widgetDouble)
                )
                .foregroundStyle(by: .value("Account", point.account))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Month", date, unit: .month),
                    y: .value("Balance", point.balance.widgetDouble)
                )
                .foregroundStyle(by: .value("Account", point.account))
                .symbolSize(14)
            }
        }
        .chartForegroundStyleScale(colorScale)
        .chartLegend(.hidden)
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
        HStack(spacing: 10) {
            ForEach(Array(accounts.prefix(4).enumerated()), id: \.element) { index, account in
                WidgetLegendDot(color: WidgetTheme.series[index % WidgetTheme.series.count], label: account)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var deltaList: some View {
        VStack(spacing: 4) {
            ForEach(Array(deltas.enumerated()), id: \.element.account) { index, row in
                HStack(spacing: 6) {
                    Circle()
                        .fill(WidgetTheme.series[index % WidgetTheme.series.count])
                        .frame(width: 7, height: 7)
                    Text(row.account)
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(row.balance.widgetCurrency)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(row.delta.widgetSignedCurrency)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(row.delta >= 0 ? WidgetTheme.accent : WidgetTheme.warning)
                        .frame(minWidth: 52, alignment: .trailing)
                }
            }
        }
    }
}

#Preview(as: .systemMedium) {
    AccountBalancesWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemLarge) {
    AccountBalancesWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
}
