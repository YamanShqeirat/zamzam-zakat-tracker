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
    var notificationsEnabled: Bool
    var hawlReminderDaysBefore: Int

    init() {
        self.id = UUID()
        self.goldPriceSource = "goldapi"
        self.notificationsEnabled = true
        self.hawlReminderDaysBefore = 7
    }
}
