import SwiftUI

// Small shared pieces for the widget target. The widget can't see the main
// app's types (AppTheme, AssetCategory, Decimal+Finance), so the handful of
// values it needs are mirrored here — keep them in sync with the app.

enum WidgetTheme {
    /// Metallic gold — `AppTheme.accent`.
    static let accent  = Color(red: 0xD4 / 255, green: 0xAF / 255, blue: 0x37 / 255)
    /// Red-orange — `AppTheme.warning`.
    static let warning = Color(red: 0xE0 / 255, green: 0x53 / 255, blue: 0x3D / 255)
    /// Nisab threshold line.
    static let nisab   = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    static let track   = Color.secondary.opacity(0.18)

    /// Series colours for per-account lines, cycled by index.
    static let series: [Color] = [
        Color(red: 0xD4 / 255, green: 0xAF / 255, blue: 0x37 / 255),
        Color(red: 0x4A / 255, green: 0x90 / 255, blue: 0xD9 / 255),
        Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255),
        Color(red: 0x22 / 255, green: 0xC5 / 255, blue: 0x5E / 255),
        Color(red: 0xFB / 255, green: 0x92 / 255, blue: 0x3C / 255),
        Color(red: 0xEC / 255, green: 0x48 / 255, blue: 0x99 / 255),
    ]

    static func color(hex: UInt32) -> Color {
        Color(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255
        )
    }
}

/// Mirror of the main app's `AssetCategory+Display` colours/labels so the
/// widget target doesn't depend on the SwiftData model.
enum WidgetCategory {
    static func color(for key: String) -> Color {
        switch key {
        case "brokerage":   return Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255)
        case "bankAccount": return Color(red: 0x4A / 255, green: 0x90 / 255, blue: 0xD9 / 255)
        case "gold":        return Color(red: 0xD4 / 255, green: 0xAF / 255, blue: 0x37 / 255)
        case "silver":      return Color(red: 0xCB / 255, green: 0xD5 / 255, blue: 0xE1 / 255)
        case "cash":        return Color(red: 0x64 / 255, green: 0x74 / 255, blue: 0x8B / 255)
        case "crypto":      return Color(red: 0xFB / 255, green: 0x92 / 255, blue: 0x3C / 255)
        case "espp":        return Color(red: 0x22 / 255, green: 0xC5 / 255, blue: 0x5E / 255)
        case "retirement":  return Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255)
        case "receivable":  return Color(red: 0xEC / 255, green: 0x48 / 255, blue: 0x99 / 255)
        default:            return Color(red: 0x9C / 255, green: 0xA3 / 255, blue: 0xAF / 255)
        }
    }

    static func displayName(for key: String) -> String {
        switch key {
        case "cash":        return "Cash"
        case "bankAccount": return "Bank Account"
        case "brokerage":   return "Stocks"
        case "crypto":      return "Crypto"
        case "espp":        return "ESPP"
        case "gold":        return "Gold"
        case "silver":      return "Silver"
        case "retirement":  return "Retirement"
        case "receivable":  return "Receivable"
        default:            return "Other"
        }
    }
}

// MARK: - Formatting

extension Decimal {
    var widgetDouble: Double { (self as NSDecimalNumber).doubleValue }

    /// `$1,234` — whole dollars, which is all a widget has room for.
    var widgetCurrency: String {
        formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    var widgetSignedCurrency: String {
        (self >= 0 ? "+" : "") + widgetCurrency
    }
}

/// Abbreviated currency for axis labels: `$1.2k`, `-$3.4M`, `$820`.
/// Mirrors the app's `compactCurrency`.
func widgetCompactCurrency(_ value: Double) -> String {
    let magnitude = abs(value)
    let sign = value < 0 ? "-" : ""
    if magnitude >= 1_000_000 {
        return "\(sign)$\((magnitude / 1_000_000).formatted(.number.precision(.fractionLength(0...1))))M"
    }
    if magnitude >= 1_000 {
        return "\(sign)$\((magnitude / 1_000).formatted(.number.precision(.fractionLength(0...1))))k"
    }
    return value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
}

// MARK: - Hijri helpers (mirrors AnalyticsSections)

enum WidgetHijri {
    static let calendar = Calendar(identifier: .islamicUmmAlQura)

    static let monthAbbreviations: [String] = [
        "Muh", "Saf", "Rab I", "Rab II",
        "Jum I", "Jum II", "Raj", "Sha",
        "Ram", "Shw", "Qid", "Hij",
    ]

    /// 0-based index of the current Hijri month.
    static func monthIndex(for date: Date = Date()) -> Int {
        max(1, min(12, calendar.component(.month, from: date))) - 1
    }

    /// How far through the current Hijri year we are, 0...1.
    static func yearProgress(for date: Date = Date()) -> Double {
        let year = calendar.component(.year, from: date)
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return 0
        }
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / span))
    }

    static func longDate(for date: Date = Date()) -> String {
        format(date, as: "d MMMM yyyy 'AH'")
    }

    static func shortDate(for date: Date = Date()) -> String {
        format(date, as: "d MMM yyyy")
    }

    private static func format(_ date: Date, as pattern: String) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en")
        f.dateFormat = pattern
        return f.string(from: date)
    }
}

// MARK: - Shared chrome

/// The small tracked caption every chart widget opens with.
struct WidgetHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.caption2.bold())
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let trailing {
                Spacer(minLength: 4)
                Text(trailing)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// Placeholder shown when the snapshot has nothing to chart yet.
struct WidgetEmptyState: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
    }
}
