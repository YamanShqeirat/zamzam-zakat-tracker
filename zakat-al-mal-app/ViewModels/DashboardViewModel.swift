import Foundation
import Observation
import SwiftData
import WidgetKit

@Observable
final class DashboardViewModel {
    var totalZakatableWealth: Decimal = 0
    var currentNisab: Decimal = 0
    var goldPricePerGram: Decimal = 0
    var silverPricePerGram: Decimal = 0
    var isAboveNisab: Bool = false
    var currentHawl: HawlRecord?
    var daysRemainingInHawl: Int = 0
    var zakatDueAmount: Decimal = 0
    var lastSyncDate: Date?
    var isLoading: Bool = false
    var errorMessage: String?
    var goldPriceStale: Bool = false
    var hijriDateString: String = ""

    private let engine = ZakatEngine()

    var financialService: FinancialDataService?
    var goldPriceService: GoldPriceService?

    func refresh(assets: [Asset], modelContext: ModelContext) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 1. Gold + silver prices (independent — a failure on one doesn't block the rest).
        let gold = await refreshGoldPrice(modelContext: modelContext)
        goldPricePerGram = gold.price
        goldPriceStale = gold.stale

        silverPricePerGram = await refreshSilverPrice(modelContext: modelContext)

        // 2. SimpleFIN sync (independent error path).
        await refreshSimpleFIN(assets: assets, modelContext: modelContext)

        // 3. Re-mark gold/silver assets with live spot × weight.
        applyMetalSpotPrices(assets: assets, modelContext: modelContext)

        // 4. Recompute totals + nisab.
        totalZakatableWealth = engine.totalZakatableWealth(assets: assets)
        currentNisab = engine.nisabMonitor.nisabThreshold(goldPricePerGram: goldPricePerGram)
        isAboveNisab = goldPricePerGram > 0 && totalZakatableWealth >= currentNisab

        // 5. Hawl evaluation (only when we have a meaningful nisab).
        if goldPricePerGram > 0 {
            evaluateHawl(modelContext: modelContext)
        }

        // 6. Hijri label, widget snapshot, hawl-reminder schedule.
        hijriDateString = engine.hawlTracker.hijriDateString(for: Date())
        publishWidgetSnapshot()
        scheduleHawlReminderIfNeeded(modelContext: modelContext)
    }

    // MARK: - Section helpers

    private func refreshGoldPrice(modelContext: ModelContext) async -> (price: Decimal, stale: Bool) {
        if let service = goldPriceService {
            do {
                let price = try await service.fetchGoldPricePerGram()
                if let settings = currentSettings(modelContext) {
                    settings.cachedGoldPricePerGram = price
                    settings.lastGoldPriceRefresh = Date()
                    try? modelContext.save()
                }
                let stale = (service as? CachedGoldPriceService)?.lastGoldFetchWasStale ?? false
                return (price, stale)
            } catch {
                appendError("Gold price: \(error.localizedDescription)")
            }
        }
        // Fall back to the persisted cache when no live price is available.
        if let cached = currentSettings(modelContext)?.cachedGoldPricePerGram, cached > 0 {
            return (cached, true)
        }
        return (0, false)
    }

    private func refreshSilverPrice(modelContext: ModelContext) async -> Decimal {
        if let service = goldPriceService {
            if let price = try? await service.fetchSilverPricePerGram() {
                if let settings = currentSettings(modelContext) {
                    settings.cachedSilverPricePerGram = price
                    settings.lastSilverPriceRefresh = Date()
                    try? modelContext.save()
                }
                return price
            }
        }
        return currentSettings(modelContext)?.cachedSilverPricePerGram ?? 0
    }

    private func refreshSimpleFIN(assets: [Asset], modelContext: ModelContext) async {
        guard let finService = financialService else { return }
        do {
            let accounts = try await finService.fetchAccounts()
            updateAssetBalances(assets: assets, from: accounts, context: modelContext)
            lastSyncDate = Date()
        } catch {
            appendError("Account sync: \(error.localizedDescription)")
        }
    }

    private func applyMetalSpotPrices(assets: [Asset], modelContext: ModelContext) {
        var changed = false
        for asset in assets {
            guard let weight = asset.weightInGrams, weight > 0 else { continue }
            let price: Decimal
            switch asset.category {
            case .gold:   price = goldPricePerGram
            case .silver: price = silverPricePerGram
            default: continue
            }
            guard price > 0 else { continue }
            let value = weight * price
            if asset.currentBalance != value {
                asset.currentBalance = value
                changed = true
            }
        }
        if changed { try? modelContext.save() }
    }

    private func evaluateHawl(modelContext: ModelContext) {
        if let hawl = currentHawl {
            let evaluation = engine.evaluateHawl(
                hawlRecord: hawl,
                currentWealth: totalZakatableWealth,
                currentGoldPrice: goldPricePerGram,
                currentDate: Date()
            )

            switch evaluation {
            case .inProgress(let days):
                daysRemainingInHawl = days
                zakatDueAmount = 0
            case .zakatDue(let amount):
                zakatDueAmount = amount
                daysRemainingInHawl = 0
                hawl.status = .zakatDue
                hawl.wealthAtEnd = totalZakatableWealth
                hawl.nisabAtEnd = currentNisab
                hawl.zakatDueAmount = amount
            case .hawlReset:
                hawl.status = .reset
                currentHawl = nil
                daysRemainingInHawl = 0
                zakatDueAmount = 0
            }
            try? modelContext.save()
        } else if isAboveNisab {
            let newHawl = HawlRecord(
                startDate: Date(),
                wealthAtStart: totalZakatableWealth,
                nisabAtStart: currentNisab
            )
            modelContext.insert(newHawl)
            currentHawl = newHawl
            daysRemainingInHawl = engine.hawlTracker.daysRemaining(
                from: Date(),
                hawlEnd: newHawl.hawlEndDate
            )
            try? modelContext.save()
        }
    }

    private func publishWidgetSnapshot() {
        SharedAppGroup.write(.init(
            totalZakatableWealth: totalZakatableWealth,
            currentNisab: currentNisab,
            daysRemaining: daysRemainingInHawl,
            estimatedZakat: zakatDueAmount > 0
                ? zakatDueAmount
                : totalZakatableWealth * ZakatEngine.zakatRate,
            isAboveNisab: isAboveNisab,
            lastUpdated: Date(),
            hasData: true
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleHawlReminderIfNeeded(modelContext: ModelContext) {
        guard let hawl = currentHawl, hawl.status == .inProgress else { return }
        guard let settings = currentSettings(modelContext),
              settings.notificationsEnabled else { return }
        let daysBefore = settings.hawlReminderDaysBefore
        guard let fire = Calendar.current.date(byAdding: .day, value: -daysBefore, to: hawl.hawlEndDate),
              fire > Date() else { return }
        let estimate = totalZakatableWealth * ZakatEngine.zakatRate
        NotificationService.scheduleHawlReminder(at: fire, daysBefore: daysBefore, estimatedZakat: estimate)
    }

    private func updateAssetBalances(
        assets: [Asset],
        from accounts: [SimpleFINAccount],
        context: ModelContext
    ) {
        for asset in assets where asset.source == .simplefin {
            if let match = accounts.first(where: { $0.id == asset.simplefinAccountId }) {
                asset.currentBalance = match.balance
                asset.lastSyncedAt = match.balanceDate
            }
        }
        try? context.save()
    }

    private func currentSettings(_ modelContext: ModelContext) -> AppSettings? {
        try? modelContext.fetch(FetchDescriptor<AppSettings>()).first
    }

    private func appendError(_ msg: String) {
        if let existing = errorMessage, !existing.isEmpty {
            errorMessage = existing + "\n" + msg
        } else {
            errorMessage = msg
        }
    }
}
