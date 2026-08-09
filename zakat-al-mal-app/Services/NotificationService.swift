import Foundation
import UserNotifications

/// Local notifications for hawl + sync events.
///
/// Notification copy is taken verbatim from the build spec — do not paraphrase.
/// Identifiers are stable so subsequent calls *replace* a pending request
/// rather than stacking duplicates.
enum NotificationService {
    enum Identifier {
        static let hawlReminder         = "zakat.hawl-reminder"
        static let zakatDue             = "zakat.zakat-due"
        static let syncFailure          = "zakat.sync-failure"
        static let hawlReset            = "zakat.hawl-reset"
        static let monthlyExpenseReview = "zakat.monthly-expense-review"
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// Schedule the "hawl completing soon" reminder at a future fire date.
    /// `daysBefore` and `estimatedZakat` are substituted into the body.
    static func scheduleHawlReminder(
        at fireDate: Date,
        daysBefore: Int,
        estimatedZakat: Decimal
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Hawl Completing Soon"
        content.body = "Your lunar year cycle completes in \(daysBefore) days. Current estimated zakat: \(currency(estimatedZakat))"
        content.sound = .default
        schedule(content: content, fireDate: fireDate, identifier: Identifier.hawlReminder)
    }

    /// Fire "Zakat Is Due" — used when a hawl transitions to .zakatDue.
    static func notifyZakatDue(estimatedZakat: Decimal, wealth: Decimal) {
        let content = UNMutableNotificationContent()
        content.title = "Zakat Is Due"
        content.body = "Your hawl cycle has completed. \(currency(estimatedZakat)) in zakat is due on your zakatable wealth of \(currency(wealth))"
        content.sound = .default
        fireSoon(content: content, identifier: Identifier.zakatDue)
    }

    /// Fire "Sync Issue" when SimpleFIN balances haven't refreshed for N days.
    static func notifySyncFailure(daysWithoutSync: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Sync Issue"
        content.body = "Account balances haven't updated in \(daysWithoutSync) days. Open the app to check your connection."
        content.sound = .default
        fireSoon(content: content, identifier: Identifier.syncFailure)
    }

    /// Fire "Hawl Reset" when wealth dropped below nisab.
    static func notifyHawlReset() {
        let content = UNMutableNotificationContent()
        content.title = "Hawl Reset"
        content.body = "Your zakatable wealth has dropped below the nisab threshold. Your hawl has been reset and will restart when your wealth reaches nisab again."
        content.sound = .default
        fireSoon(content: content, identifier: Identifier.hawlReset)
    }

    /// Schedule the end-of-month "review your expenses" reminder for the last
    /// day of the current month at `hour`. If that moment has already passed,
    /// target next month instead. Non-repeating under a stable id, so re-arming
    /// on launch / daily sync keeps it perpetually one month ahead.
    static func scheduleMonthlyExpenseReview(hour: Int) {
        guard let fireDate = nextMonthEndReviewDate(hour: hour) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to review your expenses"
        content.body = "The month is wrapping up — take a minute to review this month's income and spending."
        content.sound = .default
        schedule(content: content, fireDate: fireDate, identifier: Identifier.monthlyExpenseReview)
    }

    /// Last day of the current month at `hour`; rolls to next month's last day
    /// once the current one is in the past.
    static func nextMonthEndReviewDate(hour: Int, now: Date = Date()) -> Date? {
        let cal = Calendar.current
        func lastDay(monthsFromNow: Int) -> Date? {
            guard let monthStart = cal.date(byAdding: .month, value: monthsFromNow,
                                            to: cal.date(from: cal.dateComponents([.year, .month], from: now))!),
                  let range = cal.range(of: .day, in: .month, for: monthStart) else { return nil }
            var comps = cal.dateComponents([.year, .month], from: monthStart)
            comps.day = range.count
            comps.hour = max(0, min(23, hour))
            comps.minute = 0
            return cal.date(from: comps)
        }
        if let thisMonth = lastDay(monthsFromNow: 0), thisMonth > now {
            return thisMonth
        }
        return lastDay(monthsFromNow: 1)
    }

    static func cancel(identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Private

    private static func schedule(
        content: UNMutableNotificationContent,
        fireDate: Date,
        identifier: String
    ) {
        cancel(identifier: identifier)
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private static func fireSoon(content: UNMutableNotificationContent, identifier: String) {
        schedule(content: content, fireDate: Date().addingTimeInterval(2), identifier: identifier)
    }

    private static func currency(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "USD"))
    }
}
