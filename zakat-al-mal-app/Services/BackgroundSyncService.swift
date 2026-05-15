import BackgroundTasks
import Foundation
import SwiftData
import WidgetKit

/// Daily background refresh.
///
/// Wiring required outside this file:
///   1. Info.plist: `BGTaskSchedulerPermittedIdentifiers` array must include
///      `com.yamanshqeirat.zakat-al-mal-app.dailysync`.
///   2. Signing & Capabilities → Background Modes → "Background fetch".
///   3. Call `BackgroundSyncService.register(modelContainer:)` exactly once
///      at app launch, before `applicationDidFinishLaunching` returns.
///   4. Call `BackgroundSyncService.scheduleNext()` whenever the app
///      enters the background (or once after launch).
enum BackgroundSyncService {
    static let taskIdentifier = "com.yamanshqeirat.zakat-al-mal-app.dailysync"

    /// Register the BGAppRefreshTask handler. Must be called before the app
    /// finishes launching.
    static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: refresh, modelContainer: modelContainer)
        }
    }

    /// Schedule the next daily sync ~24h from now. Silently swallows
    /// the "no permitted identifier" error so the foreground app still works
    /// in development before entitlements are configured.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Handler

    private static func handle(task: BGAppRefreshTask, modelContainer: ModelContainer) {
        // Always reschedule first so we keep getting woken up.
        scheduleNext()

        let work = Task {
            await performDailySync(modelContainer: modelContainer)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { work.cancel() }
    }

    /// Performs the daily sync sequence. Public so the foreground app can
    /// run it on demand (e.g. for testing).
    @MainActor
    static func performDailySync(modelContainer: ModelContainer) async {
        let context = ModelContext(modelContainer)
        let engine = ZakatEngine()

        // 1. Fetch gold + silver prices.
        var goldPrice: Decimal = await fetchGoldPrice(context: context)
        let silverPrice: Decimal = await fetchSilverPrice(context: context)

        // 2. Fetch SimpleFIN balances → update asset balances.
        await syncSimpleFIN(context: context)

        // 3. Apply live metal spot prices to gold/silver assets with weight.
        let assets = (try? context.fetch(FetchDescriptor<Asset>())) ?? []
        applyMetalWeights(assets: assets, goldPrice: goldPrice, silverPrice: silverPrice, context: context)

        // 4. Recalculate totals from current asset state.
        let totalWealth = engine.totalZakatableWealth(assets: assets)
        // Use cached gold price if today's fetch failed.
        if goldPrice == 0,
           let cached = (try? context.fetch(FetchDescriptor<AppSettings>()).first)?.cachedGoldPricePerGram {
            goldPrice = cached
        }
        let nisab = engine.nisabMonitor.nisabThreshold(goldPricePerGram: goldPrice)
        let isAbove = goldPrice > 0 && totalWealth >= nisab

        // 4. NisabSnapshot for historical tracking.
        if goldPrice > 0 {
            context.insert(NisabSnapshot(
                date: Date(),
                goldPricePerGram: goldPrice,
                totalZakatableWealth: totalWealth
            ))
        }

        // 5. Evaluate hawl + react with notifications.
        let hawls = (try? context.fetch(FetchDescriptor<HawlRecord>())) ?? []
        var activeHawl = hawls.first { $0.status == .inProgress || $0.status == .zakatDue }
        var daysRemaining = 0
        var zakatDue: Decimal = 0
        let notificationsEnabled = (try? context.fetch(FetchDescriptor<AppSettings>()).first)?.notificationsEnabled ?? true

        if goldPrice > 0 {
            if let hawl = activeHawl {
                let evaluation = engine.evaluateHawl(
                    hawlRecord: hawl,
                    currentWealth: totalWealth,
                    currentGoldPrice: goldPrice,
                    currentDate: Date()
                )
                switch evaluation {
                case .inProgress(let days):
                    daysRemaining = days
                case .zakatDue(let amount):
                    zakatDue = amount
                    hawl.status = .zakatDue
                    hawl.wealthAtEnd = totalWealth
                    hawl.nisabAtEnd = nisab
                    hawl.zakatDueAmount = amount
                    if notificationsEnabled {
                        NotificationService.notifyZakatDue(estimatedZakat: amount, wealth: totalWealth)
                    }
                case .hawlReset:
                    hawl.status = .reset
                    activeHawl = nil
                    if notificationsEnabled {
                        NotificationService.notifyHawlReset()
                    }
                }
            } else if isAbove {
                let new = HawlRecord(startDate: Date(), wealthAtStart: totalWealth, nisabAtStart: nisab)
                context.insert(new)
                activeHawl = new
                daysRemaining = engine.hawlTracker.daysRemaining(from: Date(), hawlEnd: new.hawlEndDate)
            }
        }

        try? context.save()

        // 6. Schedule hawl reminder (future-dated).
        if notificationsEnabled,
           let hawl = activeHawl, hawl.status == .inProgress,
           let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            let daysBefore = settings.hawlReminderDaysBefore
            let fire = Calendar.current.date(byAdding: .day, value: -daysBefore, to: hawl.hawlEndDate) ?? hawl.hawlEndDate
            if fire > Date() {
                let estimate = totalWealth * ZakatEngine.zakatRate
                NotificationService.scheduleHawlReminder(at: fire, daysBefore: daysBefore, estimatedZakat: estimate)
            }
        }

        // 7. Sync-failure check: if SimpleFIN was set up but no asset has synced in 3+ days.
        if notificationsEnabled, KeychainService.load(key: KeychainKey.simplefinAccessURL) != nil {
            let simplefinAssets = assets.filter { $0.source == .simplefin }
            let mostRecent = simplefinAssets.compactMap(\.lastSyncedAt).max()
            if let latest = mostRecent {
                let days = Calendar.current.dateComponents([.day], from: latest, to: Date()).day ?? 0
                if days >= 3 {
                    NotificationService.notifySyncFailure(daysWithoutSync: days)
                }
            }
        }

        // 8. Publish snapshot to widget + reload timeline.
        SharedAppGroup.write(.init(
            totalZakatableWealth: totalWealth,
            currentNisab: nisab,
            daysRemaining: daysRemaining,
            estimatedZakat: zakatDue > 0 ? zakatDue : totalWealth * ZakatEngine.zakatRate,
            isAboveNisab: isAbove,
            lastUpdated: Date(),
            hasData: true
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Helpers

    @MainActor
    private static func fetchGoldPrice(context: ModelContext) async -> Decimal {
        guard let apiKey = KeychainService.load(key: KeychainKey.goldAPIKey) else { return 0 }
        guard let price = try? await GoldAPIService(apiKey: apiKey).fetchGoldPricePerGram(),
              price > 0 else { return 0 }
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            settings.cachedGoldPricePerGram = price
            settings.lastGoldPriceRefresh = Date()
        }
        return price
    }

    @MainActor
    private static func fetchSilverPrice(context: ModelContext) async -> Decimal {
        guard let apiKey = KeychainService.load(key: KeychainKey.goldAPIKey) else { return 0 }
        guard let price = try? await GoldAPIService(apiKey: apiKey).fetchSilverPricePerGram(),
              price > 0 else { return 0 }
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            settings.cachedSilverPricePerGram = price
            settings.lastSilverPriceRefresh = Date()
        }
        return price
    }

    @MainActor
    private static func applyMetalWeights(
        assets: [Asset],
        goldPrice: Decimal,
        silverPrice: Decimal,
        context: ModelContext
    ) {
        for asset in assets {
            guard let weight = asset.weightInGrams, weight > 0 else { continue }
            let price: Decimal
            switch asset.category {
            case .gold:   price = goldPrice
            case .silver: price = silverPrice
            default: continue
            }
            guard price > 0 else { continue }
            asset.currentBalance = weight * price
        }
    }

    @MainActor
    private static func syncSimpleFIN(context: ModelContext) async {
        guard let accessURL = KeychainService.load(key: KeychainKey.simplefinAccessURL) else { return }
        guard let accounts = try? await SimpleFINService(accessURL: accessURL).fetchAccounts() else { return }
        guard let assets = try? context.fetch(FetchDescriptor<Asset>()) else { return }
        for asset in assets where asset.source == .simplefin {
            if let match = accounts.first(where: { $0.id == asset.simplefinAccountId }) {
                asset.currentBalance = match.balance
                asset.lastSyncedAt = match.balanceDate
            }
        }
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            settings.lastSimpleFINSync = Date()
        }
    }
}
