import Foundation
import SwiftUI

extension AssetCategory {
    var swatch: Color {
        switch self {
        case .brokerage:   return Color(hex: 0x8B5CF6) // purple
        case .bankAccount: return Color(hex: 0x4A90D9) // slate blue (off teal so gold reads as brand)
        case .gold:        return Color(hex: 0xD4AF37) // gold
        case .silver:      return Color(hex: 0xCBD5E1) // silver
        case .cash:        return Color(hex: 0x64748B) // slate
        case .crypto:      return Color(hex: 0xFB923C) // orange
        case .espp:        return Color(hex: 0x22C55E) // green
        case .retirement:  return Color(hex: 0x3B82F6) // blue
        case .receivable:  return Color(hex: 0xEC4899) // pink
        case .other:       return Color(hex: 0x9CA3AF) // gray
        }
    }
}

extension AssetCategory {
    var displayName: String {
        switch self {
        case .cash:        return "Cash"
        case .bankAccount: return "Bank Account"
        case .brokerage:   return "Stocks"
        case .crypto:      return "Crypto"
        case .espp:        return "ESPP"
        case .gold:        return "Gold"
        case .silver:      return "Silver"
        case .retirement:  return "Retirement"
        case .receivable:  return "Receivable"
        case .other:       return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .cash:        return "banknote"
        case .bankAccount: return "building.columns"
        case .brokerage:   return "chart.line.uptrend.xyaxis"
        case .crypto:      return "bitcoinsign.circle"
        case .espp:        return "briefcase"
        case .gold:        return "circle.hexagongrid.fill"
        case .silver:      return "circle.hexagongrid"
        case .retirement:  return "tray.full"
        case .receivable:  return "arrow.down.left.circle"
        case .other:       return "questionmark.circle"
        }
    }

    /// The higher-level section this category rolls up into.
    var group: AssetGroup {
        switch self {
        case .cash, .bankAccount:
            return .bank
        case .brokerage, .crypto, .espp, .retirement:
            return .investments
        case .gold, .silver:
            return .physical
        case .receivable, .other:
            return .other
        }
    }
}

extension AssetGroup {
    /// Representative colour for the group-level Overview breakdown.
    var color: Color {
        switch self {
        case .bank:        return Color(hex: 0x4A90D9) // slate blue
        case .investments: return Color(hex: 0xD4AF37) // gold
        case .physical:    return Color(hex: 0xCBD5E1) // silver
        case .other:       return Color(hex: 0x9CA3AF) // gray
        }
    }

    var sfSymbol: String {
        switch self {
        case .bank:        return "building.columns"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .physical:    return "circle.hexagongrid.fill"
        case .other:       return "square.grid.2x2"
        }
    }
}

extension AssetSource {
    var displayName: String {
        switch self {
        case .simplefin: return "SimpleFIN"
        case .manual:    return "Manual"
        }
    }
}
