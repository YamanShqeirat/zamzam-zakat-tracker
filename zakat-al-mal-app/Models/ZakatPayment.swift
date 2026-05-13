import Foundation
import SwiftData

@Model
final class ZakatPayment {
    var id: UUID
    var amount: Decimal
    var date: Date
    var recipient: String?
    var notes: String?
    var hawlRecordId: UUID?

    init(amount: Decimal, date: Date, recipient: String? = nil) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.recipient = recipient
    }
}
