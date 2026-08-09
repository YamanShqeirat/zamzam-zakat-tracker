import Charts
import SwiftUI

// MARK: - Asset distribution (donut + legend)

/// One slice of the asset-distribution donut.
struct AssetSlice: Identifiable {
    let id = UUID()
    let category: AssetCategory
    let amount: Decimal
}

/// Donut breakdown of asset categories with a side legend and centre total.
/// Shared by the Investments "Savings & investments" pie and the Zakat
/// analytics "Wealth distribution" card.
struct AssetDistributionChart: View {
    let slices: [AssetSlice]
    var total: Decimal

    private var resolvedTotal: Decimal {
        total > 0 ? total : slices.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            donut
                .frame(width: 140, height: 140)
            legend
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var donut: some View {
        Chart(slices) { entry in
            SectorMark(
                angle: .value("Amount", entry.amount.asDouble),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(entry.category.swatch)
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 2) {
                Text("Total")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                CurrencyText(amount: resolvedTotal)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(slices) { entry in
                HStack(spacing: 8) {
                    Circle()
                        .fill(entry.category.swatch)
                        .frame(width: 8, height: 8)
                    Text(entry.category.displayName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 4)
                    Text(percentText(for: entry))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func percentText(for entry: AssetSlice) -> String {
        let total = resolvedTotal
        guard total > 0 else { return "—" }
        let ratio = (entry.amount / total) as NSDecimalNumber
        return "\(Int((ratio.doubleValue * 100).rounded()))%"
    }
}

// MARK: - Wealth vs nisab line

struct WealthTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let wealth: Double
    let nisab: Double
}

/// Zakatable-wealth line against the nisab threshold over time. Shared by the
/// Zakat analytics screen and the Investments tab.
struct WealthTrendChart: View {
    let points: [WealthTrendPoint]

    var body: some View {
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("Wealth", p.wealth))
                    .foregroundStyle(by: .value("Series", "Wealth"))
                    .interpolationMethod(.monotone)
            }
            ForEach(points) { p in
                AreaMark(x: .value("Date", p.date), y: .value("Wealth", p.wealth))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.35), AppTheme.accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
            }
            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("Nisab", p.nisab))
                    .foregroundStyle(by: .value("Series", "Nisab"))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
        }
        .chartForegroundStyleScale([
            "Wealth": AppTheme.accent,
            "Nisab": Color(hex: 0xEF4444),
        ])
        .chartLegend(position: .bottom, spacing: 8) {
            HStack(spacing: 14) {
                ChartLegendDot(color: AppTheme.accent, label: "Zakatable wealth")
                ChartLegendDot(color: Color(hex: 0xEF4444), label: "Nisab", dashed: true)
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.textSecondary)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(AppTheme.divider)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(compactCurrency(v))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(AppTheme.divider)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(height: 200)
    }
}

// MARK: - Legend dot (shared)

struct ChartLegendDot: View {
    let color: Color
    let label: String
    var dashed: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if dashed {
                Rectangle()
                    .fill(color)
                    .frame(width: 14, height: 1.5)
                    .overlay(
                        Rectangle()
                            .fill(AppTheme.card)
                            .frame(width: 4, height: 1.5)
                    )
            } else {
                Circle().fill(color).frame(width: 7, height: 7)
            }
            Text(label)
        }
    }
}
