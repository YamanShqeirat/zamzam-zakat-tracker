import Foundation

struct ZakatEngine {
    let nisabMonitor = NisabMonitor()
    let hawlTracker = HawlTracker()
    static let zakatRate: Decimal = 0.025

    func totalZakatableWealth(assets: [Asset]) -> Decimal {
        assets
            .filter { $0.isActive }
            .reduce(Decimal.zero) { $0 + $1.zakatableAmount }
    }

    func zakatDue(on totalWealth: Decimal) -> Decimal {
        return totalWealth * Self.zakatRate
    }

    func evaluateHawl(
        hawlRecord: HawlRecord,
        currentWealth: Decimal,
        currentGoldPrice: Decimal,
        currentDate: Date
    ) -> HawlEvaluation {
        let currentNisab = nisabMonitor.nisabThreshold(goldPricePerGram: currentGoldPrice)

        if currentWealth < currentNisab {
            return .hawlReset
        }

        let isComplete = hawlTracker.isHawlComplete(
            startDate: hawlRecord.hawlStartDate,
            currentDate: currentDate
        )

        if isComplete {
            return .zakatDue(amount: zakatDue(on: currentWealth))
        } else {
            let daysLeft = hawlTracker.daysRemaining(
                from: currentDate,
                hawlEnd: hawlRecord.hawlEndDate
            )
            return .inProgress(daysRemaining: daysLeft)
        }
    }
}

enum HawlEvaluation: Equatable {
    case inProgress(daysRemaining: Int)
    case zakatDue(amount: Decimal)
    case hawlReset
}
