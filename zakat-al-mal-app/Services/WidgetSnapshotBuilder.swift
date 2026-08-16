import Foundation
import SwiftData
import WidgetKit

/// Builds the app-group snapshot every home-screen widget renders from.
///
/// Each widget mirrors one chart in the app, so this is where the chart's
/// aggregation is repeated against the SwiftData store. The two callers —
/// `DashboardViewModel.refresh` (foreground) and `BackgroundSyncService`
/// (daily task) — hand over the zakat figures they've just computed and this
/// type fetches everything else itself.
///
/// Series are capped so the payload stays small; app-group `UserDefaults` is a
/// cache, not a database.
enum WidgetSnapshotBuilder {
    /// Most recent wealth/nisab points kept for the trend widget.
    static let maxWealthPoints = 120
    /// Months of account history kept, per account.
    static let maxAccountMonths = 18
    /// Accounts kept in the balances widget (largest latest balance first).
    static let maxAccounts = 6
    /// Expense categories kept for the category widget.
    static let maxExpenseCategories = 8

    /// The zakat figures the caller has already computed this cycle.
    struct ZakatState {
        var totalZakatableWealth: Decimal
        var currentNisab: Decimal
        var daysRemaining: Int
        var hawlTotalDays: Int
        var estimatedZakat: Decimal
        var isAboveNisab: Bool

        init(
            totalZakatableWealth: Decimal,
            currentNisab: Decimal,
            daysRemaining: Int,
            estimatedZakat: Decimal,
            isAboveNisab: Bool,
            hawl: HawlRecord?
        ) {
            self.totalZakatableWealth = totalZakatableWealth
            self.currentNisab = currentNisab
            self.daysRemaining = daysRemaining
            self.estimatedZakat = estimatedZakat
            self.isAboveNisab = isAboveNisab
            self.hawlTotalDays = Self.hawlLength(hawl)
        }

        private static func hawlLength(_ hawl: HawlRecord?) -> Int {
            guard let hawl else { return 354 }
            let days = Calendar.current
                .dateComponents([.day], from: hawl.hawlStartDate, to: hawl.hawlEndDate).day ?? 354
            return max(1, days)
        }
    }

    /// Write the snapshot and reload every widget timeline.
    static func publish(state: ZakatState, assets: [Asset], context: ModelContext) {
        SharedAppGroup.write(snapshot(state: state, assets: assets, context: context))
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func snapshot(
        state: ZakatState,
        assets: [Asset],
        context: ModelContext
    ) -> SharedAppGroup.Snapshot {
        let payments = fetch(ZakatPayment.self, context: context)
        return SharedAppGroup.Snapshot(
            totalZakatableWealth: state.totalZakatableWealth,
            currentNisab: state.currentNisab,
            daysRemaining: state.daysRemaining,
            estimatedZakat: state.estimatedZakat,
            isAboveNisab: state.isAboveNisab,
            lastUpdated: Date(),
            hasData: true,
            breakdown: breakdown(from: assets),
            hawlTotalDays: state.hawlTotalDays,
            lifetimeZakatPaid: payments.reduce(.zero) { $0 + $1.amount },
            wealthHistory: wealthHistory(
                context: context,
                currentWealth: state.totalZakatableWealth,
                currentNisab: state.currentNisab
            ),
            giving: giving(payments: payments),
            accountHistory: accountHistory(assets: assets, context: context),
            budget: budget(context: context)
        )
    }

    // MARK: - Distribution

    static func breakdown(from assets: [Asset]) -> [SharedAppGroup.CategorySlice] {
        Dictionary(grouping: assets.filter(\.isActive), by: \.category)
            .map { category, items in
                SharedAppGroup.CategorySlice(
                    category: category.rawValue,
                    amount: items.reduce(Decimal.zero) { $0 + $1.zakatableAmount }
                )
            }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Wealth vs nisab

    /// Mirrors `AnalyticsSections.wealthSeries`: stored daily snapshots plus a
    /// synthetic point for today so the chart reads before history accumulates.
    private static func wealthHistory(
        context: ModelContext,
        currentWealth: Decimal,
        currentNisab: Decimal
    ) -> [SharedAppGroup.WealthPoint] {
        let stored = fetch(NisabSnapshot.self, context: context)
            .sorted { $0.date < $1.date }
        var points = stored.map {
            SharedAppGroup.WealthPoint(
                date: $0.date,
                wealth: $0.totalZakatableWealth,
                nisab: $0.nisabThresholdUSD
            )
        }
        if currentNisab > 0 || currentWealth > 0 {
            let today = Date()
            let needsToday = stored.last.map {
                !Calendar.current.isDate($0.date, inSameDayAs: today)
            } ?? true
            if needsToday {
                points.append(SharedAppGroup.WealthPoint(
                    date: today,
                    wealth: currentWealth,
                    nisab: currentNisab
                ))
            }
        }
        return Array(points.suffix(maxWealthPoints))
    }

    // MARK: - Giving

    private static func giving(payments: [ZakatPayment]) -> [SharedAppGroup.GivingBucket] {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        return Dictionary(grouping: payments) { hijri.component(.year, from: $0.date) }
            .map { SharedAppGroup.GivingBucket(
                hijriYear: $0.key,
                amount: $0.value.reduce(.zero) { $0 + $1.amount }
            ) }
            .sorted { $0.hijriYear < $1.hijriYear }
    }

    // MARK: - Account balances

    /// Per-account end-of-month balances, newest `maxAccountMonths` months for
    /// the `maxAccounts` largest accounts.
    private static func accountHistory(
        assets: [Asset],
        context: ModelContext
    ) -> [SharedAppGroup.AccountPoint] {
        let nameByAsset = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0.name) })
        let grouped = Dictionary(grouping: fetch(AccountBalanceSnapshot.self, context: context), by: \.assetId)

        // Rank accounts by their most recent balance so the widget shows the
        // ones that matter when there are more than it can legibly plot.
        let ranked = grouped.compactMap { assetId, snaps -> (name: String, latest: Decimal, snaps: [AccountBalanceSnapshot])? in
            guard let name = nameByAsset[assetId] else { return nil }
            let ordered = snaps.sorted { ($0.year, $0.month) < ($1.year, $1.month) }
            guard let latest = ordered.last?.balance else { return nil }
            return (name, latest, Array(ordered.suffix(maxAccountMonths)))
        }
        .sorted { $0.latest > $1.latest }
        .prefix(maxAccounts)

        return ranked
            .flatMap { account in
                account.snaps.map {
                    SharedAppGroup.AccountPoint(
                        year: $0.year,
                        month: $0.month,
                        account: account.name,
                        balance: $0.balance
                    )
                }
            }
            .sorted { ($0.year, $0.month) < ($1.year, $1.month) }
    }

    // MARK: - Budget

    private static func budget(context: ModelContext) -> SharedAppGroup.BudgetSummary {
        let year = Calendar.current.component(.year, from: Date())
        let calc = BudgetCalculator(
            categories: fetch(BudgetCategory.self, context: context),
            entries: fetch(BudgetEntry.self, context: context),
            transactions: fetch(FinanceTransaction.self, context: context)
        )
        return SharedAppGroup.BudgetSummary(
            year: year,
            monthlyIncome: calc.monthlyTotals(kind: .income, year: year),
            monthlyExpense: calc.monthlyTotals(kind: .expense, year: year),
            expenseByCategory: calc.expenseByCategory(year: year)
                .prefix(maxExpenseCategories)
                .map { SharedAppGroup.CategoryTotal(
                    name: $0.category.name,
                    colorHex: $0.category.colorHex,
                    amount: $0.total
                ) }
        )
    }

    // MARK: - Fetch helper

    private static func fetch<T: PersistentModel>(_ type: T.Type, context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }
}
