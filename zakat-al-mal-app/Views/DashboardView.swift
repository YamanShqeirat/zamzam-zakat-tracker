import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assets: [Asset]
    @Query(sort: \HawlRecord.hawlStartDate, order: .reverse) private var allHawls: [HawlRecord]

    @State private var vm = DashboardViewModel()
    @State private var showingPaymentSheet = false
    @State private var showingAddAsset = false

    private let hawlTracker = HawlTracker()
    private let addAssetVM = AssetViewModel()

    // MARK: - Derived state

    private var activeHawl: HawlRecord? {
        allHawls.first { $0.status == .inProgress || $0.status == .zakatDue }
    }
    private var hasActiveAssets: Bool {
        assets.contains(where: \.isActive)
    }
    private var hasGoldKey: Bool {
        KeychainService.load(key: KeychainKey.goldAPIKey) != nil
    }
    private var totalDaysInHawl: Int {
        guard let hawl = vm.currentHawl else { return 354 }
        let comps = Calendar.current.dateComponents([.day], from: hawl.hawlStartDate, to: hawl.hawlEndDate)
        return max(1, comps.day ?? 354)
    }
    private var elapsedDays: Int {
        max(0, totalDaysInHawl - vm.daysRemainingInHawl)
    }
    private var progressToNisabPercent: Int {
        guard vm.currentNisab > 0 else { return 0 }
        let ratio = (vm.totalZakatableWealth / vm.currentNisab) as NSDecimalNumber
        return min(100, max(0, Int(ratio.doubleValue * 100)))
    }
    private var amountBelowThreshold: Decimal {
        max(0, vm.currentNisab - vm.totalZakatableWealth)
    }
    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let err = vm.errorMessage, !err.isEmpty {
                    errorBanner(err)
                }

                ringSection

                if vm.isAboveNisab, let hawl = vm.currentHawl {
                    aboveNisabIndicator(hawl: hawl)
                }

                statPair

                if vm.zakatDueAmount > 0 {
                    zakatDueCard
                } else if vm.isAboveNisab && hasActiveAssets {
                    estimatedZakatCard
                }

                if !hasActiveAssets {
                    setupCard
                } else if vm.goldPricePerGram > 0 && !vm.isAboveNisab {
                    belowNisabWarning
                    progressToNisabSection
                }

                bottomButtons

                disclaimer
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Zakat tracker")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AnalyticsView()
                } label: {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await reload(force: false) }
        .refreshable { await reload(force: true) }
        .sheet(isPresented: $showingPaymentSheet) {
            NavigationStack { PaymentView(hawlRecord: vm.currentHawl) }
        }
        .sheet(isPresented: $showingAddAsset) {
            NavigationStack { AddAssetView(vm: addAssetVM) }
        }
    }

    // MARK: - Ring

    private var ringSection: some View {
        let state: HawlRing.State = {
            if vm.isAboveNisab && vm.currentHawl != nil {
                return .active(
                    elapsedDays: elapsedDays,
                    totalDays: totalDaysInHawl,
                    daysRemaining: vm.daysRemainingInHawl
                )
            }
            return .paused
        }()
        return HawlRing(state: state)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    private func aboveNisabIndicator(hawl: HawlRecord) -> some View {
        HStack(spacing: 8) {
            Circle().fill(AppTheme.accent).frame(width: 8, height: 8)
            Text("Above nisab since \(shortHijri(hawl.hawlStartDate))")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Stat pair

    private var statPair: some View {
        HStack(spacing: 12) {
            StatCard(label: "Zakatable wealth", amount: vm.totalZakatableWealth)
            StatCard(label: "Current nisab",    amount: vm.currentNisab)
        }
    }

    // MARK: - Zakat cards

    private var estimatedZakatCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimated Zakat due")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            CurrencyText(amount: vm.totalZakatableWealth * ZakatEngine.zakatRate)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
            Text("2.5% of zakatable wealth on due date")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.accentSoft, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
        )
    }

    private var zakatDueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Zakat is due")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(AppTheme.warning)
            }
            CurrencyText(amount: vm.zakatDueAmount)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
            Text("Your hawl cycle has completed.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                showingPaymentSheet = true
            } label: {
                Text("Record payment")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent, in: .rect(cornerRadius: 10))
                    .foregroundStyle(Color.black.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.accentSoft, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Below nisab

    private var belowNisabWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)
            Text("Your wealth is below the nisab threshold. The countdown will resume automatically when your assets exceed \(vm.currentNisab.formatted(.currency(code: "USD"))).")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.warningSoft, in: .rect(cornerRadius: 12))
    }

    private var progressToNisabSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress to nisab")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(progressToNisabPercent)%")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            ProgressView(value: Double(progressToNisabPercent), total: 100)
                .progressViewStyle(.linear)
                .tint(AppTheme.warning)
            Text("\(amountBelowThreshold.formatted(.currency(code: "USD"))) below threshold")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: .rect(cornerRadius: 12))
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Get started", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            if !hasGoldKey {
                setupRow(symbol: "key.fill",
                         title: "Set your GoldAPI key",
                         detail: "Needed to compute the live nisab threshold.")
            }
            if !hasActiveAssets {
                setupRow(symbol: "link",
                         title: "Add your first asset",
                         detail: "Link an account via SimpleFIN or add a manual asset using the button below.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: .rect(cornerRadius: 12))
    }

    private func setupRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(AppTheme.accent).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(AppTheme.textPrimary)
                Text(detail).font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Bottom buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            actionButton(title: "+ Add asset") { showingAddAsset = true }
            actionButton(title: vm.isLoading ? "Refreshing…" : "Refresh") {
                Task { await reload(force: true) }
            }
            .disabled(vm.isLoading)
        }
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.card, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.divider, lineWidth: 1)
                )
        }
    }

    // MARK: - Banner / Disclaimer

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync issue").font(.subheadline.bold()).foregroundStyle(AppTheme.textPrimary)
                Text(message).font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                vm.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppTheme.warningSoft, in: .rect(cornerRadius: 12))
    }

    private var disclaimer: some View {
        Text("This app assists with Zakat calculation. Consult a qualified scholar for specific rulings.")
            .font(.caption2)
            .foregroundStyle(AppTheme.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }

    // MARK: - Reload

    private func reload(force: Bool) async {
        if let accessURL = KeychainService.load(key: KeychainKey.simplefinAccessURL) {
            vm.financialService = SimpleFINService(accessURL: accessURL)
        } else {
            vm.financialService = nil
        }
        if let apiKey = KeychainService.load(key: KeychainKey.goldAPIKey) {
            vm.goldPriceService = CachedGoldPriceService(primaryService: GoldAPIService(apiKey: apiKey))
        } else {
            vm.goldPriceService = nil
        }
        vm.currentHawl = activeHawl
        await vm.refresh(assets: assets, modelContext: modelContext, force: force)
    }

    private func shortHijri(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let label: String
    let amount: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            CurrencyText(amount: amount)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self, BudgetCategory.self, BudgetEntry.self, FinanceTransaction.self, AccountBalanceSnapshot.self], inMemory: true)
    .preferredColorScheme(.dark)
}
