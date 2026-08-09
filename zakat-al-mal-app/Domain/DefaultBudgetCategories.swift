import Foundation
import SwiftData

/// Seed categories mirroring the user's Google Sheet. Inserted once, on first
/// launch, when no `BudgetCategory` rows exist yet.
enum DefaultBudgetCategories {
    /// (name, colorHex) pairs, in display order.
    static let income: [(String, UInt32)] = [
        ("Salary", 0x2DD4A8),
        ("Other",  0x64748B),
    ]

    static let expense: [(String, UInt32)] = [
        ("Personal Spending", 0x8B5CF6),
        ("Rent",              0x3B82F6),
        ("Bills",             0x2DD4A8),
        ("Subscriptions",     0xFB923C),
        ("Loans",             0xEF4444),
        ("Taxes",             0xF59E0B),
        ("Insurance",         0x06B6D4),
        ("Donations",         0xEC4899),
        ("Gifts",             0xA3E635),
        ("Other",             0x9CA3AF),
    ]

    /// Insert the seed rows if the store has no categories yet. Safe to call on
    /// every launch — it no-ops once seeded.
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<BudgetCategory>())) ?? 0
        guard existing == 0 else { return }

        var order = 0
        for (name, hex) in income {
            context.insert(BudgetCategory(name: name, kind: .income, colorHex: hex, sortOrder: order))
            order += 1
        }
        order = 0
        for (name, hex) in expense {
            context.insert(BudgetCategory(name: name, kind: .expense, colorHex: hex, sortOrder: order))
            order += 1
        }
        try? context.save()
    }
}
