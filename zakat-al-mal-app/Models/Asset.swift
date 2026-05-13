import Foundation
import SwiftData

@Model
final class Asset {
    var id: UUID
    var name: String
    var category: AssetCategory
    var source: AssetSource
    var currentBalance: Decimal
    var lastSyncedAt: Date?
    var simplefinAccountId: String?
    var isActive: Bool
    var notes: String?

    var earlyWithdrawalPenaltyPercent: Decimal?

    /// Weight in grams for physical gold/silver. When set, the dashboard
    /// recomputes `currentBalance` as `weightInGrams * <spot price per gram>`
    /// on every refresh, so the asset always reflects live market value.
    var weightInGrams: Decimal?

    var zakatableAmount: Decimal {
        switch category {
        case .retirement:
            let penalty = earlyWithdrawalPenaltyPercent ?? 0
            return currentBalance * (1 - penalty / 100)
        default:
            return currentBalance
        }
    }

    init(
        name: String,
        category: AssetCategory,
        source: AssetSource,
        currentBalance: Decimal = 0
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.source = source
        self.currentBalance = currentBalance
        self.isActive = true
    }
}

enum AssetCategory: String, Codable, CaseIterable {
    case cash
    case bankAccount
    case brokerage
    case crypto
    case gold
    case silver
    case retirement
    case receivable
    case other
}

enum AssetSource: String, Codable {
    case simplefin
    case manual
}
