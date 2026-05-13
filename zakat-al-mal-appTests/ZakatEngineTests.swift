import Foundation
import Testing
@testable import zakat_al_mal_app

struct ZakatEngineTests {
    let engine = ZakatEngine()

    // MARK: - totalZakatableWealth

    @Test func totalZakatableWealth_emptyList_isZero() {
        #expect(engine.totalZakatableWealth(assets: []) == 0)
    }

    @Test func totalZakatableWealth_sumsActiveAssets() {
        let cash = Asset(name: "Cash", category: .cash, source: .manual, currentBalance: 1000)
        let bank = Asset(name: "Bank", category: .bankAccount, source: .manual, currentBalance: 2500)
        let brokerage = Asset(name: "Brokerage", category: .brokerage, source: .simplefin, currentBalance: 12500)
        #expect(engine.totalZakatableWealth(assets: [cash, bank, brokerage]) == 16000)
    }

    @Test func totalZakatableWealth_excludesInactiveAssets() {
        let active = Asset(name: "Active", category: .cash, source: .manual, currentBalance: 1000)
        let inactive = Asset(name: "Inactive", category: .cash, source: .manual, currentBalance: 5000)
        inactive.isActive = false
        #expect(engine.totalZakatableWealth(assets: [active, inactive]) == 1000)
    }

    @Test func totalZakatableWealth_appliesRetirementPenalty() {
        let retirement = Asset(name: "401k", category: .retirement, source: .manual, currentBalance: 10000)
        retirement.earlyWithdrawalPenaltyPercent = 10
        #expect(engine.totalZakatableWealth(assets: [retirement]) == 9000)
    }

    @Test func totalZakatableWealth_retirementWithoutPenaltyUsesFullBalance() {
        let retirement = Asset(name: "IRA", category: .retirement, source: .manual, currentBalance: 10000)
        #expect(engine.totalZakatableWealth(assets: [retirement]) == 10000)
    }

    @Test func totalZakatableWealth_mixedCategoriesWithPenalty() {
        let cash = Asset(name: "Cash", category: .cash, source: .manual, currentBalance: 2000)
        let retirement = Asset(name: "401k", category: .retirement, source: .manual, currentBalance: 10000)
        retirement.earlyWithdrawalPenaltyPercent = 10
        // Cash full + retirement net of 10% = 2000 + 9000 = 11000
        #expect(engine.totalZakatableWealth(assets: [cash, retirement]) == 11000)
    }

    // MARK: - zakatDue

    @Test func zakatDue_onZero_isZero() {
        #expect(engine.zakatDue(on: 0) == 0)
    }

    @Test func zakatDue_calculatesTwoAndAHalfPercent() {
        #expect(engine.zakatDue(on: 1000) == 25)
        #expect(engine.zakatDue(on: 40000) == 1000)
        #expect(engine.zakatDue(on: 10000) == 250)
    }

    // MARK: - evaluateHawl

    @Test func evaluateHawl_whenWealthBelowNisab_resetsHawl() {
        let hawl = HawlRecord(startDate: Date(), wealthAtStart: 10000, nisabAtStart: 6205)
        let result = engine.evaluateHawl(
            hawlRecord: hawl,
            currentWealth: 5000,
            currentGoldPrice: 73, // nisab = 73 * 85 = 6205
            currentDate: Date()
        )
        #expect(result == .hawlReset)
    }

    @Test func evaluateHawl_whenAboveNisabMidCycle_isInProgress() {
        let start = Date()
        let hawl = HawlRecord(startDate: start, wealthAtStart: 10000, nisabAtStart: 6205)
        let current = start.addingTimeInterval(60 * 24 * 60 * 60) // 60 days later
        let result = engine.evaluateHawl(
            hawlRecord: hawl,
            currentWealth: 50000,
            currentGoldPrice: 73,
            currentDate: current
        )
        guard case .inProgress(let days) = result else {
            Issue.record("Expected .inProgress, got \(result)")
            return
        }
        #expect(days > 0)
    }

    @Test func evaluateHawl_whenHawlCompleteAndAboveNisab_returnsZakatDue() {
        // Hawl started 400 days ago — lunar year (~354 days) has elapsed.
        let start = Date().addingTimeInterval(-400 * 24 * 60 * 60)
        let hawl = HawlRecord(startDate: start, wealthAtStart: 10000, nisabAtStart: 6205)
        let result = engine.evaluateHawl(
            hawlRecord: hawl,
            currentWealth: 40000,
            currentGoldPrice: 73,
            currentDate: Date()
        )
        guard case .zakatDue(let amount) = result else {
            Issue.record("Expected .zakatDue, got \(result)")
            return
        }
        #expect(amount == 1000) // 40000 * 0.025
    }

    @Test func evaluateHawl_atExactNisabBoundary_doesNotReset() {
        let hawl = HawlRecord(startDate: Date(), wealthAtStart: 6205, nisabAtStart: 6205)
        let result = engine.evaluateHawl(
            hawlRecord: hawl,
            currentWealth: 6205, // exactly at threshold
            currentGoldPrice: 73,
            currentDate: Date()
        )
        // At-nisab is inclusive (>=), so it should not reset.
        if case .hawlReset = result {
            Issue.record("Wealth exactly at nisab should not trigger reset")
        }
    }

    @Test func evaluateHawl_belowNisabTakesPrecedenceOverCompletion() {
        // Even if the hawl end date has passed, dropping below nisab resets.
        let start = Date().addingTimeInterval(-400 * 24 * 60 * 60)
        let hawl = HawlRecord(startDate: start, wealthAtStart: 10000, nisabAtStart: 6205)
        let result = engine.evaluateHawl(
            hawlRecord: hawl,
            currentWealth: 1000, // far below nisab
            currentGoldPrice: 73,
            currentDate: Date()
        )
        #expect(result == .hawlReset)
    }
}
