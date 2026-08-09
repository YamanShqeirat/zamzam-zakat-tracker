//
//  ContentView.swift
//  zakat-al-mal-app
//
//  Created by Yaman Shqeirat on 5/12/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    var body: some View {
        RootTabView()
            .tint(AppTheme.accent)
            .preferredColorScheme(.dark)
            .task {
                if settingsList.isEmpty {
                    modelContext.insert(AppSettings())
                    try? modelContext.save()
                }
                DefaultBudgetCategories.seedIfNeeded(context: modelContext)
                await NotificationService.requestAuthorization()
                BackgroundSyncService.scheduleNext()
                armMonthlyExpenseReminder()
            }
    }

    /// (Re)schedule the end-of-month "review your expenses" reminder on launch.
    private func armMonthlyExpenseReminder() {
        let settings = settingsList.first
        guard settings?.notificationsEnabled ?? true,
              settings?.monthlyExpenseReminderEnabled ?? true else {
            NotificationService.cancel(identifier: NotificationService.Identifier.monthlyExpenseReview)
            return
        }
        NotificationService.scheduleMonthlyExpenseReview(hour: settings?.monthlyExpenseReminderHour ?? 20)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self, BudgetCategory.self, BudgetEntry.self, FinanceTransaction.self, AccountBalanceSnapshot.self], inMemory: true)
}
