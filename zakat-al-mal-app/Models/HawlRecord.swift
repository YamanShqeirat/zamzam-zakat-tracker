import Foundation
import SwiftData

@Model
final class HawlRecord {
    var id: UUID
    var hawlStartDate: Date
    var hawlEndDate: Date
    var status: HawlStatus
    var zakatDueAmount: Decimal?
    var zakatPaidAmount: Decimal?
    var zakatPaidDate: Date?
    var wealthAtStart: Decimal
    var wealthAtEnd: Decimal?
    var nisabAtStart: Decimal
    var nisabAtEnd: Decimal?

    init(startDate: Date, wealthAtStart: Decimal, nisabAtStart: Decimal) {
        self.id = UUID()
        self.hawlStartDate = startDate
        self.status = .inProgress
        self.wealthAtStart = wealthAtStart
        self.nisabAtStart = nisabAtStart

        let hijri = Calendar(identifier: .islamicUmmAlQura)
        self.hawlEndDate = hijri.date(byAdding: .year, value: 1, to: startDate) ?? startDate
    }
}

enum HawlStatus: String, Codable {
    case inProgress
    case zakatDue
    case zakatPaid
    case reset
}
