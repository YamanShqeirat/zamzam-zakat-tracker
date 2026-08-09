import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var simplefinAccessURL: String?
    var goldPriceSource: String
    var lastGoldPriceRefresh: Date?
    var cachedGoldPricePerGram: Decimal?
    var lastSilverPriceRefresh: Date?
    var cachedSilverPricePerGram: Decimal?
    var lastSimpleFINSync: Date?
    var notificationsEnabled: Bool
    var hawlReminderDaysBefore: Int

    /// End-of-month "review your expenses" reminder.
    var monthlyExpenseReminderEnabled: Bool = true
    /// Hour of day (0...23) the monthly reminder fires on the last day of the month.
    var monthlyExpenseReminderHour: Int = 20

    init() {
        self.id = UUID()
        self.goldPriceSource = "goldapi"
        self.notificationsEnabled = true
        self.hawlReminderDaysBefore = 7
        self.monthlyExpenseReminderEnabled = true
        self.monthlyExpenseReminderHour = 20
    }
}
