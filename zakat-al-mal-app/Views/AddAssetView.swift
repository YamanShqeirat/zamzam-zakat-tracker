import SwiftData
import SwiftUI

struct AddAssetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @Bindable var vm: AssetViewModel

    @State private var name: String = ""
    @State private var category: AssetCategory = .cash
    @State private var balance: Decimal = 0
    @State private var weight: Decimal = 0
    @State private var weightUnit: WeightUnit = .grams
    @State private var notes: String = ""

    private var settings: AppSettings? { settingsList.first }
    private var isMetal: Bool { category == .gold || category == .silver }
    /// Spot price is stored per gram; expose a per-selected-unit figure too.
    private var spotPrice: Decimal {
        switch category {
        case .gold:   return settings?.cachedGoldPricePerGram ?? 0
        case .silver: return settings?.cachedSilverPricePerGram ?? 0
        default:      return 0
        }
    }
    private var spotPricePerUnit: Decimal { spotPrice * weightUnit.gramsPerUnit }
    /// Entered weight converted to canonical grams for storage/value.
    private var weightInGrams: Decimal { weight * weightUnit.gramsPerUnit }
    private var estimatedValue: Decimal {
        weightInGrams * spotPrice
    }
    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if isMetal {
            // Allow weight-based OR direct-USD entry as a fallback.
            return weight > 0 || balance > 0
        }
        return true
    }

    var body: some View {
        Form {
            Section("Asset") {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(AssetCategory.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.sfSymbol).tag(cat)
                    }
                }
            }

            if isMetal {
                Section("Weight") {
                    Picker("Unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Weight (\(weightUnit.abbrev))", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                    if spotPrice > 0 {
                        LabeledContent("Spot price") {
                            Text("\(spotPricePerUnit.formatted(.currency(code: "USD")))/\(weightUnit.abbrev)")
                        }
                        LabeledContent("Estimated value") {
                            CurrencyText(amount: estimatedValue).bold()
                        }
                    } else {
                        Text("No live \(category.displayName.lowercased()) price yet — refresh in Settings, or enter the USD value manually below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Value (USD)", value: $balance, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                    }
                }
            } else {
                Section("Balance") {
                    TextField("Amount", value: $balance, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                }
            }

            Section("Notes (optional)") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
        }
        .navigationTitle("Add Manual Asset")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }

    private func save() {
        let trimmedNotes = notes.isEmpty ? nil : notes
        if isMetal && weight > 0 && spotPrice > 0 {
            vm.addManualAsset(
                name: name.trimmingCharacters(in: .whitespaces),
                category: category,
                balance: estimatedValue,
                weightInGrams: weightInGrams,
                weightUnit: weightUnit,
                notes: trimmedNotes,
                context: modelContext
            )
        } else {
            vm.addManualAsset(
                name: name.trimmingCharacters(in: .whitespaces),
                category: category,
                balance: balance,
                weightInGrams: isMetal && weight > 0 ? weightInGrams : nil,
                weightUnit: weightUnit,
                notes: trimmedNotes,
                context: modelContext
            )
        }
    }
}

#Preview {
    NavigationStack { AddAssetView(vm: AssetViewModel()) }
        .modelContainer(for: [Asset.self, AppSettings.self], inMemory: true)
}
