import Foundation
import SwiftData

/// End-of-month balance for a single `Asset`, powering the "Bank account
/// deltas" line chart. Written automatically each month by
/// `AccountHistoryStore.upsertCurrentMonth` from live/synced balances; a user
/// edit flips `isManualOverride` so subsequent auto-syncs leave that month alone.
@Model
final class AccountBalanceSnapshot {
    var id: UUID
    var assetId: UUID
    var year: Int
    /// 1...12
    var month: Int
    var balance: Decimal
    var isManualOverride: Bool

    init(
        assetId: UUID,
        year: Int,
        month: Int,
        balance: Decimal,
        isManualOverride: Bool = false
    ) {
        self.id = UUID()
        self.assetId = assetId
        self.year = year
        self.month = month
        self.balance = balance
        self.isManualOverride = isManualOverride
    }
}
