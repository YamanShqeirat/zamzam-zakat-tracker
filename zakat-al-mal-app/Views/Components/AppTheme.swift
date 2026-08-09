import SwiftUI

/// Color palette — black surface with a faint gray Islamic geometric pattern,
/// metallic gold accent, red-orange for below-nisab warnings.
enum AppTheme {
    static let background     = Color(hex: 0x000000)
    static let card           = Color(hex: 0x16171A)
    static let cardElevated   = Color(hex: 0x232428)
    static let divider        = Color.white.opacity(0.08)

    static let accent         = Color(hex: 0xD4AF37)  // metallic gold
    static let accentSoft     = Color(hex: 0xD4AF37).opacity(0.15)
    static let accentMuted    = Color(hex: 0x8C6D1F)  // deep gold

    static let warning        = Color(hex: 0xE0533D)  // red-orange
    static let warningSoft    = Color(hex: 0xE0533D).opacity(0.18)

    static let textPrimary    = Color.white
    static let textSecondary  = Color.white.opacity(0.65)
    static let textTertiary   = Color.white.opacity(0.4)
    static let ringTrack      = Color.white.opacity(0.08)

    /// Faint gray used for the background geometric pattern strokes.
    static let pattern        = Color.white.opacity(0.1)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }
}
