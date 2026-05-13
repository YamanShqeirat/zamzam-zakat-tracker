import SwiftUI

/// Circular hawl-progress ring. Two states:
///  - `.active`: teal ring filled to `elapsedDays / totalDays`, large day count in the middle.
///  - `.paused`: gray ring (no fill), "Countdown / Paused / Below nisab" text in the middle.
struct HawlRing: View {
    enum State {
        case active(elapsedDays: Int, totalDays: Int, daysRemaining: Int)
        case paused
    }

    let state: State
    var size: CGFloat = 200
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.ringTrack, lineWidth: lineWidth)

            if case .active(let elapsed, let total, _) = state {
                let progress = total > 0
                    ? min(1, max(0, Double(elapsed) / Double(total)))
                    : 0
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppTheme.accent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: progress)
            }

            center
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var center: some View {
        switch state {
        case .active(let elapsed, let total, let remaining):
            VStack(spacing: 2) {
                Text("\(elapsed) of \(total) days")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("\(remaining)")
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .contentTransition(.numericText())
                Text("days remaining")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        case .paused:
            VStack(spacing: 2) {
                Text("Countdown")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                Text("Paused")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Below nisab")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        HawlRing(state: .active(elapsedDays: 217, totalDays: 354, daysRemaining: 137))
        HawlRing(state: .paused)
    }
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
