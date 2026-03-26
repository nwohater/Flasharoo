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

        // TODO: Phase 1 — once bundle ID and iCloud capability are configured in Xcode,
        // replace the configuration below with the CloudKit-backed version:
        //
        // let config = ModelConfiguration(
        //     schema: schema,
        //     cloudKitDatabase: .private("iCloud.com.yourdomain.flasharoo")
        // )
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
