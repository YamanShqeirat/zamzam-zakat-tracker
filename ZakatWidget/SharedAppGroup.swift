// NOTE: This file is a verbatim copy of the main app's Services/SharedAppGroup.swift.
// Keep the two in sync — the widget target compiles this one, the main app
// compiles its own. (Alternative: share a single file across both targets.)

import Foundation

/// Read/write the snapshot the home-screen widgets render from.
/// Source of truth lives in SwiftData; this is a cached projection so the
/// widgets never have to load the database or make network calls.
///
/// Every chart in the app has a widget counterpart, so the snapshot carries the
/// series each one needs. Series are capped (see `WidgetSnapshotBuilder`) to
/// keep the payload small — app-group defaults are not a database.
///
/// **Requires** the "App Groups" capability on both the main app and the
/// widget extension, with the identifier below registered in the dev portal.
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
        static let breakdown            = "categoryBreakdown"
        static let hawlTotalDays        = "hawlTotalDays"
        static let lifetimeZakatPaid    = "lifetimeZakatPaid"
        static let wealthHistory        = "wealthHistory"
        static let giving               = "givingByHijriYear"
        static let accountHistory       = "accountHistory"
        static let budget               = "budgetSummary"
    }

    /// One slice of the distribution donut. `category` is the raw value of
    /// `AssetCategory` — the widget resolves it to a color/label via its own
    /// table so it doesn't have to depend on the main app's model.
    struct CategorySlice: Codable, Hashable {
        var category: String
        var amount: Decimal
    }

    /// One point of the wealth-vs-nisab trend line.
    struct WealthPoint: Codable, Hashable {
        var date: Date
        var wealth: Decimal
        var nisab: Decimal
    }

    /// Zakat paid in one Hijri year.
    struct GivingBucket: Codable, Hashable {
        var hijriYear: Int
        var amount: Decimal
    }

    /// One account's end-of-month balance.
    struct AccountPoint: Codable, Hashable {
        var year: Int
        /// 1...12
        var month: Int
        var account: String
        var balance: Decimal

        var date: Date? {
            Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }

    /// A budget category's yearly total, with the colour the app draws it in.
    struct CategoryTotal: Codable, Hashable {
        var name: String
        var colorHex: UInt32
        var amount: Decimal
    }

    /// Everything the budget widgets need for one calendar year.
    struct BudgetSummary: Codable, Hashable {
        var year: Int = 0
        /// 12 entries, January first. Empty when no budget data exists.
        var monthlyIncome: [Decimal] = []
        var monthlyExpense: [Decimal] = []
        /// Largest first.
        var expenseByCategory: [CategoryTotal] = []

        var totalIncome: Decimal { monthlyIncome.reduce(0, +) }
        var totalExpense: Decimal { monthlyExpense.reduce(0, +) }
        var balance: Decimal { totalIncome - totalExpense }
        var hasData: Bool { totalIncome > 0 || totalExpense > 0 }
    }

    struct Snapshot {
        var totalZakatableWealth: Decimal = 0
        var currentNisab: Decimal = 0
        var daysRemaining: Int = 0
        var estimatedZakat: Decimal = 0
        var isAboveNisab: Bool = false
        var lastUpdated: Date? = nil
        var hasData: Bool = false
        var breakdown: [CategorySlice] = []
        /// Length of the active hawl in days (354 when none is running).
        var hawlTotalDays: Int = 354
        var lifetimeZakatPaid: Decimal = 0
        var wealthHistory: [WealthPoint] = []
        var giving: [GivingBucket] = []
        var accountHistory: [AccountPoint] = []
        var budget: BudgetSummary = BudgetSummary()

        /// Whether a hawl is actually counting down right now.
        var hasActiveHawl: Bool { isAboveNisab && daysRemaining > 0 }
        /// Days elapsed in the active hawl.
        var hawlElapsedDays: Int { max(0, hawlTotalDays - daysRemaining) }
    }

    static func write(_ snapshot: Snapshot) {
        guard let defaults else { return }
        defaults.set(NSDecimalNumber(decimal: snapshot.totalZakatableWealth), forKey: Key.totalZakatableWealth)
        defaults.set(NSDecimalNumber(decimal: snapshot.currentNisab),         forKey: Key.currentNisab)
        defaults.set(snapshot.daysRemaining,                                  forKey: Key.daysRemaining)
        defaults.set(NSDecimalNumber(decimal: snapshot.estimatedZakat),       forKey: Key.estimatedZakat)
        defaults.set(snapshot.isAboveNisab,                                   forKey: Key.isAboveNisab)
        defaults.set(snapshot.lastUpdated ?? Date(),                          forKey: Key.lastUpdated)
        defaults.set(max(1, snapshot.hawlTotalDays),                          forKey: Key.hawlTotalDays)
        defaults.set(NSDecimalNumber(decimal: snapshot.lifetimeZakatPaid),    forKey: Key.lifetimeZakatPaid)
        defaults.set(true,                                                    forKey: Key.hasData)
        encode(snapshot.breakdown,      forKey: Key.breakdown,      into: defaults)
        encode(snapshot.wealthHistory,  forKey: Key.wealthHistory,  into: defaults)
        encode(snapshot.giving,         forKey: Key.giving,         into: defaults)
        encode(snapshot.accountHistory, forKey: Key.accountHistory, into: defaults)
        encode(snapshot.budget,         forKey: Key.budget,         into: defaults)
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
            hasData:              true,
            breakdown:            decode([CategorySlice].self, forKey: Key.breakdown,      from: defaults) ?? [],
            hawlTotalDays:        max(1, defaults.object(forKey: Key.hawlTotalDays) as? Int ?? 354),
            lifetimeZakatPaid:    (defaults.object(forKey: Key.lifetimeZakatPaid)   as? NSDecimalNumber)?.decimalValue ?? 0,
            wealthHistory:        decode([WealthPoint].self,   forKey: Key.wealthHistory,  from: defaults) ?? [],
            giving:               decode([GivingBucket].self,  forKey: Key.giving,         from: defaults) ?? [],
            accountHistory:       decode([AccountPoint].self,  forKey: Key.accountHistory, from: defaults) ?? [],
            budget:               decode(BudgetSummary.self,   forKey: Key.budget,         from: defaults) ?? BudgetSummary()
        )
    }

    // MARK: - JSON helpers

    private static func encode<T: Encodable>(_ value: T, forKey key: String, into defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
