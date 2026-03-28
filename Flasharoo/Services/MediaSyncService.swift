//
//  MediaSyncService.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Orchestrates CloudKit upload/download of media assets.
//  Runs as a ModelActor so it can read/write SwiftData models safely off the main thread.
//  Called by the BGProcessingTask handler in FlasharooApp.
//
//  Retry schedule: 1 min → 5 min → 30 min (3 attempts max per session).
//  Retry state is in-memory; a fresh BGTask launch resets attempts and retries from scratch.
//

import Foundation
import SwiftData

actor MediaSyncService: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor

    // Retry state (in-memory; resets on app relaunch — BGTask will retry again)
    private let retryDelays: [TimeInterval] = [60, 300, 1800]
    private var retryAttempts: [UUID: Int] = [:]
    private var nextRetryAt: [UUID: Date] = [:]

    init(container: ModelContainer) {
        self.modelContainer = container
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    // MARK: - Upload Queue

    /// Uploads all pending-local assets to CloudKit, with exponential backoff on failure.
    func processUploadQueue() async {
        // Reset any assets stuck in .uploading from a prior crashed session
        resetStuckUploads()

        let pending = pendingUploads()
        guard !pending.isEmpty else { return }

        for asset in pending {
            guard shouldRetry(assetID: asset.id) else { continue }

            let assetID       = asset.id
            let cardID        = asset.cardID
            let mimeType      = asset.mimeType
            let localFilename = asset.localFilename

            asset.syncState = .uploading
            saveContext()

            do {
                let recordName = try await MediaService.shared.uploadToCloudKit(
                    assetID: assetID,
                    cardID: cardID,
                    mimeType: mimeType,
                    localFilename: localFilename
                )
                asset.syncState          = .synced
                asset.ckAssetRecordName  = recordName
                retryAttempts.removeValue(forKey: assetID)
                nextRetryAt.removeValue(forKey: assetID)
                saveContext()
            } catch {
                asset.syncState = .local
                recordFailure(assetID: assetID)
                saveContext()
            }
        }
    }

    // MARK: - Download Queue

    /// Downloads all assets marked `.downloadNeeded` from CloudKit.
    func processDownloadQueue() async {
        let pending = pendingDownloads()
        guard !pending.isEmpty else { return }

        for asset in pending {
            guard shouldRetry(assetID: asset.id) else { continue }
            guard let recordName = asset.ckAssetRecordName else { continue }

            let assetID       = asset.id
            let localFilename = asset.localFilename

            do {
                try await MediaService.shared.downloadFromCloudKit(
                    recordName: recordName,
                    to: localFilename
                )
                asset.syncState = .synced
                retryAttempts.removeValue(forKey: assetID)
                nextRetryAt.removeValue(forKey: assetID)
                saveContext()
            } catch {
                recordFailure(assetID: assetID)
            }
        }
    }

    // MARK: - Queries

    func pendingUploads() -> [MediaAsset] {
        let descriptor = FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.syncState == .local }
    }

    func pendingDownloads() -> [MediaAsset] {
        let descriptor = FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.syncState == .downloadNeeded }
    }

    func pendingUploadCount() -> Int {
        pendingUploads().count
    }

    func pendingDownloadCount() -> Int {
        pendingDownloads().count
    }

    /// Total bytes stored locally across all non-deleted assets (from SwiftData metadata).
    func totalStorageBytes() -> Int {
        let descriptor = FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.reduce(0) { $0 + $1.fileSizeBytes }
    }

    // MARK: - Retry helpers

    private func shouldRetry(assetID: UUID) -> Bool {
        if let date = nextRetryAt[assetID], Date() < date {
            return false
        }
        return true
    }

    private func recordFailure(assetID: UUID) {
        let attempt = (retryAttempts[assetID] ?? 0) + 1
        retryAttempts[assetID] = attempt
        let delayIndex = min(attempt - 1, retryDelays.count - 1)
        nextRetryAt[assetID] = Date().addingTimeInterval(retryDelays[delayIndex])
    }

    // MARK: - Private

    private func resetStuckUploads() {
        let descriptor = FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let stuck = all.filter { $0.syncState == .uploading }
        for asset in stuck {
            asset.syncState = .local
        }
        if !stuck.isEmpty { saveContext() }
    }

    private func saveContext() {
        try? modelContext.save()
    }
}
