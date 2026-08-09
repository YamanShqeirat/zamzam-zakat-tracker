import Foundation
import SwiftData
import SwiftUI

/// A user-defined bucket for income or spending (e.g. "Salary", "Rent",
/// "Eating out"). Monthly amounts live on `BudgetEntry`; individual purchases
/// can optionally be itemised via `FinanceTransaction`.
@Model
final class BudgetCategory {
    var id: UUID
    var name: String
    /// Backing store for `BudgetKind`. Stored as a raw string so SwiftData can
    /// index it and lightweight migration stays trivial.
    var kindRaw: String
    var colorHex: UInt32
    var sortOrder: Int
    var isArchived: Bool

    var kind: BudgetKind {
        get { BudgetKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    init(
        name: String,
        kind: BudgetKind,
        colorHex: UInt32,
        sortOrder: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }
}

enum BudgetKind: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income:  return "Income"
        case .expense: return "Expenses"
        }
    }
}
