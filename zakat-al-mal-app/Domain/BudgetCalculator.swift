import Foundation

/// Pure aggregation over the budget models. Views pass in the `@Query` results;
/// every figure the Budget/Overview screens show is derived here so the charts
/// and tiles stay consistent.
///
/// The single source of truth for a category's monthly figure is
/// `effectiveAmount`: a typed `manualAmount` always wins, otherwise the amount
/// is the sum of that month's itemised `FinanceTransaction`s. The two entry
/// styles therefore never double-count.
struct BudgetCalculator {
    let categories: [BudgetCategory]
    let entries: [BudgetEntry]
    let transactions: [FinanceTransaction]

    // Index transactions by (categoryId, year, month) once so per-cell lookups
    // stay O(1) even with a full year of history on screen.
    private let txnByCell: [Cell: Decimal]
    private let entryByCell: [Cell: BudgetEntry]

    private struct Cell: Hashable {
        let categoryId: UUID
        let year: Int
        let month: Int
    }

    init(categories: [BudgetCategory], entries: [BudgetEntry], transactions: [FinanceTransaction]) {
        self.categories = categories
        self.entries = entries
        self.transactions = transactions

        let cal = Calendar.current
        var txnMap: [Cell: Decimal] = [:]
        for txn in transactions {
            let comps = cal.dateComponents([.year, .month], from: txn.date)
            guard let y = comps.year, let m = comps.month else { continue }
            let cell = Cell(categoryId: txn.categoryId, year: y, month: m)
            txnMap[cell, default: 0] += txn.amount
        }
        self.txnByCell = txnMap

        var entryMap: [Cell: BudgetEntry] = [:]
        for entry in entries {
            entryMap[Cell(categoryId: entry.categoryId, year: entry.year, month: entry.month)] = entry
        }
        self.entryByCell = entryMap
    }

    // MARK: - Core

    /// A category's figure for one month: manual override if present, else the
    /// sum of that month's itemised transactions.
    func effectiveAmount(categoryId: UUID, year: Int, month: Int) -> Decimal {
        let cell = Cell(categoryId: categoryId, year: year, month: month)
        if let manual = entryByCell[cell]?.manualAmount {
            return manual
        }
        return txnByCell[cell] ?? 0
    }

    /// Whether a cell's figure comes from itemised transactions (no manual value).
    func isDerived(categoryId: UUID, year: Int, month: Int) -> Bool {
        entryByCell[Cell(categoryId: categoryId, year: year, month: month)]?.manualAmount == nil
    }

    // MARK: - Aggregations

    func activeCategories(_ kind: BudgetKind) -> [BudgetCategory] {
        categories
            .filter { $0.kind == kind && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Total for one category across a whole year.
    func yearTotal(categoryId: UUID, year: Int) -> Decimal {
        (1...12).reduce(Decimal.zero) { $0 + effectiveAmount(categoryId: categoryId, year: year, month: $1) }
    }

    /// Per-month totals (1...12) for a kind across a year.
    func monthlyTotals(kind: BudgetKind, year: Int) -> [Decimal] {
        let cats = activeCategories(kind)
        return (1...12).map { month in
            cats.reduce(Decimal.zero) { $0 + effectiveAmount(categoryId: $1.id, year: year, month: month) }
        }
    }

    func totalIncome(year: Int) -> Decimal {
        monthlyTotals(kind: .income, year: year).reduce(0, +)
    }

    func totalExpense(year: Int) -> Decimal {
        monthlyTotals(kind: .expense, year: year).reduce(0, +)
    }

    /// Income minus expenses for the year.
    func balance(year: Int) -> Decimal {
        totalIncome(year: year) - totalExpense(year: year)
    }

    /// Share of income spent, 0...(can exceed 100). `nil` when no income.
    func percentIncomeSpent(year: Int) -> Int? {
        let income = totalIncome(year: year)
        guard income > 0 else { return nil }
        let ratio = (totalExpense(year: year) / income) as NSDecimalNumber
        return Int((ratio.doubleValue * 100).rounded())
    }

    /// Per-expense-category yearly totals, largest first, zero-totals dropped.
    func expenseByCategory(year: Int) -> [(category: BudgetCategory, total: Decimal)] {
        activeCategories(.expense)
            .map { (category: $0, total: yearTotal(categoryId: $0.id, year: year)) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }
}
