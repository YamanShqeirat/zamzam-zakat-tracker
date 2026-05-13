import Foundation

// NOTE: This file is a verbatim copy of the main app's SharedAppGroup.swift.
// Keep the two in sync — the widget target compiles this one, the main app
// compiles its own. (Alternative: share a single file across both targets.)

enum SharedAppGroup {
    static let identifier = "group.com.yamanshqeirat.zakat-al-mal-app"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    enum Key {
        static let totalZakatableWealth = "totalZakatableWealth"
        static let currentNisab         = "currentNisab"
        static let daysRemaining        = "daysRemaining"
        static let estimatedZakat       = "estimatedZakat"
        static let isAboveNisab         = "isAboveNisab"
        static let hasData              = "hasData"
        static let lastUpdated          = "lastUpdated"
    }

    struct Snapshot {
        var totalZakatableWealth: Decimal = 0
        var currentNisab: Decimal = 0
        var daysRemaining: Int = 0
        var estimatedZakat: Decimal = 0
        var isAboveNisab: Bool = false
        var lastUpdated: Date? = nil
        var hasData: Bool = false
    }

    static func write(_ snapshot: Snapshot) {
        guard let defaults else { return }
        defaults.set(NSDecimalNumber(decimal: snapshot.totalZakatableWealth), forKey: Key.totalZakatableWealth)
        defaults.set(NSDecimalNumber(decimal: snapshot.currentNisab),         forKey: Key.currentNisab)
        defaults.set(snapshot.daysRemaining,                                  forKey: Key.daysRemaining)
        defaults.set(NSDecimalNumber(decimal: snapshot.estimatedZakat),       forKey: Key.estimatedZakat)
        defaults.set(snapshot.isAboveNisab,                                   forKey: Key.isAboveNisab)
        defaults.set(snapshot.lastUpdated ?? Date(),                          forKey: Key.lastUpdated)
        defaults.set(true,                                                    forKey: Key.hasData)
    }

    static func read() -> Snapshot {
        guard let defaults, defaults.bool(forKey: Key.hasData) else {
            return Snapshot()
        }
        return Snapshot(
            totalZakatableWealth: (defaults.object(forKey: Key.totalZakatableWealth) as? NSDecimalNumber)?.decimalValue ?? 0,
            currentNisab:         (defaults.object(forKey: Key.currentNisab)         as? NSDecimalNumber)?.decimalValue ?? 0,
            daysRemaining:        defaults.integer(forKey: Key.daysRemaining),
            estimatedZakat:       (defaults.object(forKey: Key.estimatedZakat)       as? NSDecimalNumber)?.decimalValue ?? 0,
            isAboveNisab:         defaults.bool(forKey: Key.isAboveNisab),
            lastUpdated:          defaults.object(forKey: Key.lastUpdated) as? Date,
            hasData:              true
        )
    }
}
