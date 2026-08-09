import Charts
import SwiftData
import SwiftUI

/// The "Budget" tab: a monthly entry grid mirroring the user's spreadsheet plus
/// the income/expense charts. Typing a figure into a category updates the
/// charts live via `@Query`. Tapping a category opens `CategoryDetailView` for
/// optional itemised transactions.
struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [BudgetCategory]
    @Query private var entries: [BudgetEntry]
    @Query private var transactions: [FinanceTransaction]

    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var showingAddCategory = false
    @State private var detailCategory: BudgetCategory?

    private static let monthNames = Calendar.current.shortMonthSymbols

    private var calc: BudgetCalculator {
        BudgetCalculator(categories: categories, entries: entries, transactions: transactions)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                monthSelector
                entrySection(kind: .income)
                entrySection(kind: .expense)
                incomeVsExpenditureCard
                byMonthCard
                topExpensesCard
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Budget")
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack { AddCategoryView(nextSortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1) }
        }
        .sheet(item: $detailCategory) { category in
            NavigationStack {
                CategoryDetailView(category: category, year: selectedYear, month: selectedMonth)
            }
        }
    }

    // MARK: - Month selector

    private var monthSelector: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(1...12, id: \.self) { m in
                    Button(Self.monthNames[m - 1]) { selectedMonth = m }
                }
            } label: {
                selectorChip(text: Self.monthNames[selectedMonth - 1], systemImage: "calendar")
            }

            HStack(spacing: 0) {
                Button { selectedYear -= 1 } label: {
                    Image(systemName: "chevron.left").padding(8)
                }
                Text(String(selectedYear))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(minWidth: 52)
                Button { selectedYear += 1 } label: {
                    Image(systemName: "chevron.right").padding(8)
                }
            }
            .foregroundStyle(AppTheme.accent)
            .background(AppTheme.card, in: .capsule)

            Spacer()
        }
    }

    private func selectorChip(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text).font(.subheadline.bold())
            Image(systemName: "chevron.down").font(.caption2)
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.card, in: .capsule)
    }

    // MARK: - Entry grid

    private func entrySection(kind: BudgetKind) -> some View {
        let cats = calc.activeCategories(kind)
        let total = kind == .income
            ? cats.reduce(Decimal.zero) { $0 + calc.effectiveAmount(categoryId: $1.id, year: selectedYear, month: selectedMonth) }
            : cats.reduce(Decimal.zero) { $0 + calc.effectiveAmount(categoryId: $1.id, year: selectedYear, month: selectedMonth) }

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(kind.displayName.uppercased())
                    .font(.caption2.bold())
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                CurrencyText(amount: total)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(kind == .income ? AppTheme.accent : AppTheme.warning)
            }
            .padding(.bottom, 8)

            if cats.isEmpty {
                Text("No categories yet. Tap + to add one.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(cats) { category in
                        BudgetRow(
                            category: category,
                            entry: entry(for: category.id),
                            derivedAmount: calc.effectiveAmount(categoryId: category.id, year: selectedYear, month: selectedMonth),
                            isDerived: calc.isDerived(categoryId: category.id, year: selectedYear, month: selectedMonth),
                            onCommit: { amount in commit(amount, for: category) },
                            onTapDetail: { detailCategory = category }
                        )
                        .id("\(category.id)-\(selectedYear)-\(selectedMonth)")
                        if category.id != cats.last?.id {
                            Divider().background(AppTheme.divider)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }

    private func entry(for categoryId: UUID) -> BudgetEntry? {
        entries.first { $0.categoryId == categoryId && $0.year == selectedYear && $0.month == selectedMonth }
    }

    /// Persist a manual amount for the selected month (nil clears it, reverting
    /// to the itemised-transaction sum). Writes through the context so `@Query`
    /// recomputes the charts immediately.
    private func commit(_ amount: Decimal?, for category: BudgetCategory) {
        if let existing = entry(for: category.id) {
            existing.manualAmount = amount
        } else if amount != nil {
            modelContext.insert(BudgetEntry(
                categoryId: category.id,
                year: selectedYear,
                month: selectedMonth,
                manualAmount: amount
            ))
        }
        try? modelContext.save()
    }

    // MARK: - Charts

    private var incomeVsExpenditureCard: some View {
        let income = calc.totalIncome(year: selectedYear)
        let expense = calc.totalExpense(year: selectedYear)
        let data = [
            SummaryBar(label: "Income", amount: income, color: AppTheme.accent),
            SummaryBar(label: "Expenses", amount: expense, color: AppTheme.warning),
        ]
        return chartCard(title: "TOTAL INCOME VS EXPENDITURE") {
            if income == 0 && expense == 0 {
                chartEmpty
            } else {
                Chart(data) { bar in
                    BarMark(x: .value("Kind", bar.label), y: .value("Amount", bar.amount.asDouble))
                        .foregroundStyle(bar.color)
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            Text(compactCurrency(bar.amount.asDouble))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                }
                .chartYAxis { yAxis }
                .frame(height: 180)
            }
        }
    }

    private var byMonthCard: some View {
        let incomeByMonth = calc.monthlyTotals(kind: .income, year: selectedYear)
        let expenseByMonth = calc.monthlyTotals(kind: .expense, year: selectedYear)
        var data: [MonthBar] = []
        for m in 1...12 {
            data.append(MonthBar(month: m, series: "Income", amount: incomeByMonth[m - 1]))
            data.append(MonthBar(month: m, series: "Expenses", amount: expenseByMonth[m - 1]))
        }
        let hasData = data.contains { $0.amount > 0 }
        return chartCard(title: "INCOME VS EXPENSES BY MONTH") {
            if !hasData {
                chartEmpty
            } else {
                Chart(data) { bar in
                    BarMark(
                        x: .value("Month", Self.monthNames[bar.month - 1]),
                        y: .value("Amount", bar.amount.asDouble)
                    )
                    .foregroundStyle(by: .value("Series", bar.series))
                    .position(by: .value("Series", bar.series))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(["Income": AppTheme.accent, "Expenses": AppTheme.warning])
                .chartLegend(position: .bottom, spacing: 8)
                .chartYAxis { yAxis }
                .frame(height: 220)
            }
        }
    }

    private var topExpensesCard: some View {
        let data = calc.expenseByCategory(year: selectedYear)
        return chartCard(title: "TOTAL EXPENSES BY CATEGORY") {
            if data.isEmpty {
                chartEmpty
            } else {
                Chart(data, id: \.category.id) { entry in
                    BarMark(
                        x: .value("Amount", entry.total.asDouble),
                        y: .value("Category", entry.category.name)
                    )
                    .foregroundStyle(entry.category.color)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisGridLine().foregroundStyle(AppTheme.divider)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(compactCurrency(v))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { AxisValueLabel().font(.caption2).foregroundStyle(AppTheme.textTertiary) }
                }
                .frame(height: CGFloat(max(120, data.count * 34)))
            }
        }
    }

    private var yAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(AppTheme.divider)
            AxisValueLabel {
                if let v = value.as(Double.self) {
                    Text(compactCurrency(v))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
    }

    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(AppTheme.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }

    private var chartEmpty: some View {
        Text("Enter some figures above to see this chart.")
            .font(.footnote)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.vertical, 8)
    }
}

// MARK: - Budget row

private struct BudgetRow: View {
    let category: BudgetCategory
    let entry: BudgetEntry?
    let derivedAmount: Decimal
    let isDerived: Bool
    let onCommit: (Decimal?) -> Void
    let onTapDetail: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(category.color).frame(width: 8, height: 8)

            Button(action: onTapDetail) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.name)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textPrimary)
                    if isDerived && derivedAmount > 0 {
                        Text("from items")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 96)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(AppTheme.background, in: .rect(cornerRadius: 8))
                .focused($focused)
                .onChange(of: text) { _, newValue in
                    commit(newValue)
                }
                .toolbar {
                    if focused {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { focused = false }
                                .fontWeight(.semibold)
                        }
                    }
                }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
                .onTapGesture(perform: onTapDetail)
        }
        .padding(.vertical, 8)
        .onAppear { syncText() }
    }

    /// Show the manual amount if one is set, else leave the field empty so the
    /// "from items" derived total shows through as context.
    private func syncText() {
        if let manual = entry?.manualAmount {
            text = Self.plain(manual)
        } else {
            text = ""
        }
    }

    private func commit(_ raw: String) {
        let cleaned = raw.filter { $0.isNumber || $0 == "." }
        if cleaned.isEmpty {
            onCommit(nil)
        } else if let value = Decimal(string: cleaned) {
            onCommit(value)
        }
    }

    private static func plain(_ amount: Decimal) -> String {
        // Drop a trailing ".0" for whole numbers so the field reads cleanly.
        if amount == amount.rounded() {
            return "\((amount as NSDecimalNumber).intValue)"
        }
        return "\((amount as NSDecimalNumber).doubleValue)"
    }
}

private extension Decimal {
    func rounded() -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, 0, .plain)
        return result
    }
}

// MARK: - Chart data

private struct SummaryBar: Identifiable {
    let id = UUID()
    let label: String
    let amount: Decimal
    let color: Color
}

private struct MonthBar: Identifiable {
    let id = UUID()
    let month: Int
    let series: String
    let amount: Decimal
}

#Preview {
    NavigationStack { BudgetView() }
        .modelContainer(for: [Asset.self, HawlRecord.self, NisabSnapshot.self, ZakatPayment.self, AppSettings.self, BudgetCategory.self, BudgetEntry.self, FinanceTransaction.self, AccountBalanceSnapshot.self], inMemory: true)
        .preferredColorScheme(.dark)
}
