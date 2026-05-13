//
//  zakat_al_mal_appApp.swift
//  zakat-al-mal-app
//
//  Created by Yaman Shqeirat on 5/12/26.
//

import SwiftUI
import SwiftData

@main
struct zakat_al_mal_appApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
