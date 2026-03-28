//
//  FlasharooApp.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData
import BackgroundTasks

private let mediaSyncTaskID = "com.golackey.flasharoo.mediasync"

@main
struct FlasharooApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            Deck.self, Card.self, CardReview.self,
            MediaAsset.self, FilteredDeck.self,
            GestureSettings.self, UserSettings.self
        ])

        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.golackey.flasharoo")
        )

        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            return container
        }

        // Fallback: local-only (simulator without iCloud, test environment)
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private var mediaSyncService: MediaSyncService {
        MediaSyncService(container: container)
    }

    @Environment(\.scenePhase) private var scenePhase

    init() {
        registerBGTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleMediaSync()
            }
        }

        #if os(macOS)
        Settings {
            Text("Settings") // placeholder — replaced in Phase 12
        }
        #endif
    }

    // MARK: - Background Tasks

    private func registerBGTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: mediaSyncTaskID,
            using: nil
        ) { [self] task in
            handleMediaSync(task: task as! BGProcessingTask)
        }
    }

    private func scheduleMediaSync() {
        let request = BGProcessingTaskRequest(identifier: mediaSyncTaskID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleMediaSync(task: BGProcessingTask) {
        let sync = MediaSyncService(container: container)

        task.expirationHandler = {
            // System is reclaiming time; nothing to cancel cleanly — next BGTask picks up
        }

        Task {
            await sync.processUploadQueue()
            await sync.processDownloadQueue()
            task.setTaskCompleted(success: true)
            scheduleMediaSync() // reschedule for next opportunity
        }
    }
}
