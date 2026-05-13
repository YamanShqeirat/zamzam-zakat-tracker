import Foundation

struct NisabMonitor {
    static let nisabGoldGrams: Decimal = 85

    func nisabThreshold(goldPricePerGram: Decimal) -> Decimal {
        return goldPricePerGram * Self.nisabGoldGrams
    }

    func isAboveNisab(totalWealth: Decimal, goldPricePerGram: Decimal) -> Bool {
        return totalWealth >= nisabThreshold(goldPricePerGram: goldPricePerGram)
    }
}
