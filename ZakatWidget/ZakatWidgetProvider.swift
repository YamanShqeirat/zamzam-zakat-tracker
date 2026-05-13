import Foundation
import WidgetKit

struct ZakatWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedAppGroup.Snapshot

    static let placeholder = ZakatWidgetEntry(
        date: Date(),
        snapshot: SharedAppGroup.Snapshot(
            totalZakatableWealth: 47832,
            currentNisab: 6205,
            daysRemaining: 107,
            estimatedZakat: 1195.80,
            isAboveNisab: true,
            lastUpdated: Date(),
            hasData: true
        )
    )

    static let empty = ZakatWidgetEntry(
        date: Date(),
        snapshot: SharedAppGroup.Snapshot()
    )
}

struct ZakatWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZakatWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ZakatWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZakatWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 6 hours per spec — the main app reloads the timeline
        // proactively on each sync, so this is just a safety net.
        let nextRefresh = Date().addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> ZakatWidgetEntry {
        ZakatWidgetEntry(date: Date(), snapshot: SharedAppGroup.read())
    }
}
