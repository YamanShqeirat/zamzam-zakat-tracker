import Foundation

/// Shared currency/number formatting helpers used across the finance views.
/// (Previously duplicated file-locally inside `AnalyticsView`.)
extension Decimal {
    var asDouble: Double { (self as NSDecimalNumber).doubleValue }

    var currencyString: String { formatted(.currency(code: "USD")) }

    var signedCurrencyString: String {
        let prefix = self >= 0 ? "+" : ""
        return prefix + formatted(.currency(code: "USD"))
    }
}

/// Abbreviated currency for axis labels: `$1.2k`, `-$3.4M`, `$820`.
func compactCurrency(_ value: Double) -> String {
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
