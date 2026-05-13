import SwiftUI
import WidgetKit

struct ZakatWidget: Widget {
    let kind: String = "ZakatWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakatWidgetProvider()) { entry in
            ZakatWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Zakat Tracker")
        .description("See your nisab status and hawl progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ZakatWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZakatWidget()
    }
}
