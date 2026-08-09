import Foundation
import SwiftData

/// One category's total for one calendar month. `manualAmount` is the lump sum
/// the user typed into the budget grid; when it's `nil` the effective amount is
/// derived from that month's `FinanceTransaction`s instead (see
/// `BudgetCalculator.effectiveAmount`). A manual value always wins so the two
/// entry styles never double-count.
@Model
final class BudgetEntry {
    var id: UUID
    var categoryId: UUID
    var year: Int
    /// 1...12
    var month: Int
    var manualAmount: Decimal?
    var notes: String?

    init(
        categoryId: UUID,
        year: Int,
        month: Int,
        manualAmount: Decimal? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.categoryId = categoryId
        self.year = year
        self.month = month
        self.manualAmount = manualAmount
        self.notes = notes
    }
}
