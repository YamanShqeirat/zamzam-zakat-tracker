import Foundation

/// Builds a single CSV that mirrors the user's annual-budget spreadsheet:
/// a Summary block, Income / Expenses tables (category × month + Total/Average),
/// a Savings & Investments snapshot, and an Accounts (end-of-month) table.
/// Sections are separated by blank lines so it opens cleanly in Sheets/Excel.
enum CSVExporter {
    private static let months = Calendar.current.shortMonthSymbols // Jan…Dec

    @MainActor
    static func export(
        year: Int,
        categories: [BudgetCategory],
        entries: [BudgetEntry],
        transactions: [FinanceTransaction],
        assets: [Asset],
        accountSnapshots: [AccountBalanceSnapshot]
    ) -> URL? {
        let csv = buildCSV(
            year: year,
            calc: BudgetCalculator(categories: categories, entries: entries, transactions: transactions),
            categories: categories,
            entries: entries,
            assets: assets.filter(\.isActive),
            accountSnapshots: accountSnapshots
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZamZam-\(year)-finances.csv")
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Building

    private static func buildCSV(
        year: Int,
        calc: BudgetCalculator,
        categories: [BudgetCategory],
        entries: [BudgetEntry],
        assets: [Asset],
        accountSnapshots: [AccountBalanceSnapshot]
    ) -> String {
        var rows: [[String]] = []

        rows.append(["ANNUAL BUDGET \(year)"])
        rows.append([])

        // Summary
        rows.append(["SUMMARY"])
        rows.append(["Total income", fmt(calc.totalIncome(year: year))])
        rows.append(["Total expenses", fmt(calc.totalExpense(year: year))])
        rows.append(["Balance", fmt(calc.balance(year: year))])
        rows.append(["Percentage of income spent", calc.percentIncomeSpent(year: year).map { "\($0)%" } ?? "—"])
        rows.append([])

        // Income + Expenses tables
        appendBudgetTable(&rows, title: "INCOME", kind: .income, year: year, calc: calc, withNotes: false, entries: entries)
        rows.append([])
        appendBudgetTable(&rows, title: "EXPENSES", kind: .expense, year: year, calc: calc, withNotes: true, entries: entries)
        rows.append([])

        // Savings & investments snapshot (current balances by category)
        rows.append(["SAVINGS & INVESTMENTS (CURRENT)"])
        rows.append(["Item", "Value"])
        let byCategory = Dictionary(grouping: assets, by: \.category)
            .map { (name: $0.key.displayName, total: $0.value.reduce(Decimal.zero) { $0 + $1.currentBalance }) }
            .filter { $0.total != 0 }
            .sorted { $0.total > $1.total }
        for entry in byCategory {
            rows.append([entry.name, fmt(entry.total)])
        }
        rows.append(["Total", fmt(byCategory.reduce(Decimal.zero) { $0 + $1.total })])
        rows.append([])

        // Accounts (end of month)
        appendAccountsTable(&rows, year: year, assets: assets, accountSnapshots: accountSnapshots)

        return rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n")
    }

    private static func appendBudgetTable(
        _ rows: inout [[String]],
        title: String,
        kind: BudgetKind,
        year: Int,
        calc: BudgetCalculator,
        withNotes: Bool,
        entries: [BudgetEntry]
    ) {
        var header = [title] + months + ["Total", "Average"]
        if withNotes { header.append("Notes") }
        rows.append(header)

        let cats = calc.activeCategories(kind)
        var monthTotals = Array(repeating: Decimal.zero, count: 12)
        var grandTotal = Decimal.zero

        for cat in cats {
            var row = [cat.name]
            var rowTotal = Decimal.zero
            var monthsWithValue = 0
            for month in 1...12 {
                let value = calc.effectiveAmount(categoryId: cat.id, year: year, month: month)
                row.append(value == 0 ? "" : fmt(value))
                rowTotal += value
                monthTotals[month - 1] += value
                if value != 0 { monthsWithValue += 1 }
            }
            grandTotal += rowTotal
            row.append(fmt(rowTotal))
            row.append(fmt(monthsWithValue == 0 ? 0 : rowTotal / Decimal(monthsWithValue)))
            if withNotes { row.append(notes(for: cat, year: year, entries: entries)) }
            rows.append(row)
        }

        // Total row
        var totalRow = ["Total"]
        for month in 1...12 { totalRow.append(fmt(monthTotals[month - 1])) }
        totalRow.append(fmt(grandTotal))
        totalRow.append(fmt(grandTotal / 12))
        if withNotes { totalRow.append("") }
        rows.append(totalRow)
    }

    private static func appendAccountsTable(
        _ rows: inout [[String]],
        year: Int,
        assets: [Asset],
        accountSnapshots: [AccountBalanceSnapshot]
    ) {
        rows.append(["ACCOUNTS (END OF MONTH)"] + months)
        let nameByAsset = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0.name) })
        let yearSnaps = accountSnapshots.filter { $0.year == year }
        let grouped = Dictionary(grouping: yearSnaps, by: \.assetId)

        var monthTotals = Array(repeating: Decimal.zero, count: 12)
        for (assetId, snaps) in grouped.sorted(by: { ($0.key.uuidString) < ($1.key.uuidString) }) {
            let name = nameByAsset[assetId] ?? "Account"
            var row = [name]
            for month in 1...12 {
                if let snap = snaps.first(where: { $0.month == month }) {
                    row.append(fmt(snap.balance))
                    monthTotals[month - 1] += snap.balance
                } else {
                    row.append("")
                }
            }
            rows.append(row)
        }
        rows.append(["Total"] + monthTotals.map(fmt))
    }

    // MARK: - Helpers

    private static func notes(for cat: BudgetCategory, year: Int, entries: [BudgetEntry]) -> String {
        entries
            .filter { $0.categoryId == cat.id && $0.year == year }
            .compactMap { $0.notes }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
    }

    private static func fmt(_ value: Decimal) -> String {
        String(format: "%.2f", (value as NSDecimalNumber).doubleValue)
    }

    /// RFC-4180 escaping: quote fields containing commas, quotes, or newlines.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
