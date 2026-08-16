import Charts
import SwiftUI
import WidgetKit

/// Home-screen counterpart of the Budget tab's "Total income vs expenditure"
/// and "Income vs expenses by month" charts. Small shows the year's totals and
/// balance; medium and large plot the twelve months side by side.
struct BudgetFlowWidget: Widget {
    let kind = "BudgetFlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakatWidgetProvider()) { entry in
            BudgetFlowWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Income vs Expenses")
        .description("This year's income against what you've spent, month by month.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct BudgetFlowWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ZakatWidgetEntry

    private var budget: SharedAppGroup.BudgetSummary { entry.snapshot.budget }

    private struct MonthBar: Hashable {
        let month: Int
        let series: String
        let amount: Double
    }

    private var bars: [MonthBar] {
        (0..<12).flatMap { i -> [MonthBar] in
            let income = i < budget.monthlyIncome.count ? budget.monthlyIncome[i].widgetDouble : 0
            let expense = i < budget.monthlyExpense.count ? budget.monthlyExpense[i].widgetDouble : 0
            return [
                MonthBar(month: i + 1, series: "Income", amount: income),
                MonthBar(month: i + 1, series: "Expenses", amount: expense),
            ]
        }
    }

    /// Full short names ("Jan", "Feb"…) because they have to be unique — the
    /// x-axis is categorical, and single initials would merge Jan/Jun/Jul into
    /// one bar group. The axis label trims them back to an initial.
    private static let monthNames = Calendar.current.shortMonthSymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(
                title: "INCOME VS EXPENSES",
                trailing: budget.year > 0 ? String(budget.year) : nil
            )

            if !budget.hasData {
                WidgetEmptyState(
                    symbol: "chart.bar.xaxis",
                    text: "Enter figures in the Budget tab to see your year at a glance."
                )
            } else {
                totals
                if family != .systemSmall {
                    chart
                    legend
                } else {
                    balanceBar
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Totals

    private var totals: some View {
        HStack(spacing: 10) {
            totalColumn(label: "Income", amount: budget.totalIncome, color: WidgetTheme.accent)
            totalColumn(label: "Expenses", amount: budget.totalExpense, color: WidgetTheme.warning)
            if family != .systemSmall {
                totalColumn(
                    label: "Balance",
                    amount: budget.balance,
                    color: budget.balance >= 0 ? WidgetTheme.accent : WidgetTheme.warning
                )
            }
        }
    }

    private func totalColumn(label: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(amount.widgetCurrency)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Small: share of income spent

    private var balanceBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            HStack {
                Text("Balance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(budget.balance.widgetSignedCurrency)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(budget.balance >= 0 ? WidgetTheme.accent : WidgetTheme.warning)
            }
            ProgressView(value: min(spentRatio, 1))
                .progressViewStyle(.linear)
                .tint(spentRatio <= 1 ? WidgetTheme.accent : WidgetTheme.warning)
            Text(percentSpentLabel)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private var spentRatio: Double {
        let income = budget.totalIncome.widgetDouble
        guard income > 0 else { return 0 }
        return budget.totalExpense.widgetDouble / income
    }

    private var percentSpentLabel: String {
        guard budget.totalIncome > 0 else { return "No income recorded yet" }
        return "\(Int((spentRatio * 100).rounded()))% of income spent"
    }

    // MARK: - Medium / large: grouped bars

    private var chart: some View {
        Chart(bars, id: \.self) { bar in
            BarMark(
                x: .value("Month", Self.monthNames[bar.month - 1]),
                y: .value("Amount", bar.amount)
            )
            .foregroundStyle(by: .value("Series", bar.series))
            .position(by: .value("Series", bar.series))
            .cornerRadius(2)
        }
        .chartForegroundStyleScale([
            "Income": WidgetTheme.accent,
            "Expenses": WidgetTheme.warning,
        ])
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
            AxisMarks { value in
                AxisValueLabel {
                    if let month = value.as(String.self) {
                        Text(month.prefix(1))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            WidgetLegendDot(color: WidgetTheme.accent, label: "Income")
            WidgetLegendDot(color: WidgetTheme.warning, label: "Expenses")
            Spacer(minLength: 0)
            Text(percentSpentLabel)
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

#Preview(as: .systemSmall) {
    BudgetFlowWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemMedium) {
    BudgetFlowWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemLarge) {
    BudgetFlowWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
}
