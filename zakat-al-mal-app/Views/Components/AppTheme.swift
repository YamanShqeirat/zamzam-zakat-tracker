import SwiftUI

/// Color palette drawn from the pitch wireframes — dark navy app surface,
/// slightly lighter card fills, teal accent, amber for below-nisab warnings.
enum AppTheme {
    static let background     = Color(hex: 0x1A1F2E)
    static let card           = Color(hex: 0x232A3B)
    static let cardElevated   = Color(hex: 0x2A3247)
    static let divider        = Color.white.opacity(0.06)

    static let accent         = Color(hex: 0x2DD4A8)
    static let accentSoft     = Color(hex: 0x2DD4A8).opacity(0.15)
    static let accentMuted    = Color(hex: 0x1F6B56)

    static let warning        = Color(hex: 0xF59E0B)
    static let warningSoft    = Color(hex: 0xF59E0B).opacity(0.18)

    static let textPrimary    = Color.white
    static let textSecondary  = Color.white.opacity(0.65)
    static let textTertiary   = Color.white.opacity(0.4)
    static let ringTrack      = Color.white.opacity(0.08)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }
}
