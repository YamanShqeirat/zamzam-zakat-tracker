import SwiftData
import SwiftUI

/// Top-level navigation for the finance app. Zakat is now one tab among several
/// rather than the whole app. Each tab owns its own `NavigationStack`.
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Overview", systemImage: "square.grid.2x2") {
                NavigationStack { OverviewView() }
            }
            Tab("Budget", systemImage: "chart.bar.xaxis") {
                NavigationStack { BudgetView() }
            }
            Tab("Investments", systemImage: "chart.pie") {
                NavigationStack { InvestmentsView() }
            }
            Tab("Zakat", systemImage: "moon.stars") {
                NavigationStack { DashboardView() }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack { SettingsView() }
            }
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self, BudgetCategory.self, BudgetEntry.self, FinanceTransaction.self, AccountBalanceSnapshot.self], inMemory: true)
        .preferredColorScheme(.dark)
}
