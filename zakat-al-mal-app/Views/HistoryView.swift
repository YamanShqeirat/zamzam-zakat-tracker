import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \HawlRecord.hawlStartDate, order: .reverse) private var hawls: [HawlRecord]
    @Query(sort: \ZakatPayment.date, order: .reverse) private var payments: [ZakatPayment]

    private let hawlTracker = HawlTracker()

    private var currentHawl: HawlRecord? {
        hawls.first { $0.status == .inProgress || $0.status == .zakatDue }
    }
    private var pastHawls: [HawlRecord] {
        hawls.filter { $0.status == .zakatPaid || $0.status == .reset }
    }

    var body: some View {
        List {
            Section("Current cycle") {
                if let hawl = currentHawl {
                    HawlSummaryRow(hawl: hawl, isCurrent: true)
                } else {
                    Text("No active hawl. A new cycle starts when your wealth reaches nisab.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Past cycles") {
                if pastHawls.isEmpty {
                    Text("None yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pastHawls) { hawl in
                        HawlSummaryRow(hawl: hawl, isCurrent: false)
                    }
                }
            }

            Section("All payments") {
                if payments.isEmpty {
                    Text("None yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(payments) { p in
                        PaymentRow(payment: p)
                    }
                }
            }
        }
        .navigationTitle("Zakat History")
    }
}

private struct HawlSummaryRow: View {
    let hawl: HawlRecord
    let isCurrent: Bool

    private let hawlTracker = HawlTracker()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Hawl: \(hijri(hawl.hawlStartDate)) → \(hijri(hawl.hawlEndDate))")
                    .font(.footnote)
                Spacer()
                StatusChip(status: hawl.status)
            }
            HStack {
                Text("Start wealth")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                CurrencyText(amount: hawl.wealthAtStart).font(.caption.monospacedDigit())
            }
            if let end = hawl.wealthAtEnd {
                HStack {
                    Text("End wealth")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CurrencyText(amount: end).font(.caption.monospacedDigit())
                }
            }
            if let due = hawl.zakatDueAmount {
                HStack {
                    Text("Zakat due")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CurrencyText(amount: due).font(.caption.monospacedDigit())
                }
            }
            if let paid = hawl.zakatPaidAmount, paid > 0 {
                HStack {
                    Text("Zakat paid")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CurrencyText(amount: paid).font(.caption.monospacedDigit())
                }
            }
            if isCurrent {
                let total = max(1, Calendar.current.dateComponents([.day], from: hawl.hawlStartDate, to: hawl.hawlEndDate).day ?? 354)
                let remaining = hawlTracker.daysRemaining(from: Date(), hawlEnd: hawl.hawlEndDate)
                let elapsed = max(0, total - remaining)
                HawlProgressBar(elapsedDays: elapsed, totalDays: total, daysRemaining: remaining)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func hijri(_ date: Date) -> String {
        hawlTracker.hijriDateString(for: date)
    }
}

private struct StatusChip: View {
    let status: HawlStatus

    private var label: String {
        switch status {
        case .inProgress: return "In Progress"
        case .zakatDue:   return "Zakat Due"
        case .zakatPaid:  return "Paid"
        case .reset:      return "Reset"
        }
    }

    private var color: Color {
        switch status {
        case .inProgress: return .blue
        case .zakatDue:   return .orange
        case .zakatPaid:  return .green
        case .reset:      return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .modelContainer(for: [HawlRecord.self, ZakatPayment.self], inMemory: true)
}
