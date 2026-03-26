//
//  FlasharooApp.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

@main
struct FlasharooApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            Deck.self, Card.self, CardReview.self,
            MediaAsset.self, FilteredDeck.self,
            GestureSettings.self, UserSettings.self
        ])

        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.golackey.flasharoo")
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)

        #if os(macOS)
        Settings {
            Text("Settings") // placeholder — replaced in Phase 12
        }
        #endif
    }
}
