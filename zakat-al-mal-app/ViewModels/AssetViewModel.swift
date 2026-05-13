import Foundation
import Observation
import SwiftData

@Observable
final class AssetViewModel {
    var showingAddAsset: Bool = false
    var showingSimpleFINSetup: Bool = false

    func addManualAsset(
        name: String,
        category: AssetCategory,
        balance: Decimal,
        weightInGrams: Decimal? = nil,
        notes: String? = nil,
        context: ModelContext
    ) {
        let asset = Asset(name: name, category: category, source: .manual, currentBalance: balance)
        asset.weightInGrams = weightInGrams
        asset.notes = notes
        context.insert(asset)
        try? context.save()
    }

    func updateManualBalance(asset: Asset, newBalance: Decimal, context: ModelContext) {
        guard asset.source == .manual else { return }
        asset.currentBalance = newBalance
        try? context.save()
    }

    func updateMetalWeight(
        asset: Asset,
        weightInGrams: Decimal,
        spotPricePerGram: Decimal,
        context: ModelContext
    ) {
        guard asset.source == .manual,
              asset.category == .gold || asset.category == .silver else { return }
        asset.weightInGrams = weightInGrams
        if spotPricePerGram > 0 {
            asset.currentBalance = weightInGrams * spotPricePerGram
        }
        try? context.save()
    }

    func deleteAsset(_ asset: Asset, context: ModelContext) {
        context.delete(asset)
        try? context.save()
    }

    func linkSimpleFINAccounts(
        _ accounts: [SimpleFINAccount],
        existingAssets: [Asset],
        context: ModelContext
    ) {
        // Skip accounts that are already linked.
        let linkedIDs = Set(existingAssets.compactMap { $0.simplefinAccountId })
        for account in accounts where !linkedIDs.contains(account.id) {
            let asset = Asset(
                name: account.name,
                category: categorize(account),
                source: .simplefin,
                currentBalance: account.balance
            )
            asset.simplefinAccountId = account.id
            asset.lastSyncedAt = account.balanceDate
            context.insert(asset)
        }
        try? context.save()
    }

    private func categorize(_ account: SimpleFINAccount) -> AssetCategory {
        let name = account.name.lowercased()
        if name.contains("checking") || name.contains("savings") { return .bankAccount }
        if name.contains("ira") || name.contains("401k") || name.contains("roth") { return .retirement }
        if name.contains("brokerage") || name.contains("individual") { return .brokerage }
        return .brokerage
    }
}
