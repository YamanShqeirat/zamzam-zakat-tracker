import Foundation
import SwiftData

/// Maintains the monthly `AccountBalanceSnapshot` history that powers the
/// "Bank account deltas" line chart. Each active asset gets one snapshot per
/// calendar month, refreshed from its live/synced balance — except months the
/// user has hand-edited (`isManualOverride`), which are left untouched.
enum AccountHistoryStore {
    /// Upsert the current month's balance for every active asset. Called after
    /// each sync (foreground refresh + background daily sync) and on first
    /// launch, so history accumulates automatically.
    @MainActor
    static func upsertCurrentMonth(assets: [Asset], context: ModelContext) {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        guard let year = comps.year, let month = comps.month else { return }

        let existing = (try? context.fetch(FetchDescriptor<AccountBalanceSnapshot>())) ?? []
        var changed = false

        for asset in assets where asset.isActive {
            let assetId = asset.id
            if let snapshot = existing.first(where: {
                $0.assetId == assetId && $0.year == year && $0.month == month
            }) {
                if !snapshot.isManualOverride, snapshot.balance != asset.currentBalance {
                    snapshot.balance = asset.currentBalance
                    changed = true
                }
            } else {
                context.insert(AccountBalanceSnapshot(
                    assetId: assetId,
                    year: year,
                    month: month,
                    balance: asset.currentBalance
                ))
                changed = true
            }
        }

        if changed { try? context.save() }
    }
}
