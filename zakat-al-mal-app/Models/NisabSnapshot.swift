import Foundation
import SwiftData

@Model
final class NisabSnapshot {
    var id: UUID
    var date: Date
    var goldPricePerGram: Decimal
    var nisabThresholdUSD: Decimal
    var totalZakatableWealth: Decimal
    var isAboveNisab: Bool

    init(date: Date, goldPricePerGram: Decimal, totalZakatableWealth: Decimal) {
        self.id = UUID()
        self.date = date
        self.goldPricePerGram = goldPricePerGram
        let threshold = goldPricePerGram * NisabMonitor.nisabGoldGrams
        self.nisabThresholdUSD = threshold
        self.totalZakatableWealth = totalZakatableWealth
        self.isAboveNisab = totalZakatableWealth >= threshold
    }
}
