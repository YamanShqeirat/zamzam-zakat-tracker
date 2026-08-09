import SwiftUI

/// A faint gray Islamic geometric pattern — a tessellation of eight-point stars
/// (khatim / Rub el Hizb) formed by two overlapping squares per cell, with a
/// connecting lattice. Drawn once with `Canvas`, non-interactive, low opacity so
/// content stays legible on the black surface.
struct IslamicPattern: View {
    var cell: CGFloat = 66
    var color: Color = AppTheme.pattern

    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / cell) + 2
            let rows = Int(size.height / cell) + 2
            let radius = cell * 0.5

            for row in -1..<rows {
                for col in -1..<cols {
                    let center = CGPoint(x: CGFloat(col) * cell, y: CGFloat(row) * cell)
                    context.stroke(eightPointStar(center: center, radius: radius),
                                   with: .color(color), lineWidth: 0.8)
                    // Small central diamond to enrich the motif.
                    context.stroke(square(center: center, radius: radius * 0.34, rotation: .pi / 4),
                                   with: .color(color), lineWidth: 0.8)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Two overlapping squares (one rotated 45°) whose outline reads as an
    /// eight-point star.
    private func eightPointStar(center: CGPoint, radius: CGFloat) -> Path {
        var path = square(center: center, radius: radius, rotation: 0)
        path.addPath(square(center: center, radius: radius, rotation: .pi / 4))
        return path
    }

    private func square(center: CGPoint, radius: CGFloat, rotation: CGFloat) -> Path {
        var path = Path()
        for i in 0..<4 {
            let angle = rotation + CGFloat(i) * (.pi / 2) + .pi / 4
            let point = CGPoint(x: center.x + radius * cos(angle),
                                y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The app's shared screen backdrop: black + the faint geometric pattern.
/// Use via `.background(AppBackground().ignoresSafeArea())` on each screen so
/// cards float over the motif.
struct AppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background
            IslamicPattern()
        }
    }
}

#Preview {
    AppBackground()
        .ignoresSafeArea()
}
