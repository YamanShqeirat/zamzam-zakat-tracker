import SwiftUI
import WidgetKit

struct ZakatWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ZakatWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumView(snapshot: entry.snapshot)
        default:
            SmallView(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Small

private struct SmallView: View {
    let snapshot: SharedAppGroup.Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Zakat Tracker")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            if !snapshot.hasData {
                Spacer()
                Text("Open the app to sync")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(snapshot.isAboveNisab ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(snapshot.isAboveNisab ? "Above Nisab" : "Below Nisab")
                        .font(.caption.bold())
                }

                if snapshot.isAboveNisab {
                    Text("\(snapshot.daysRemaining) days left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 2)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Est:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(snapshot.estimatedZakat.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                        .font(.title3.bold())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium

private struct MediumView: View {
    let snapshot: SharedAppGroup.Snapshot

    private var progress: Double {
        guard snapshot.daysRemaining > 0 else { return 0 }
        let total = 354.0 // Hijri year approximation
        return max(0, min(1, (total - Double(snapshot.daysRemaining)) / total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zakat Tracker")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if !snapshot.hasData {
                Spacer()
                Text("Open the app to sync your accounts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    LabeledValue(label: "Wealth", value: snapshot.totalZakatableWealth)
                    LabeledValue(label: "Nisab",  value: snapshot.currentNisab)
                    Spacer()
                }

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(snapshot.isAboveNisab ? .green : .gray)

                HStack {
                    Text("\(snapshot.daysRemaining) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Estimated Zakat: \(snapshot.estimatedZakat.formatted(.currency(code: "USD")))")
                        .font(.caption.bold())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct LabeledValue: View {
    let label: String
    let value: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                .font(.callout.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

#Preview(as: .systemSmall) {
    ZakatWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}

#Preview(as: .systemMedium) {
    ZakatWidget()
} timeline: {
    ZakatWidgetEntry.placeholder
    ZakatWidgetEntry.empty
}
