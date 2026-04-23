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

    // MARK: - Container (Result so init failure shows a UI instead of crashing)

    private static let containerResult: Result<ModelContainer, Error> = {
        let schema = Schema([
            Deck.self, Card.self, CardReview.self,
            MediaAsset.self, FilteredDeck.self,
            GestureSettings.self, UserSettings.self
        ])

        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.golackey.flasharoo")
        )
        if let c = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            return .success(c)
        }

        // Fallback: local-only (simulator / no iCloud account)
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return .success(try ModelContainer(for: schema, configurations: [localConfig]))
        } catch {
            return .failure(error)
        }
    }()

    // MARK: - App state

    @State private var syncMonitor = SyncMonitor()
    @State private var aiSettings  = AISettings()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        registerBGTasks()
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            switch Self.containerResult {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .environment(syncMonitor)
                    .environment(aiSettings)
                    .tint(.paperAccent)
                    .task { await runLaunchTasks(container: container) }

            case .failure(let error):
                ContainerErrorView(errorMessage: error.localizedDescription)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleMediaSync()
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(aiSettings)
        }
        #endif
    }

    // MARK: - Launch tasks (orphan adoption + UserSettings bootstrap)

    private func runLaunchTasks(container: ModelContainer) async {
        let actor = BackgroundDataActor(container: container)
        await actor.adoptOrphanedCards()
    }

    // MARK: - Background Tasks

    private func registerBGTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: mediaSyncTaskID,
            using: nil
        ) { task in
            self.handleMediaSync(task: task as! BGProcessingTask)
        }
    }

    private func scheduleMediaSync() {
        let request = BGProcessingTaskRequest(identifier: mediaSyncTaskID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleMediaSync(task: BGProcessingTask) {
        guard case .success(let container) = Self.containerResult else {
            task.setTaskCompleted(success: false)
            return
        }

        let sync    = MediaSyncService(container: container)
        let cleanup = BackgroundDataActor(container: container)

        task.expirationHandler = {}

        Task {
            await sync.processUploadQueue()
            await sync.processDownloadQueue()
            await cleanup.purgeOldSoftDeletes()
            task.setTaskCompleted(success: true)
            scheduleMediaSync()
        }
    }
}
