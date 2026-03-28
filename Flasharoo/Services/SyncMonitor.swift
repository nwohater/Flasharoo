//
//  SyncMonitor.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Subscribes to NSPersistentCloudKitContainer.eventChangedNotification and surfaces
//  sync state to the UI. Always runs on the MainActor so SwiftUI observation is safe.
//

import SwiftUI
import CoreData
import CloudKit

@MainActor
@Observable
final class SyncMonitor {

    enum SyncState: Equatable {
        case idle
        case syncing
        case error(String)

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    private(set) var state: SyncState = .idle
    private(set) var lastSyncDate: Date?

    init() {
        // SyncMonitor lives for the entire app lifetime, so we don't need to
        // store or remove the observer token. The [weak self] closure is a
        // no-op if the object is ever deallocated, preventing any retain cycle.
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            Task { @MainActor [weak self] in
                self?.process(event: event)
            }
        }
    }

    // MARK: - Event processing

    private func process(event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            // Event in progress
            state = .syncing
            return
        }

        if let error = event.error {
            state = .error(message(for: error))
        } else {
            state = .idle
            lastSyncDate = event.endDate
        }
    }

    // MARK: - CloudKit error messages

    private func message(for error: Error) -> String {
        guard let ckError = error as? CKError else {
            return error.localizedDescription
        }
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return "Network unavailable — changes will sync when reconnected."
        case .quotaExceeded:
            return "iCloud storage is full. Free up space in Settings to resume sync."
        case .notAuthenticated:
            return "Not signed in to iCloud. Open Settings › [Your Name] to sign in."
        case .zoneNotFound:
            return "iCloud sync zone not found. Data will re-sync automatically."
        case .changeTokenExpired:
            return "Sync token expired — a full re-sync has been triggered."
        default:
            return ckError.localizedDescription
        }
    }
}
