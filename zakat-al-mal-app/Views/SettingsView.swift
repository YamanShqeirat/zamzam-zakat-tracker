import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    @Query private var assets: [Asset]
    @Query private var hawls: [HawlRecord]
    @Query private var payments: [ZakatPayment]
    @Query private var snapshots: [NisabSnapshot]

    @State private var showSimpleFINSetup = false
    @State private var showGoldKeySheet = false
    @State private var goldKeyDraft: String = ""
    @State private var goldRefreshing = false
    @State private var goldError: String?
    @State private var showResetConfirm = false

    private var settings: AppSettings? { settingsList.first }
    private var simpleFINConnected: Bool {
        KeychainService.load(key: KeychainKey.simplefinAccessURL) != nil
    }
    private var goldKeySet: Bool {
        KeychainService.load(key: KeychainKey.goldAPIKey) != nil
    }
    private var simplefinAssetCount: Int {
        assets.filter { $0.source == .simplefin && $0.isActive }.count
    }
    private var currentNisab: Decimal {
        NisabMonitor().nisabThreshold(goldPricePerGram: settings?.cachedGoldPricePerGram ?? 0)
    }

    var body: some View {
        Form {
            historySection
            simplefinSection
            goldSection
            notificationsSection
            nisabSection
            dataSection
        }
        .navigationTitle("Settings")
        .task {
            if settingsList.isEmpty {
                modelContext.insert(AppSettings())
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showSimpleFINSetup) {
            NavigationStack { SimpleFINSetupView() }
        }
        .sheet(isPresented: $showGoldKeySheet) {
            NavigationStack {
                GoldAPIKeyEntryView(initialValue: KeychainService.load(key: KeychainKey.goldAPIKey) ?? "") { newKey in
                    if newKey.isEmpty {
                        KeychainService.delete(key: KeychainKey.goldAPIKey)
                    } else {
                        try? KeychainService.save(key: KeychainKey.goldAPIKey, value: newKey)
                    }
                }
            }
        }
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all assets, hawl records, payments, and snapshots. Stored credentials are also cleared. This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var historySection: some View {
        Section {
            NavigationLink {
                HistoryView()
            } label: {
                Label("Zakat history", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    private var simplefinSection: some View {
        Section("SimpleFIN connection") {
            HStack {
                Circle()
                    .fill(simpleFINConnected ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(simpleFINConnected ? "Connected" : "Not connected")
            }
            if simpleFINConnected {
                LabeledContent("Accounts", value: "\(simplefinAssetCount) linked")
            }
            Button(simpleFINConnected ? "Reconfigure" : "Connect") {
                showSimpleFINSetup = true
            }
            if simpleFINConnected {
                Button("Disconnect", role: .destructive) {
                    KeychainService.delete(key: KeychainKey.simplefinAccessURL)
                }
            }
        }
    }

    private var goldSection: some View {
        Section("Metal prices") {
            LabeledContent("Source", value: settings?.goldPriceSource ?? "goldapi")
            if let price = settings?.cachedGoldPricePerGram, price > 0 {
                LabeledContent("Gold") {
                    Text("\(price.formatted(.currency(code: "USD")))/gram")
                }
            }
            if let price = settings?.cachedSilverPricePerGram, price > 0 {
                LabeledContent("Silver") {
                    Text("\(price.formatted(.currency(code: "USD")))/gram")
                }
            }
            if let last = settings?.lastGoldPriceRefresh {
                LabeledContent("Last updated") {
                    Text(last, format: .dateTime)
                }
            }
            Button(goldKeySet ? "Update GoldAPI key" : "Set GoldAPI key") {
                goldKeyDraft = KeychainService.load(key: KeychainKey.goldAPIKey) ?? ""
                showGoldKeySheet = true
            }
            if !goldKeySet {
                Text("Set a GoldAPI key to enable nisab calculations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await refreshMetalPrices() }
            } label: {
                HStack {
                    if goldRefreshing { ProgressView().controlSize(.small) }
                    Text(goldRefreshing ? "Refreshing…" : "Refresh now")
                }
            }
            .disabled(!goldKeySet || goldRefreshing)
            if let err = goldError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            if let settings = settings {
                Toggle("Notifications enabled", isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { settings.notificationsEnabled = $0; try? modelContext.save() }
                ))
                Stepper(
                    "Hawl reminder: \(settings.hawlReminderDaysBefore) day\(settings.hawlReminderDaysBefore == 1 ? "" : "s") before",
                    value: Binding(
                        get: { settings.hawlReminderDaysBefore },
                        set: { settings.hawlReminderDaysBefore = $0; try? modelContext.save() }
                    ),
                    in: 1...30
                )
            }
        }
    }

    private var nisabSection: some View {
        Section("Nisab") {
            LabeledContent("Method", value: "85g of gold")
            LabeledContent("Current threshold") {
                if let price = settings?.cachedGoldPricePerGram, price > 0 {
                    CurrencyText(amount: currentNisab)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button("Reset all data", role: .destructive) {
                showResetConfirm = true
            }
        }
    }

    // MARK: - Actions

    private func refreshMetalPrices() async {
        guard let apiKey = KeychainService.load(key: KeychainKey.goldAPIKey) else { return }
        goldRefreshing = true
        goldError = nil
        defer { goldRefreshing = false }
        let service = GoldAPIService(apiKey: apiKey)
        var errors: [String] = []
        do {
            let gold = try await service.fetchGoldPricePerGram()
            settings?.cachedGoldPricePerGram = gold
            settings?.lastGoldPriceRefresh = Date()
        } catch {
            errors.append("Gold: \(error.localizedDescription)")
        }
        do {
            let silver = try await service.fetchSilverPricePerGram()
            settings?.cachedSilverPricePerGram = silver
            settings?.lastSilverPriceRefresh = Date()
        } catch {
            errors.append("Silver: \(error.localizedDescription)")
        }
        try? modelContext.save()
        if !errors.isEmpty {
            goldError = errors.joined(separator: "\n")
        }
    }

    private func resetAll() {
        for a in assets { modelContext.delete(a) }
        for h in hawls { modelContext.delete(h) }
        for p in payments { modelContext.delete(p) }
        for s in snapshots { modelContext.delete(s) }
        KeychainService.delete(key: KeychainKey.simplefinAccessURL)
        KeychainService.delete(key: KeychainKey.goldAPIKey)
        if let s = settings {
            s.cachedGoldPricePerGram = nil
            s.lastGoldPriceRefresh = nil
            s.cachedSilverPricePerGram = nil
            s.lastSilverPriceRefresh = nil
        }
        try? modelContext.save()
        NotificationService.cancelAll()
    }
}

private struct GoldAPIKeyEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var key: String
    let onSave: (String) -> Void

    init(initialValue: String, onSave: @escaping (String) -> Void) {
        self._key = State(initialValue: initialValue)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("GoldAPI.io key") {
                TextField("x-access-token", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            }
            Section {
                Text("Sign up for a free key at goldapi.io. The free tier allows ~300 requests/month — the app uses about 30.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("GoldAPI Key")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(key.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self], inMemory: true)
}
