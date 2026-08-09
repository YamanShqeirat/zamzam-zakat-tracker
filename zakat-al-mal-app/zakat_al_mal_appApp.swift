//
//  zakat_al_mal_appApp.swift
//  zakat-al-mal-app
//
//  Created by Yaman Shqeirat on 5/12/26.
//

import SwiftData
import SwiftUI

@main
struct zakat_al_mal_appApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Asset.self,
            HawlRecord.self,
            NisabSnapshot.self,
            ZakatPayment.self,
            AppSettings.self,
            BudgetCategory.self,
            BudgetEntry.self,
            FinanceTransaction.self,
            AccountBalanceSnapshot.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        BackgroundSyncService.register(modelContainer: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await BackgroundSyncService.performForegroundSyncIfNeeded(
                        modelContainer: sharedModelContainer
                    )
                }
            case .background:
                BackgroundSyncService.scheduleNext()
            default:
                break
            }
        }
    }
}
