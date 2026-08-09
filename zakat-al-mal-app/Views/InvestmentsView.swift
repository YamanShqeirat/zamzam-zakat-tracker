import Charts
import SwiftData
import SwiftUI

/// The "Investments" tab: savings & investments breakdown (from assets),
/// account balances over time, and the wealth-vs-nisab trend. Read-only charts;
/// asset editing lives behind the "Manage assets" link.
struct InvestmentsView: View {
    @Query private var assets: [Asset]
    @Query private var accountSnapshots: [AccountBalanceSnapshot]

    @State private var accountMode: AccountMode = .balance

    private enum AccountMode: String, CaseIterable, Identifiable {
        case balance = "Balance"
        case delta = "Monthly Δ"
        var id: String { rawValue }
    }

    // MARK: - Derived

    private var activeAssets: [Asset] { assets.filter(\.isActive) }
    private var totalWealth: Decimal {
        activeAssets.reduce(.zero) { $0 + $1.zakatableAmount }
    }

    private var slices: [AssetSlice] {
        Dictionary(grouping: activeAssets, by: \.category)
            .map { AssetSlice(category: $0.key, amount: $0.value.reduce(.zero) { $0 + $1.zakatableAmount }) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    /// Per-account balance history, one series per account, ordered by month.
    private var accountSeries: [AccountPoint] {
        let nameByAsset = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0.name) })
        let grouped = Dictionary(grouping: accountSnapshots, by: \.assetId)
        var out: [AccountPoint] = []
        for (assetId, snaps) in grouped {
            guard let name = nameByAsset[assetId] else { continue }
            let ordered = snaps.sorted { ($0.year, $0.month) < ($1.year, $1.month) }
            var previous: Decimal?
            for snap in ordered {
                guard let date = Self.monthDate(year: snap.year, month: snap.month) else { continue }
                let value: Double
                switch accountMode {
                case .balance:
                    value = snap.balance.asDouble
                case .delta:
                    value = (snap.balance - (previous ?? snap.balance)).asDouble
                }
                out.append(AccountPoint(date: date, account: name, value: value))
                previous = snap.balance
            }
        }
        return out.sorted { $0.date < $1.date }
    }

    private var hasAccountHistory: Bool {
        Set(accountSnapshots.map(\.assetId)).count > 0 && accountSnapshots.count >= 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                savingsCard
                accountsCard
                manageLink
                disclaimer
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Investments")
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Savings & investments

    private var savingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader("SAVINGS & INVESTMENTS")
            if slices.isEmpty {
                emptyState(symbol: "chart.pie",
                           text: "Add assets in the Zakat tab to see how your savings and investments break down.")
            } else {
                AssetDistributionChart(slices: slices, total: totalWealth)
            }
        }
        .cardBackground()
    }

    // MARK: - Account balances

    private var accountsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                cardHeader("BANK ACCOUNT DELTAS")
                Spacer()
                Picker("", selection: $accountMode) {
                    ForEach(AccountMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if !hasAccountHistory {
                emptyState(symbol: "chart.xyaxis.line",
                           text: "Each account's end-of-month balance is recorded automatically as your balances sync. Come back after a month or two to see the trend.")
            } else {
                Chart(accountSeries) { p in
                    LineMark(x: .value("Month", p.date, unit: .month),
                             y: .value("Value", p.value))
                        .foregroundStyle(by: .value("Account", p.account))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Month", p.date, unit: .month),
                              y: .value("Value", p.value))
                        .foregroundStyle(by: .value("Account", p.account))
                        .symbolSize(28)
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
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .chartLegend(position: .bottom, spacing: 8)
                .frame(height: 220)
            }
        }
        .cardBackground()
    }

    // MARK: - Manage

    private var manageLink: some View {
        NavigationLink {
            AssetListView()
        } label: {
            HStack {
                Label("Manage assets", systemImage: "slider.horizontal.3")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(16)
            .background(AppTheme.card, in: .rect(cornerRadius: 12))
        }
    }

    private var disclaimer: some View {
        Text("Charts are for personal insight only and are not financial advice.")
            .font(.caption2)
            .foregroundStyle(AppTheme.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2.bold())
            .tracking(0.8)
            .foregroundStyle(AppTheme.textSecondary)
    }

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

    private static func monthDate(year: Int, month: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))
    }
}

private struct AccountPoint: Identifiable {
    let id = UUID()
    let date: Date
    let account: String
    let value: Double
}

private extension View {
    func cardBackground() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack { InvestmentsView() }
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self, BudgetCategory.self, BudgetEntry.self, FinanceTransaction.self, AccountBalanceSnapshot.self], inMemory: true)
        .preferredColorScheme(.dark)
}
