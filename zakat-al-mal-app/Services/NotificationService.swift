import Foundation
import UserNotifications

/// Local notifications for hawl + sync events.
///
/// Notification copy is taken verbatim from the build spec — do not paraphrase.
/// Identifiers are stable so subsequent calls *replace* a pending request
/// rather than stacking duplicates.
enum NotificationService {
    enum Identifier {
        static let hawlReminder = "zakat.hawl-reminder"
        static let zakatDue     = "zakat.zakat-due"
        static let syncFailure  = "zakat.sync-failure"
        static let hawlReset    = "zakat.hawl-reset"
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
