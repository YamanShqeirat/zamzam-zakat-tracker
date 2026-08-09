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
    /// Storage is always canonical grams; the user's preferred entry/display
    /// unit lives in `weightUnitRaw`.
    var weightInGrams: Decimal?

    /// The unit the user prefers to enter/view this metal's weight in.
    /// Grams remain the canonical storage unit; this only affects display.
    var weightUnitRaw: String?

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw ?? "") ?? .grams }
        set { weightUnitRaw = newValue.rawValue }
    }

    /// The stored weight expressed in the user's preferred unit.
    var weightInPreferredUnit: Decimal? {
        guard let grams = weightInGrams else { return nil }
        return grams / weightUnit.gramsPerUnit
    }

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
    case espp
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

/// Higher-level section an `AssetCategory` belongs to, used to organise the
/// asset list and the Overview net-worth split.
enum AssetGroup: String, CaseIterable, Identifiable {
    case bank
    case investments
    case physical
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bank:        return "Bank Accounts"
        case .investments: return "Investments"
        case .physical:    return "Physical Assets"
        case .other:       return "Other"
        }
    }

    var sortOrder: Int {
        switch self {
        case .bank:        return 0
        case .investments: return 1
        case .physical:    return 2
        case .other:       return 3
        }
    }
}

/// Weight unit for physical metals. Grams is canonical storage; ounces use the
/// troy ounce (31.1034768 g), the standard for precious metals.
enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case grams
    case ounces

    var id: String { rawValue }

    var abbrev: String {
        switch self {
        case .grams:  return "g"
        case .ounces: return "oz"
        }
    }

    var displayName: String {
        switch self {
        case .grams:  return "Grams"
        case .ounces: return "Troy oz"
        }
    }

    /// Grams in one unit — multiply a value in this unit by it to get grams.
    var gramsPerUnit: Decimal {
        switch self {
        case .grams:  return 1
        case .ounces: return Decimal(string: "31.1034768")!
        }
    }
}
