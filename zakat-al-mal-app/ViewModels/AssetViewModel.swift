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
        weightUnit: WeightUnit = .grams,
        notes: String? = nil,
        context: ModelContext
    ) {
        let asset = Asset(name: name, category: category, source: .manual, currentBalance: balance)
        asset.weightInGrams = weightInGrams
        asset.weightUnit = weightUnit
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
        weightUnit: WeightUnit? = nil,
        context: ModelContext
    ) {
        guard asset.source == .manual,
              asset.category == .gold || asset.category == .silver else { return }
        asset.weightInGrams = weightInGrams
        if let weightUnit { asset.weightUnit = weightUnit }
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
        if name.contains("checking") || name.contains("savings")
            || name.contains("chequing") || name.contains("deposit") { return .bankAccount }
        if name.contains("ira") || name.contains("401k") || name.contains("roth")
            || name.contains("retirement") || name.contains("pension") { return .retirement }
        if name.contains("espp") { return .espp }
        if name.contains("crypto") || name.contains("coinbase") || name.contains("bitcoin") { return .crypto }
        if name.contains("brokerage") || name.contains("individual")
            || name.contains("invest") || name.contains("stock") { return .brokerage }
        if name.contains("cash") || name.contains("money market") { return .cash }
        // Unknown: default to a neutral category rather than assuming stocks —
        // the user can correct it in the asset's detail screen.
        return .other
    }
}
