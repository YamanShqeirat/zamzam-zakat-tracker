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
        NavigationStack {
            DashboardView()
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .task {
            if settingsList.isEmpty {
                modelContext.insert(AppSettings())
                try? modelContext.save()
            }
            await NotificationService.requestAuthorization()
            BackgroundSyncService.scheduleNext()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self], inMemory: true)
}
