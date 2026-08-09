import Charts
import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Query private var assets: [Asset]
    @Query(sort: \NisabSnapshot.date, order: .forward) private var snapshots: [NisabSnapshot]
    @Query(sort: \HawlRecord.hawlStartDate, order: .reverse) private var hawls: [HawlRecord]
    @Query(sort: \ZakatPayment.date, order: .forward) private var payments: [ZakatPayment]
    @Query private var settingsList: [AppSettings]

    // MARK: - Derived state

    private var settings: AppSettings? { settingsList.first }
    private var activeAssets: [Asset] { assets.filter { $0.isActive } }
    private var totalWealth: Decimal {
        activeAssets.reduce(.zero) { $0 + $1.zakatableAmount }
    }
    private var currentNisab: Decimal {
        NisabMonitor().nisabThreshold(goldPricePerGram: settings?.cachedGoldPricePerGram ?? 0)
    }
    private var activeHawl: HawlRecord? {
        hawls.first { $0.status == .inProgress || $0.status == .zakatDue }
    }
    private var lifetimeZakatPaid: Decimal {
        payments.reduce(.zero) { $0 + $1.amount }
    }
    private var distribution: [BreakdownEntry] {
        Dictionary(grouping: activeAssets, by: \.category)
            .map { BreakdownEntry(category: $0.key, amount: $0.value.reduce(.zero) { $0 + $1.zakatableAmount }) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }
    private var topConcentrationPercent: Int {
        guard totalWealth > 0, let top = distribution.first else { return 0 }
        let ratio = (top.amount / totalWealth) as NSDecimalNumber
        return Int((ratio.doubleValue * 100).rounded())
    }
    private var wealthSeries: [WealthPoint] {
        var points = snapshots.map {
            WealthPoint(date: $0.date,
                        wealth: $0.totalZakatableWealth.asDouble,
                        nisab: $0.nisabThresholdUSD.asDouble)
        }
        // Synthetic "today" point so the chart is meaningful even before
        // background syncs have accumulated history.
        if currentNisab > 0 || totalWealth > 0 {
            let today = Date()
            let needsAppend = snapshots.last.map {
                Calendar.current.isDate($0.date, inSameDayAs: today) == false
            } ?? true
            if needsAppend {
                points.append(WealthPoint(date: today,
                                          wealth: totalWealth.asDouble,
                                          nisab: currentNisab.asDouble))
            }
        }
        return points
    }
    private var wealthChange: Decimal? {
        guard let first = snapshots.first?.totalZakatableWealth else { return nil }
        return totalWealth - first
    }
    private var givingByYear: [GivingBucket] {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let grouped = Dictionary(grouping: payments) { hijri.component(.year, from: $0.date) }
        return grouped
            .map { GivingBucket(hijriYear: $0.key,
                                amount: $0.value.reduce(.zero) { $0 + $1.amount }) }
            .sorted { $0.hijriYear < $1.hijriYear }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                insightsStrip
                wealthOverTimeCard
                lunarCard
                givingCard
                disclaimer
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Analytics")
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Insights strip

    private var insightsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "AT A GLANCE",
                infoTitle: "At a glance",
                infoText: "Three quick measures of your financial journey so far.",
                infoCalc: "Lifetime zakat: sum of every recorded ZakatPayment.\nWealth Δ: today's zakatable wealth minus the value at your earliest snapshot.\nTop category: the largest category's share of your total zakatable wealth."
            )
            HStack(spacing: 12) {
                InsightTile(label: "Lifetime zakat",
                            value: lifetimeZakatPaid > 0 ? lifetimeZakatPaid.currencyString : "—",
                            accent: AppTheme.accent)
                InsightTile(label: "Wealth Δ",
                            value: wealthChange.map { $0.signedCurrencyString } ?? "—",
                            accent: (wealthChange ?? 0) >= 0 ? AppTheme.accent : AppTheme.warning)
                InsightTile(label: "Top category",
                            value: distribution.first != nil ? "\(topConcentrationPercent)%" : "—",
                            accent: distribution.first?.category.swatch ?? AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Wealth over time (line)

    private var wealthOverTimeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "WEALTH VS NISAB",
                infoTitle: "Wealth vs nisab",
                infoText: "Your zakatable wealth plotted against the nisab threshold over time.",
                infoCalc: "Each point is a daily snapshot stored by the background sync. The dashed red line is nisab = 85 g of gold × the gold spot price on that day, so it shifts as gold prices move. A synthetic point for today is added so the chart is meaningful before history accumulates."
            )

            if wealthSeries.count < 2 {
                emptyState(symbol: "chart.xyaxis.line",
                           text: "Your wealth trajectory will appear here as daily snapshots accumulate.")
            } else {
                WealthTrendChart(points: wealthSeries.map {
                    WealthTrendPoint(date: $0.date, wealth: $0.wealth, nisab: $0.nisab)
                })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }

    // MARK: - Lunar calendar infographic

    private var lunarCard: some View {
        VStack(spacing: 12) {
            SectionHeader(
                title: "THE HIJRI CALENDAR",
                infoTitle: "The Hijri calendar",
                infoText: "Zakat is paid each hawl — one full lunar year above nisab. The Hijri (lunar) year is about 354 days, ~11 shorter than a solar year.",
                infoCalc: "The 12 ring segments mark the Hijri months. The glowing dot is today's position in the current lunar year using the Umm al-Qura calendar. The moon's illumination tracks how far you are through that year."
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            LunarMonthRing(
                currentMonthIndex: hijriMonthIndex,
                dayOfYearRatio: hijriYearProgress
            )
            .frame(width: 220, height: 220)

            VStack(spacing: 2) {
                Text(currentHijriLong)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("12 lunar months · 354 days per hawl")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let hawl = activeHawl {
                let stats = hawlStats(for: hawl)
                Text("Hawl day \(stats.elapsed) of \(stats.total) · \(stats.remaining) remaining")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.top, 2)
            } else {
                Text("A hawl begins the moment your wealth crosses nisab.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }

    // MARK: - Giving history

    private var givingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "ZAKAT GIVEN",
                infoTitle: "Zakat given",
                infoText: "How much zakat you've recorded as paid, grouped by Hijri year.",
                infoCalc: "Each bar sums all ZakatPayment records whose date falls within that Hijri year (Umm al-Qura calendar). The lifetime total above is the sum across all years."
            )

            if payments.isEmpty {
                emptyState(symbol: "hands.sparkles",
                           text: "Once you record a zakat payment, your giving history will be charted here.")
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("Lifetime")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    CurrencyText(amount: lifetimeZakatPaid)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.accent)
                }

                Chart(givingByYear) { bucket in
                    BarMark(
                        x: .value("Year", "\(bucket.hijriYear) AH"),
                        y: .value("Amount", bucket.amount.asDouble)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .cornerRadius(4)
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
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .frame(height: 160)

                Text("\(payments.count) payment\(payments.count == 1 ? "" : "s") across \(givingByYear.count) Hijri year\(givingByYear.count == 1 ? "" : "s").")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        Text("Charts are for personal insight only and are not financial advice.")
            .font(.caption2)
            .foregroundStyle(AppTheme.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }

    // MARK: - Small helpers

    private func emptyState(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Hijri helpers

    private var hijriMonthIndex: Int {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        return max(1, min(12, hijri.component(.month, from: Date()))) - 1
    }
    private var hijriYearProgress: Double {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let now = Date()
        let year = hijri.component(.year, from: now)
        guard let yearStart = hijri.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = hijri.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return 0
        }
        let span = yearEnd.timeIntervalSince(yearStart)
        let elapsed = now.timeIntervalSince(yearStart)
        return min(1, max(0, elapsed / span))
    }
    private var currentHijriLong: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        f.locale = Locale(identifier: "en")
        f.dateFormat = "d MMMM yyyy 'AH'"
        return f.string(from: Date())
    }

    private func hawlStats(for hawl: HawlRecord) -> (elapsed: Int, total: Int, remaining: Int) {
        let total = max(1, Calendar.current.dateComponents([.day], from: hawl.hawlStartDate, to: hawl.hawlEndDate).day ?? 354)
        let remaining = max(0, Calendar.current.dateComponents([.day], from: Date(), to: hawl.hawlEndDate).day ?? 0)
        return (elapsed: max(0, total - remaining), total: total, remaining: remaining)
    }
}

// MARK: - Section header with info popover

private struct SectionHeader: View {
    let title: String
    let infoTitle: String
    let infoText: String
    let infoCalc: String?

    @State private var showingInfo = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About \(infoTitle)")
            .popover(isPresented: $showingInfo) {
                InfoPopover(title: infoTitle, text: infoText, calc: infoCalc)
                    .presentationCompactAdaptation(.popover)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct InfoPopover: View {
    let title: String
    let text: String
    let calc: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let calc {
                Divider().background(AppTheme.divider)
                Text("HOW IT'S CALCULATED")
                    .font(.caption2.bold())
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.textTertiary)
                Text(calc)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 260)
        .background(AppTheme.cardElevated)
        .presentationBackground(AppTheme.cardElevated)
    }
}

// MARK: - Insight tile

private struct InsightTile: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Rectangle()
                .fill(accent)
                .frame(height: 2)
                .clipShape(.capsule)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.card, in: .rect(cornerRadius: 12))
    }
}

// MARK: - Lunar month ring (infographic)

private struct LunarMonthRing: View {
    /// 0-based index of the currently-active Hijri month (0…11).
    let currentMonthIndex: Int
    /// Fraction (0…1) of how far we are through the current Hijri year.
    let dayOfYearRatio: Double

    private static let monthAbbreviations: [String] = [
        "Muh", "Saf", "Rab I", "Rab II",
        "Jum I", "Jum II", "Raj", "Sha",
        "Ram", "Shw", "Qid", "Hij",
    ]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = size / 2 - 6
            let labelRadius = outerRadius - 18
            let markerRadius = outerRadius - 4

            ZStack {
                Circle()
                    .stroke(AppTheme.ringTrack, lineWidth: 1)
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(center)

                ForEach(0..<12, id: \.self) { i in
                    let angle = angleForMonth(i)
                    let isCurrent = i == currentMonthIndex
                    Text(Self.monthAbbreviations[i])
                        .font(.caption2.weight(isCurrent ? .bold : .regular))
                        .foregroundStyle(isCurrent ? AppTheme.accent : AppTheme.textTertiary)
                        .position(point(at: center, radius: labelRadius, angle: angle))
                }

                // Dot showing precise position in the year along the ring.
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 10, height: 10)
                    .position(point(at: center, radius: markerRadius, angle: yearAngle))
                    .shadow(color: AppTheme.accent.opacity(0.7), radius: 6)

                MoonGlyph(phase: dayOfYearRatio)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .position(center)
            }
        }
    }

    /// Place month label at the start of that month (angle goes clockwise from top).
    private func angleForMonth(_ index: Int) -> Angle {
        Angle(degrees: -90 + Double(index) * 30)
    }
    private var yearAngle: Angle {
        Angle(degrees: -90 + dayOfYearRatio * 360)
    }
    private func point(at center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle.radians)),
            y: center.y + radius * CGFloat(sin(angle.radians))
        )
    }
}

/// Stylized crescent / moon disc whose illumination tracks the hawl phase.
/// `phase` (0…1) drives how much of the disc is illuminated, giving a subtle
/// waxing → full → waning feel without trying to be astronomically accurate.
private struct MoonGlyph: View {
    let phase: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.cardElevated, AppTheme.background],
                        center: .center,
                        startRadius: 4,
                        endRadius: 80
                    )
                )
            Circle()
                .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)

            // Illuminated crescent: shift a second disc to expose a sliver.
            GeometryReader { geo in
                let d = min(geo.size.width, geo.size.height)
                let offset = (1 - illumination) * d * 0.55
                Circle()
                    .fill(AppTheme.accent.opacity(0.85))
                    .frame(width: d, height: d)
                    .mask(
                        ZStack {
                            Circle()
                            Circle()
                                .offset(x: -offset)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
            }
            .padding(6)
        }
    }

    /// Triangle wave: 0 → 1 at mid-year → 0 again, so it reads as
    /// new-moon → full → new across one lunar year.
    private var illumination: Double {
        let p = min(1, max(0, phase))
        return 1 - abs(0.5 - p) * 2
    }
}

// MARK: - Local models

private struct BreakdownEntry: Identifiable {
    let id = UUID()
    let category: AssetCategory
    let amount: Decimal
}

private struct WealthPoint: Identifiable {
    let id = UUID()
    let date: Date
    let wealth: Double
    let nisab: Double
}

private struct GivingBucket: Identifiable {
    let id = UUID()
    let hijriYear: Int
    let amount: Decimal
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self, BudgetCategory.self, BudgetEntry.self, FinanceTransaction.self, AccountBalanceSnapshot.self], inMemory: true)
        .preferredColorScheme(.dark)
}
