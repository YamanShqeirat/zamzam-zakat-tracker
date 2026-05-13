import Foundation
import Observation
import SwiftData

@Observable
final class PaymentViewModel {
    func recordPayment(
        amount: Decimal,
        recipient: String?,
        notes: String?,
        hawlRecord: HawlRecord?,
        context: ModelContext
    ) throws {
        let payment = ZakatPayment(amount: amount, date: Date(), recipient: recipient)
        payment.hawlRecordId = hawlRecord?.id
        payment.notes = notes
        context.insert(payment)

        if let hawl = hawlRecord {
            let totalPaid = (hawl.zakatPaidAmount ?? 0) + amount
            hawl.zakatPaidAmount = totalPaid
            if let due = hawl.zakatDueAmount, totalPaid >= due {
                hawl.status = .zakatPaid
                hawl.zakatPaidDate = Date()
            }
        }

        try context.save()
    }
}
