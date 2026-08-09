import Foundation
import SwiftData

/// An optional itemised entry under a `BudgetCategory` (e.g. a single "$18
/// lunch" under "Eating out"). Transactions roll up into a category/month total
/// only when that month has no `manualAmount` set on its `BudgetEntry`.
@Model
final class FinanceTransaction {
    var id: UUID
    var categoryId: UUID
    var date: Date
    var amount: Decimal
    var note: String?

    init(
        categoryId: UUID,
        date: Date,
        amount: Decimal,
        note: String? = nil
    ) {
        self.id = UUID()
        self.categoryId = categoryId
        self.date = date
        self.amount = amount
        self.note = note
    }
}
