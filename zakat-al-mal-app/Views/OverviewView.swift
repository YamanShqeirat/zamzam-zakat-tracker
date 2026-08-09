import SwiftData
import SwiftUI

/// The "Overview" home tab: a spreadsheet-style summary of the current year —
/// income, expenses, balance, % of income spent — plus a net-worth figure and a
/// compact Zakat status glance. Everything here is read-only; entry happens in
/// the Budget and Zakat tabs.
struct OverviewView: View {
    @Query private var categories: [BudgetCategory]
    @Query private var entries: [BudgetEntry]
    @Query private var transactions: [FinanceTransaction]
    @Query private var assets: [Asset]
    @Query(sort: \HawlRecord.hawlStartDate, order: .reverse) private var hawls: [HawlRecord]
    @Query private var settingsList: [AppSettings]

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    private var calc: BudgetCalculator {
        BudgetCalculator(categories: categories, entries: entries, transactions: transactions)
    }
    private var settings: AppSettings? { settingsList.first }
    private var netWorth: Decimal {
        assets.filter(\.isActive).reduce(.zero) { $0 + $1.currentBalance }
    }
    private var zakatableWealth: Decimal {
        assets.filter(\.isActive).reduce(.zero) { $0 + $1.zakatableAmount }
    }
    private var currentNisab: Decimal {
        NisabMonitor().nisabThreshold(goldPricePerGram: settings?.cachedGoldPricePerGram ?? 0)
    }
    private var activeHawl: HawlRecord? {
        hawls.first { $0.status == .inProgress || $0.status == .zakatDue }
    }

    /// Net worth split into high-level asset groups (Bank / Investments /
    /// Physical / Other), largest first. Uses `currentBalance` so it reflects
    /// total holdings, not just the zakatable portion.
    private var groupBreakdown: [(group: AssetGroup, total: Decimal)] {
        Dictionary(grouping: assets.filter(\.isActive), by: { $0.category.group })
            .map { (group: $0.key, total: $0.value.reduce(Decimal.zero) { $0 + $1.currentBalance }) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }
    private var groupBreakdownMax: Decimal { groupBreakdown.first?.total ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                summaryCard
                statGrid
                if !groupBreakdown.isEmpty {
                    breakdownCard
                }
                zakatGlance
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle("Overview")
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let balance = calc.balance(year: year)
        return VStack(alignment: .leading, spacing: 14) {
            Text("\(String(year)) SUMMARY")
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(alignment: .firstTextBaseline) {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                CurrencyText(amount: balance)
                    .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(balance >= 0 ? AppTheme.accent : AppTheme.warning)
            }

            if let percent = calc.percentIncomeSpent(year: year) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Income spent")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Text("\(percent)%")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    ProgressView(value: Double(min(percent, 100)), total: 100)
                        .progressViewStyle(.linear)
                        .tint(percent <= 100 ? AppTheme.accent : AppTheme.warning)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }

    // MARK: - Stat grid

    private var statGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            OverviewTile(label: "Income (\(String(year)))", amount: calc.totalIncome(year: year), accent: AppTheme.accent)
            OverviewTile(label: "Expenses (\(String(year)))", amount: calc.totalExpense(year: year), accent: AppTheme.warning)
            OverviewTile(label: "Net worth", amount: netWorth, accent: AppTheme.textPrimary)
            OverviewTile(label: "Zakatable wealth", amount: zakatableWealth, accent: AppTheme.textPrimary)
        }
    }

    // MARK: - Asset breakdown (by group)

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NET WORTH BREAKDOWN")
                    .font(.caption2.bold())
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                CurrencyText(amount: netWorth)
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            VStack(spacing: 10) {
                ForEach(groupBreakdown, id: \.group) { entry in
                    GroupBreakdownRow(group: entry.group, amount: entry.total, max: groupBreakdownMax)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }

    // MARK: - Zakat glance

    private var zakatGlance: some View {
        let above = currentNisab > 0 && zakatableWealth >= currentNisab
        return VStack(alignment: .leading, spacing: 10) {
            Text("ZAKAT STATUS")
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 10) {
                Image(systemName: above ? "checkmark.seal.fill" : "hourglass")
                    .foregroundStyle(above ? AppTheme.accent : AppTheme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(above ? "Above nisab" : "Below nisab")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(zakatSubtitle(above: above))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }

    private func zakatSubtitle(above: Bool) -> String {
        if activeHawl?.status == .zakatDue {
            return "Zakat is due — open the Zakat tab to record it."
        }
        if above, activeHawl != nil {
            return "Hawl in progress. Estimated \((zakatableWealth * ZakatEngine.zakatRate).currencyString) at year end."
        }
        if currentNisab == 0 {
            return "Set your GoldAPI key in Settings to compute the nisab."
        }
        return "Your wealth is below the nisab threshold."
    }
}

private struct GroupBreakdownRow: View {
    let group: AssetGroup
    let amount: Decimal
    let max: Decimal

    private var ratio: Double {
        guard max > 0 else { return 0 }
        return Swift.min(1, (amount as NSDecimalNumber).doubleValue / (max as NSDecimalNumber).doubleValue)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: group.sfSymbol)
                    .font(.caption)
                    .foregroundStyle(group.color)
                    .frame(width: 18)
                Text(group.displayName)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                CurrencyText(amount: amount)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.ringTrack).frame(height: 3)
                    Capsule().fill(group.color).frame(width: geo.size.width * ratio, height: 3)
                }
            }
            .frame(height: 3)
        }
    }
}

private struct OverviewTile: View {
    let label: String
    let amount: Decimal
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            CurrencyText(amount: amount)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(accent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack { OverviewView() }
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self, BudgetCategory.self, BudgetEntry.self, FinanceTransaction.self, AccountBalanceSnapshot.self], inMemory: true)
        .preferredColorScheme(.dark)
}
