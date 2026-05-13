import SwiftData
import SwiftUI

struct AssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @Bindable var asset: Asset
    @Bindable var vm: AssetViewModel

    @State private var editedBalance: Decimal
    @State private var editedWeight: Decimal
    @State private var showDeleteConfirm = false

    init(asset: Asset, vm: AssetViewModel) {
        self.asset = asset
        self.vm = vm
        self._editedBalance = State(initialValue: asset.currentBalance)
        self._editedWeight = State(initialValue: asset.weightInGrams ?? 0)
    }

    private var settings: AppSettings? { settingsList.first }
    private var isMetal: Bool { asset.category == .gold || asset.category == .silver }
    private var spotPrice: Decimal {
        switch asset.category {
        case .gold:   return settings?.cachedGoldPricePerGram ?? 0
        case .silver: return settings?.cachedSilverPricePerGram ?? 0
        default:      return 0
        }
    }

    var body: some View {
        Form {
            Section("Asset") {
                LabeledContent("Name", value: asset.name)
                LabeledContent("Category", value: asset.category.displayName)
                LabeledContent("Source", value: asset.source.displayName)
            }

            if isMetal && asset.source == .manual {
                Section("Weight") {
                    TextField("Grams", value: $editedWeight, format: .number)
                        .keyboardType(.decimalPad)
                    if spotPrice > 0 {
                        LabeledContent("Spot price") {
                            Text("\(spotPrice.formatted(.currency(code: "USD")))/g")
                        }
                        LabeledContent("Market value") {
                            CurrencyText(amount: editedWeight * spotPrice).bold()
                        }
                    } else {
                        Text("No live \(asset.category.displayName.lowercased()) price — refresh in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(isMetal && spotPrice > 0 ? "Value" : "Balance") {
                if asset.source == .manual && !(isMetal && spotPrice > 0 && editedWeight > 0) {
                    TextField("Balance", value: $editedBalance, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                } else {
                    LabeledContent("Balance") {
                        CurrencyText(amount: asset.currentBalance)
                    }
                    if let synced = asset.lastSyncedAt {
                        LabeledContent("Last synced") {
                            Text(synced, format: .dateTime)
                        }
                    }
                    if let id = asset.simplefinAccountId {
                        LabeledContent("Account ID", value: id)
                            .textSelection(.enabled)
                    }
                }
            }

            if asset.category == .retirement {
                Section("Retirement") {
                    TextField(
                        "Early withdrawal penalty %",
                        value: Binding(
                            get: { asset.earlyWithdrawalPenaltyPercent ?? 0 },
                            set: { asset.earlyWithdrawalPenaltyPercent = $0 }
                        ),
                        format: .number
                    )
                    .keyboardType(.decimalPad)
                    LabeledContent("Zakatable") {
                        CurrencyText(amount: asset.zakatableAmount)
                    }
                }
            }

            if let notes = asset.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            Section {
                Button("Delete Asset", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    persistChanges()
                    dismiss()
                }
            }
        }
        .confirmationDialog(
            "Delete \(asset.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                vm.deleteAsset(asset, context: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func persistChanges() {
        guard asset.source == .manual else {
            try? modelContext.save()
            return
        }
        if isMetal && editedWeight > 0 && spotPrice > 0 {
            vm.updateMetalWeight(
                asset: asset,
                weightInGrams: editedWeight,
                spotPricePerGram: spotPrice,
                context: modelContext
            )
        } else if editedBalance != asset.currentBalance {
            vm.updateManualBalance(asset: asset, newBalance: editedBalance, context: modelContext)
        } else {
            try? modelContext.save()
        }
    }
}
