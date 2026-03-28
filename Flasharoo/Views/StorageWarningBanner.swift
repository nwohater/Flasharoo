//
//  StorageWarningBanner.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Displays a dismissible banner when total local media storage exceeds 1 GB.
//  Embed above the main content in RootView.
//

import SwiftUI

private let storageWarningThreshold = 1_073_741_824 // 1 GB in bytes

struct StorageWarningBanner: View {
    @State private var totalBytes: Int = 0
    @State private var isDismissed = false

    private var isOverLimit: Bool { totalBytes >= storageWarningThreshold }

    var body: some View {
        if isOverLimit && !isDismissed {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Media Storage Warning")
                        .font(.subheadline).bold()
                    Text("\(formattedBytes(totalBytes)) of media stored locally. Consider removing unused attachments.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { isDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task {
                await refreshStorageSize()
            }
        }
    }

    private func refreshStorageSize() async {
        let bytes = await MediaService.shared.totalStorageBytes()
        await MainActor.run { totalBytes = bytes }
    }

    private func formattedBytes(_ bytes: Int) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
}
