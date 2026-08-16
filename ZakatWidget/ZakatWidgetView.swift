import Charts
import SwiftUI
import WidgetKit

struct ZakatWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ZakatWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumView(snapshot: entry.snapshot)
        default:
            SmallView(snapshot: entry.snapshot)
        }
    }
}

// Category colours/labels live in `WidgetSupport.swift` (`WidgetCategory`),
// shared with the other chart widgets.

// MARK: - Small: countdown ring

private struct SmallView: View {
    let snapshot: SharedAppGroup.Snapshot

    private var progress: Double {
        let total = Double(max(1, snapshot.hawlTotalDays))
        let remaining = Double(snapshot.daysRemaining)
        return max(0, min(1, (total - remaining) / total))
    }

    private var ringTint: Color {
        snapshot.isAboveNisab ? WidgetTheme.accent : .gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hawl")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            if !snapshot.hasData {
                Spacer()
                Text("Open the app to sync")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringTint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(snapshot.daysRemaining)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(snapshot.daysRemaining == 1 ? "day left" : "days left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium: wealth distribution (mirrors AnalyticsView's distributionCard)

private struct MediumView: View {
    let snapshot: SharedAppGroup.Snapshot

    /// Sum the breakdown directly so the displayed total always matches the
    /// donut — defends against a stale `totalZakatableWealth` in the snapshot.
    private var derivedTotal: Decimal {
        snapshot.breakdown.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var slices: [SharedAppGroup.CategorySlice] {
        snapshot.breakdown.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEALTH DISTRIBUTION")
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(.secondary)

            if slices.isEmpty {
                Spacer()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chart.pie")
                        .foregroundStyle(.secondary)
                    Text("Add an asset in the app to see how your wealth is distributed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                HStack(alignment: .center, spacing: 14) {
                    Donut(slices: slices, total: derivedTotal)
                        .frame(width: 118, height: 118)

                    Legend(slices: slices, total: derivedTotal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct Donut: View {
    let slices: [SharedAppGroup.CategorySlice]
    let total: Decimal

    var body: some View {
        Chart(slices, id: \.category) { slice in
            SectorMark(
                angle: .value("Amount", NSDecimalNumber(decimal: slice.amount).doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(WidgetCategory.color(for: slice.category))
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 1) {
                Text("Total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(total.formatted(
                    .currency(code: "USD").precision(.fractionLength(0))
                ))
                    .font(.subheadline.bold().monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
        }
    }
}

private struct Legend: View {
    let slices: [SharedAppGroup.CategorySlice]
    let total: Decimal

    /// Cap visible rows so the legend doesn't overflow the medium widget. The
    /// tail rolls into a single "Other" row.
    private var rows: [SharedAppGroup.CategorySlice] {
        let maxRows = 5
        guard slices.count > maxRows else { return slices }
        let head = Array(slices.prefix(maxRows - 1))
        let rest = slices.dropFirst(maxRows - 1)
            .reduce(Decimal.zero) { $0 + $1.amount }
        return head + [SharedAppGroup.CategorySlice(category: "other", amount: rest)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.category) { slice in
                LegendRow(slice: slice, total: total)
            }
        }
    }
}

private struct LegendRow: View {
    let slice: SharedAppGroup.CategorySlice
    let total: Decimal

    private var percent: String {
        guard total > 0 else { return "—" }
        let pct = (slice.amount / total) as NSDecimalNumber
        return "\(Int((pct.doubleValue * 100).rounded()))%"
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(WidgetCategory.color(for: slice.category))
                .frame(width: 8, height: 8)
            Text(WidgetCategory.displayName(for: slice.category))
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(percent)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview(as: .systemSmall) {
    ZakatWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemMedium) {
    ZakatWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}
