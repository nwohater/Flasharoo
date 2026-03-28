//
//  SyncStatusButton.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Toolbar button that reflects CloudKit sync state.
//  Tap to open a popover with last-sync time and any error detail.
//

import SwiftUI

struct SyncStatusButton: View {
    @Environment(SyncMonitor.self) private var sync
    @State private var showingPopover = false

    var body: some View {
        Button { showingPopover = true } label: {
            stateIcon
        }
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            SyncStatusPopover(sync: sync)
                .presentationCompactAdaptation(.popover)
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch sync.state {
        case .idle:
            Image(systemName: "icloud")
                .foregroundStyle(.secondary)
        case .syncing:
            ProgressView()
                .controlSize(.small)
        case .error:
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Popover content

private struct SyncStatusPopover: View {
    let sync: SyncMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("iCloud Sync", systemImage: "icloud")
                .font(.headline)

            switch sync.state {
            case .idle:
                Label("Up to date", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .syncing:
                Label("Syncing…", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
            case .error(let msg):
                Label("Sync Error", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let date = sync.lastSyncDate {
                Divider()
                Text("Last synced: \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 240)
    }
}
