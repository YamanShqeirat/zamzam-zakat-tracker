import Charts
import SwiftUI
import WidgetKit

/// Home-screen counterpart of the Budget tab's "Total expenses by category"
/// chart: this year's spending per category, largest first, in each category's
/// own colour.
struct ExpenseCategoryWidget: Widget {
    let kind = "ExpenseCategoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakatWidgetProvider()) { entry in
            ExpenseCategoryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Expenses by Category")
        .description("Where this year's spending went, biggest category first.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ExpenseCategoryWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ZakatWidgetEntry

    private var budget: SharedAppGroup.BudgetSummary { entry.snapshot.budget }

    /// Medium fits about four bars legibly; large takes the full set.
    private var rows: [SharedAppGroup.CategoryTotal] {
        Array(budget.expenseByCategory.prefix(family == .systemLarge ? 8 : 4))
    }

    private var total: Decimal {
        budget.expenseByCategory.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(
                title: "EXPENSES BY CATEGORY",
                trailing: total > 0 ? total.widgetCurrency : nil
            )

            if rows.isEmpty {
                WidgetEmptyState(
                    symbol: "chart.bar.xaxis",
                    text: "Add expense categories in the Budget tab to see where your money goes."
                )
            } else {
                chart
                if let top = budget.expenseByCategory.first, total > 0 {
                    Text("\(top.name) is \(share(of: top))% of this year's spending.")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func share(of row: SharedAppGroup.CategoryTotal) -> Int {
        guard total > 0 else { return 0 }
        return Int(((row.amount / total).widgetDouble * 100).rounded())
    }

    private var chart: some View {
        Chart(rows, id: \.name) { row in
            BarMark(
                x: .value("Amount", row.amount.widgetDouble),
                y: .value("Category", row.name)
            )
            .foregroundStyle(WidgetTheme.color(hex: row.colorHex))
            .cornerRadius(3)
            .annotation(position: .trailing, alignment: .leading) {
                Text(widgetCompactCurrency(row.amount.widgetDouble))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(domain: 0...(maxAmount * 1.25))
        .frame(maxHeight: .infinity)
    }

    /// Headroom on the x-axis so the trailing value labels aren't clipped.
    private var maxAmount: Double {
        max(1, rows.map { $0.amount.widgetDouble }.max() ?? 1)
    }
}

#Preview(as: .systemMedium) {
    ExpenseCategoryWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemLarge) {
    ExpenseCategoryWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
}
