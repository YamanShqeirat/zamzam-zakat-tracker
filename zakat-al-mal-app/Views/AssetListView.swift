import SwiftData
import SwiftUI

struct AssetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]

    @State private var vm = AssetViewModel()
    @State private var selectedAsset: Asset?
    @State private var showAddOptions = false

    private var activeAssets: [Asset] {
        assets.filter(\.isActive)
    }
    private var total: Decimal {
        activeAssets.reduce(Decimal.zero) { $0 + $1.zakatableAmount }
    }

    /// Active assets bucketed into their `AssetGroup`, sorted by category then
    /// name within each group.
    private func assets(in group: AssetGroup) -> [Asset] {
        activeAssets
            .filter { $0.category.group == group }
            .sorted {
                if $0.category != $1.category {
                    return $0.category.displayName < $1.category.displayName
                }
                return $0.name < $1.name
            }
    }

    private func groupTotal(_ group: AssetGroup) -> Decimal {
        assets(in: group).reduce(Decimal.zero) { $0 + $1.currentBalance }
    }

    var body: some View {
        List {
            ForEach(AssetGroup.allCases.sorted { $0.sortOrder < $1.sortOrder }) { group in
                let groupAssets = assets(in: group)
                if !groupAssets.isEmpty {
                    Section {
                        ForEach(groupAssets) { asset in
                            Button { selectedAsset = asset } label: {
                                AssetRow(asset: asset)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in delete(offsets, from: groupAssets) }
                    } header: {
                        HStack {
                            Label(group.displayName, systemImage: group.sfSymbol)
                            Spacer()
                            CurrencyText(amount: groupTotal(group))
                                .monospacedDigit()
                        }
                    }
                }
            }

            if activeAssets.isEmpty {
                ContentUnavailableView(
                    "No assets yet",
                    systemImage: "tray",
                    description: Text("Tap + to add a manual asset or link your accounts via SimpleFIN.")
                )
            }

            Section {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    CurrencyText(amount: total)
                        .font(.headline.monospacedDigit())
                }
            }
        }
        .navigationTitle("My Assets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddOptions = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog("Add asset", isPresented: $showAddOptions, titleVisibility: .visible) {
            Button("Add Manual Asset") { vm.showingAddAsset = true }
            Button("Link via SimpleFIN") { vm.showingSimpleFINSetup = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $vm.showingAddAsset) {
            NavigationStack { AddAssetView(vm: vm) }
        }
        .sheet(isPresented: $vm.showingSimpleFINSetup) {
            NavigationStack { SimpleFINSetupView() }
        }
        .sheet(item: $selectedAsset) { asset in
            NavigationStack { AssetDetailView(asset: asset, vm: vm) }
        }
    }

    private func delete(_ offsets: IndexSet, from list: [Asset]) {
        for index in offsets {
            vm.deleteAsset(list[index], context: modelContext)
        }
    }
}

private struct AssetRow: View {
    let asset: Asset

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: asset.category.sfSymbol)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(asset.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(asset.source == .simplefin ? "· SimpleFIN" : "· Manual")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let synced = asset.lastSyncedAt {
                        Text("· synced \(synced, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            CurrencyText(amount: asset.currentBalance)
                .font(.body.monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { AssetListView() }
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self, BudgetCategory.self, BudgetEntry.self, FinanceTransaction.self, AccountBalanceSnapshot.self], inMemory: true)
}
