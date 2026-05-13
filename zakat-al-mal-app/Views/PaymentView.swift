import SwiftData
import SwiftUI

struct PaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ZakatPayment.date, order: .reverse) private var allPayments: [ZakatPayment]

    let hawlRecord: HawlRecord?

    @State private var amount: Decimal = 0
    @State private var recipient: String = ""
    @State private var notes: String = ""
    @State private var saveError: String?

    private let vm = PaymentViewModel()

    private var due: Decimal { hawlRecord?.zakatDueAmount ?? 0 }
    private var paid: Decimal { hawlRecord?.zakatPaidAmount ?? 0 }
    private var remaining: Decimal { max(0, due - paid) }
    private var paymentsForThisHawl: [ZakatPayment] {
        guard let id = hawlRecord?.id else { return [] }
        return allPayments.filter { $0.hawlRecordId == id }
    }

    private var canSubmit: Bool {
        hawlRecord != nil && amount > 0 && amount <= remaining + 0.01
    }

    var body: some View {
        Group {
            if hawlRecord == nil {
                noActiveHawlState
            } else {
                paymentForm
            }
        }
        .navigationTitle("Record Zakat Payment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .alert("Couldn't save payment", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var noActiveHawlState: some View {
        ContentUnavailableView {
            Label("No zakat is currently due", systemImage: "checkmark.seal")
        } description: {
            Text("Your hawl cycle is still in progress, or your wealth is below the nisab threshold. Open the Home tab to see current status.")
        }
    }

    private var paymentForm: some View {
        Form {
            Section("Status") {
                LabeledContent("Zakat Due") { CurrencyText(amount: due) }
                LabeledContent("Already Paid") { CurrencyText(amount: paid) }
                LabeledContent("Remaining") {
                    CurrencyText(amount: remaining).bold()
                }
            }

            Section("Payment") {
                TextField("Amount", value: $amount, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                TextField("Recipient (optional)", text: $recipient)
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
            }

            Section {
                Button {
                    amount = remaining
                } label: {
                    Label("Pay Full Amount", systemImage: "equal.circle")
                }
                .disabled(remaining <= 0)

                Button {
                    record()
                } label: {
                    Label("Record Payment", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }

            if !paymentsForThisHawl.isEmpty {
                Section("Payment history (this hawl)") {
                    ForEach(paymentsForThisHawl) { p in
                        PaymentRow(payment: p)
                    }
                }
            }
        }
    }

    private func record() {
        do {
            try vm.recordPayment(
                amount: amount,
                recipient: recipient.isEmpty ? nil : recipient,
                notes: notes.isEmpty ? nil : notes,
                hawlRecord: hawlRecord,
                context: modelContext
            )
            // If fully settled, close. Otherwise reset for another partial entry.
            if let hawl = hawlRecord,
               let total = hawl.zakatDueAmount,
               (hawl.zakatPaidAmount ?? 0) >= total {
                dismiss()
            } else {
                amount = 0
                recipient = ""
                notes = ""
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

struct PaymentRow: View {
    let payment: ZakatPayment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                CurrencyText(amount: payment.amount).font(.body.bold())
                Text(payment.date, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let r = payment.recipient, !r.isEmpty {
                    Text(r).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationStack { PaymentView(hawlRecord: nil) }
        .modelContainer(for: [HawlRecord.self, ZakatPayment.self], inMemory: true)
}
