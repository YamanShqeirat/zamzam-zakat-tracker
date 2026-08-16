import SwiftUI
import WidgetKit

/// Home-screen counterpart of the app's "The Hijri calendar" infographic: the
/// 12-month ring with today's position marked and a moon whose illumination
/// tracks progress through the lunar year.
struct HijriCalendarWidget: Widget {
    let kind = "HijriCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakatWidgetProvider()) { entry in
            HijriCalendarWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hijri Calendar")
        .description("Where you are in the lunar year, and how far the hawl has run.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HijriCalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ZakatWidgetEntry

    private var monthIndex: Int { WidgetHijri.monthIndex() }
    private var progress: Double { WidgetHijri.yearProgress() }

    var body: some View {
        switch family {
        case .systemMedium: medium
        default:            small
        }
    }

    // MARK: - Small: ring only, date underneath

    private var small: some View {
        VStack(spacing: 6) {
            LunarMonthRing(
                currentMonthIndex: monthIndex,
                dayOfYearRatio: progress,
                showsLabels: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(WidgetHijri.shortDate())
                .font(.caption.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(WidgetHijri.monthAbbreviations[monthIndex] + " · \(Int(progress * 100))% of year")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium: labelled ring + hawl status

    private var medium: some View {
        HStack(spacing: 14) {
            LunarMonthRing(
                currentMonthIndex: monthIndex,
                dayOfYearRatio: progress,
                showsLabels: true
            )
            .frame(width: 128, height: 128)

            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "THE HIJRI CALENDAR")

                Text(WidgetHijri.longDate())
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                Text("12 lunar months · 354 days per hawl")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                hawlLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var hawlLine: some View {
        let snapshot = entry.snapshot
        if snapshot.hasActiveHawl {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hawl day \(snapshot.hawlElapsedDays) of \(snapshot.hawlTotalDays)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                ProgressView(
                    value: Double(snapshot.hawlElapsedDays),
                    total: Double(max(1, snapshot.hawlTotalDays))
                )
                .progressViewStyle(.linear)
                .tint(WidgetTheme.accent)
            }
        } else {
            Text("A hawl begins when your wealth crosses nisab.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Lunar month ring

/// Widget copy of the app's `LunarMonthRing`. `showsLabels` drops the month
/// names on the small family, where they'd be illegible.
struct LunarMonthRing: View {
    /// 0-based index of the currently-active Hijri month (0…11).
    let currentMonthIndex: Int
    /// Fraction (0…1) of how far we are through the current Hijri year.
    let dayOfYearRatio: Double
    var showsLabels: Bool = true

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = size / 2 - 4
            let labelRadius = outerRadius - 12
            let markerRadius = outerRadius - 2

            ZStack {
                Circle()
                    .stroke(WidgetTheme.track, lineWidth: 1)
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(center)

                if showsLabels {
                    ForEach(0..<12, id: \.self) { i in
                        let isCurrent = i == currentMonthIndex
                        Text(WidgetHijri.monthAbbreviations[i])
                            .font(.system(size: 7, weight: isCurrent ? .bold : .regular))
                            .foregroundStyle(isCurrent ? WidgetTheme.accent : .secondary)
                            .position(point(at: center, radius: labelRadius, angle: angleForMonth(i)))
                    }
                } else {
                    // Tick marks stand in for the month labels.
                    ForEach(0..<12, id: \.self) { i in
                        Circle()
                            .fill(i == currentMonthIndex ? WidgetTheme.accent : Color.secondary.opacity(0.35))
                            .frame(width: i == currentMonthIndex ? 4 : 2.5,
                                   height: i == currentMonthIndex ? 4 : 2.5)
                            .position(point(at: center, radius: labelRadius, angle: angleForMonth(i)))
                    }
                }

                Circle()
                    .fill(WidgetTheme.accent)
                    .frame(width: 7, height: 7)
                    .position(point(at: center, radius: markerRadius, angle: yearAngle))
                    .shadow(color: WidgetTheme.accent.opacity(0.7), radius: 4)

                MoonGlyph(phase: dayOfYearRatio)
                    .frame(width: size * 0.46, height: size * 0.46)
                    .position(center)
            }
        }
    }

    private func angleForMonth(_ index: Int) -> Angle {
        Angle(degrees: -90 + Double(index) * 30)
    }
    private var yearAngle: Angle {
        Angle(degrees: -90 + dayOfYearRatio * 360)
    }
    private func point(at center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle.radians)),
            y: center.y + radius * CGFloat(sin(angle.radians))
        )
    }
}

/// Stylized moon disc whose illumination tracks the lunar-year phase — a
/// triangle wave so it reads new → full → new across the year.
private struct MoonGlyph: View {
    let phase: Double

    private var illumination: Double {
        let p = min(1, max(0, phase))
        return 1 - abs(0.5 - p) * 2
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.12))
            Circle()
                .stroke(WidgetTheme.accent.opacity(0.45), lineWidth: 1)

            GeometryReader { geo in
                let d = min(geo.size.width, geo.size.height)
                let offset = (1 - illumination) * d * 0.55
                Circle()
                    .fill(WidgetTheme.accent.opacity(0.85))
                    .frame(width: d, height: d)
                    .mask(
                        ZStack {
                            Circle()
                            Circle()
                                .offset(x: -offset)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
            }
            .padding(4)
        }
    }
}

#Preview(as: .systemSmall) {
    HijriCalendarWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemMedium) {
    HijriCalendarWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}
