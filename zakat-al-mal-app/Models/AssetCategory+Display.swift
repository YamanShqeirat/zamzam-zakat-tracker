import Foundation
import SwiftUI

extension AssetCategory {
    var swatch: Color {
        switch self {
        case .brokerage:   return Color(hex: 0x8B5CF6) // purple
        case .bankAccount: return Color(hex: 0x2DD4A8) // teal
        case .gold:        return Color(hex: 0xF59E0B) // amber
        case .silver:      return Color(hex: 0xCBD5E1) // silver
        case .cash:        return Color(hex: 0x64748B) // slate
        case .crypto:      return Color(hex: 0xFB923C) // orange
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
        case .brokerage:   return "Brokerage"
        case .crypto:      return "Crypto"
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
        case .gold:        return "circle.hexagongrid.fill"
        case .silver:      return "circle.hexagongrid"
        case .retirement:  return "tray.full"
        case .receivable:  return "arrow.down.left.circle"
        case .other:       return "questionmark.circle"
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
