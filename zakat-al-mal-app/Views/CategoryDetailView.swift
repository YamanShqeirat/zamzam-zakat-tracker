import SwiftData
import SwiftUI

/// Palette offered when creating / recolouring a budget category.
enum BudgetPalette {
    static let colors: [UInt32] = [
        0x2DD4A8, 0x8B5CF6, 0x3B82F6, 0xFB923C, 0xEF4444,
        0xF59E0B, 0x06B6D4, 0xEC4899, 0xA3E635, 0x64748B, 0x9CA3AF,
    ]
}

/// Itemised transactions, notes, and category settings for one category in a
/// given month. Reached by tapping a row in the Budget grid.
struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let category: BudgetCategory
    let year: Int
    let month: Int

    @Query private var allTransactions: [FinanceTransaction]
    @Query private var allEntries: [BudgetEntry]

    @State private var newAmount = ""
    @State private var newNote = ""

    private var monthTransactions: [FinanceTransaction] {
        allTransactions
            .filter { txn in
                guard txn.categoryId == category.id else { return false }
                let c = Calendar.current.dateComponents([.year, .month], from: txn.date)
                return c.year == year && c.month == month
            }
            .sorted { $0.date > $1.date }
    }

    private var entry: BudgetEntry? {
        allEntries.first { $0.categoryId == category.id && $0.year == year && $0.month == month }
    }

    private var itemisedTotal: Decimal {
        monthTransactions.reduce(.zero) { $0 + $1.amount }
    }

    private var monthName: String {
        Calendar.current.monthSymbols[month - 1]
    }

    var body: some View {
        Form {
            manualSection
            itemisedSection
            notesSection
            categorySection
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground().ignoresSafeArea())
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Manual override

    private var manualSection: some View {
        Section {
            if let manual = entry?.manualAmount {
                HStack {
                    Text("Manual total")
                    Spacer()
                    CurrencyText(amount: manual).foregroundStyle(AppTheme.textSecondary)
                }
                Button("Clear manual total", role: .destructive) {
                    entry?.manualAmount = nil
                    try? modelContext.save()
                }
            } else {
                Text("This month uses the itemised total below. Enter a lump sum in the Budget grid to override it.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } header: {
            Text("\(monthName) \(String(year))")
        }
        .listRowBackground(AppTheme.card)
    }

    // MARK: - Itemised transactions

    private var itemisedSection: some View {
        Section {
            ForEach(monthTransactions) { txn in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(txn.note?.isEmpty == false ? txn.note! : "Item")
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(txn.date.formatted(.dateTime.month().day()))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer()
                    CurrencyText(amount: txn.amount)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .onDelete(perform: deleteTransactions)

            HStack(spacing: 8) {
                TextField("Amount", text: $newAmount)
                    .keyboardType(.decimalPad)
                    .frame(width: 90)
                TextField("Note (optional)", text: $newNote)
                Button {
                    addTransaction()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(parsedNewAmount == nil)
            }
        } header: {
            HStack {
                Text("Itemised")
                Spacer()
                Text(itemisedTotal.currencyString)
            }
        }
        .listRowBackground(AppTheme.card)
    }

    private var parsedNewAmount: Decimal? {
        let cleaned = newAmount.filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }

    private func addTransaction() {
        guard let amount = parsedNewAmount else { return }
        // Date within the selected month so it rolls up into this cell.
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 15)) ?? Date()
        modelContext.insert(FinanceTransaction(
            categoryId: category.id,
            date: date,
            amount: amount,
            note: newNote.isEmpty ? nil : newNote
        ))
        try? modelContext.save()
        newAmount = ""
        newNote = ""
    }

    private func deleteTransactions(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(monthTransactions[index])
        }
        try? modelContext.save()
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes for this month", text: notesBinding, axis: .vertical)
                .lineLimit(2...4)
        }
        .listRowBackground(AppTheme.card)
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { entry?.notes ?? "" },
            set: { newValue in
                if let entry {
                    entry.notes = newValue.isEmpty ? nil : newValue
                } else if !newValue.isEmpty {
                    modelContext.insert(BudgetEntry(categoryId: category.id, year: year, month: month, notes: newValue))
                }
                try? modelContext.save()
            }
        )
    }

    // MARK: - Category settings

    private var categorySection: some View {
        Section("Category") {
            TextField("Name", text: Binding(
                get: { category.name },
                set: { category.name = $0; try? modelContext.save() }
            ))
            colorPicker
            Toggle("Archived", isOn: Binding(
                get: { category.isArchived },
                set: { category.isArchived = $0; try? modelContext.save() }
            ))
        }
        .listRowBackground(AppTheme.card)
    }

    private var colorPicker: some View {
        HStack {
            Text("Colour")
            Spacer()
            HStack(spacing: 8) {
                ForEach(BudgetPalette.colors, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: category.colorHex == hex ? 2 : 0)
                        )
                        .onTapGesture {
                            category.colorHex = hex
                            try? modelContext.save()
                        }
                }
            }
        }
    }
}

// MARK: - Add category

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let nextSortOrder: Int

    @State private var name = ""
    @State private var kind: BudgetKind = .expense
    @State private var colorHex: UInt32 = BudgetPalette.colors[0]

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Type", selection: $kind) {
                    ForEach(BudgetKind.allCases) { Text($0.displayName).tag($0) }
                }
            }
            .listRowBackground(AppTheme.card)

            Section("Colour") {
                HStack(spacing: 10) {
                    ForEach(BudgetPalette.colors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(Color.white, lineWidth: colorHex == hex ? 2 : 0))
                            .onTapGesture { colorHex = hex }
                    }
                }
            }
            .listRowBackground(AppTheme.card)
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground().ignoresSafeArea())
        .navigationTitle("New category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { add() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func add() {
        modelContext.insert(BudgetCategory(
            name: name.trimmingCharacters(in: .whitespaces),
            kind: kind,
            colorHex: colorHex,
            sortOrder: nextSortOrder
        ))
        try? modelContext.save()
        dismiss()
    }
}
