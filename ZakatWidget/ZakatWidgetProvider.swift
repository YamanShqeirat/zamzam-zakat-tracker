import Foundation
import WidgetKit

struct ZakatWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedAppGroup.Snapshot

    /// Sample data for the gallery/placeholder state. Covers every series so
    /// each chart widget previews with something to draw. Built field by field
    /// rather than as one literal to keep it cheap to type-check.
    static let placeholder = ZakatWidgetEntry(date: Date(), snapshot: sampleSnapshot)

    private static var sampleSnapshot: SharedAppGroup.Snapshot {
        var snapshot = SharedAppGroup.Snapshot()
        snapshot.totalZakatableWealth = 47832
        snapshot.currentNisab = 6205
        snapshot.daysRemaining = 107
        snapshot.estimatedZakat = 1195.80
        snapshot.isAboveNisab = true
        snapshot.lastUpdated = Date()
        snapshot.hasData = true
        snapshot.hawlTotalDays = 354
        snapshot.lifetimeZakatPaid = 3260
        snapshot.breakdown = [
            .init(category: "brokerage",   amount: 21500),
            .init(category: "bankAccount", amount: 12800),
            .init(category: "gold",        amount: 7400),
            .init(category: "cash",        amount: 3132),
            .init(category: "crypto",      amount: 3000),
        ]
        snapshot.giving = [
            .init(hijriYear: 1444, amount: 940),
            .init(hijriYear: 1445, amount: 1120),
            .init(hijriYear: 1446, amount: 1200),
        ]
        snapshot.wealthHistory = sampleWealth
        snapshot.accountHistory = sampleAccounts
        snapshot.budget = sampleBudget
        return snapshot
    }

    static let empty = ZakatWidgetEntry(
        date: Date(),
        snapshot: SharedAppGroup.Snapshot()
    )

    // MARK: - Sample series

    private static var sampleWealth: [SharedAppGroup.WealthPoint] {
        let wealth: [Decimal] = [38200, 39100, 41050, 40400, 43800, 45200, 47832]
        let nisab: [Decimal]  = [5980, 6020, 6090, 6040, 6150, 6180, 6205]
        return (0..<wealth.count).compactMap { i in
            guard let date = Calendar.current.date(
                byAdding: .month, value: i - (wealth.count - 1), to: Date()
            ) else { return nil }
            return SharedAppGroup.WealthPoint(date: date, wealth: wealth[i], nisab: nisab[i])
        }
    }

    private static var sampleAccounts: [SharedAppGroup.AccountPoint] {
        let checking: [Decimal] = [7200, 7650, 8100, 7900, 8600, 9050]
        let savings:  [Decimal] = [11000, 11400, 11950, 12300, 12550, 12800]
        let cal = Calendar.current
        let now = Date()
        return (0..<checking.count).flatMap { i -> [SharedAppGroup.AccountPoint] in
            guard let date = cal.date(byAdding: .month, value: i - (checking.count - 1), to: now) else { return [] }
            let comps = cal.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else { return [] }
            return [
                .init(year: year, month: month, account: "Savings",  balance: savings[i]),
                .init(year: year, month: month, account: "Checking", balance: checking[i])
            ]
        }
    }

    private static var sampleBudget: SharedAppGroup.BudgetSummary {
        SharedAppGroup.BudgetSummary(
            year: Calendar.current.component(.year, from: Date()),
            monthlyIncome:  [6200, 6200, 6400, 6200, 6800, 6200, 6200, 6500, 6200, 6200, 6900, 6200],
            monthlyExpense: [4100, 3800, 4600, 4200, 5100, 3900, 4400, 4700, 4000, 4300, 5200, 4100],
            expenseByCategory: [
                .init(name: "Rent",       colorHex: 0x4A90D9, amount: 21600),
                .init(name: "Groceries",  colorHex: 0x22C55E, amount: 9400),
                .init(name: "Eating out", colorHex: 0xFB923C, amount: 5200),
                .init(name: "Transport",  colorHex: 0x8B5CF6, amount: 3800),
                .init(name: "Utilities",  colorHex: 0xEC4899, amount: 2600)
            ]
        )
    }
}

/// One provider serves every widget in the bundle — they all render from the
/// same app-group snapshot, just different slices of it.
struct ZakatWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZakatWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ZakatWidgetEntry) -> Void) {
        // The widget gallery has no real data to show, so preview with samples.
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZakatWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 6 hours per spec — the main app reloads the timeline
        // proactively on each sync, so this is just a safety net.
        let nextRefresh = Date().addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> ZakatWidgetEntry {
        ZakatWidgetEntry(date: Date(), snapshot: SharedAppGroup.read())
    }
}
