import SwiftData
import SwiftUI

struct AssetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]

    @State private var vm = AssetViewModel()
    @State private var selectedAsset: Asset?
    @State private var showAddOptions = false

    private var simplefinAssets: [Asset] {
        assets.filter { $0.isActive && $0.source == .simplefin }
    }
    private var manualAssets: [Asset] {
        assets.filter { $0.isActive && $0.source == .manual }
    }
    private var total: Decimal {
        assets.filter(\.isActive).reduce(Decimal.zero) { $0 + $1.zakatableAmount }
    }

    var body: some View {
        List {
            if !simplefinAssets.isEmpty {
                Section("Linked accounts (SimpleFIN)") {
                    ForEach(simplefinAssets) { asset in
                        Button { selectedAsset = asset } label: {
                            AssetRow(asset: asset)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets, from: simplefinAssets) }
                }
            }

            if !manualAssets.isEmpty {
                Section("Manual assets") {
                    ForEach(manualAssets) { asset in
                        Button { selectedAsset = asset } label: {
                            AssetRow(asset: asset)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets, from: manualAssets) }
                }
            }

            if assets.filter(\.isActive).isEmpty {
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
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self], inMemory: true)
}
