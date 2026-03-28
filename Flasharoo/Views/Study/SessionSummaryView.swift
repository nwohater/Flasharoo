//
//  SessionSummaryView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI

struct SessionSummaryView: View {
    let stats: StudyViewModel.SessionStats
    let sourceName: String
    let onStudyAgain: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Session Complete")
                .font(.largeTitle.bold())

            statsGrid

            Button("Study Again") { onStudyAgain() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Button("Done") { onDismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)

            Spacer()
        }
        .padding()
        .navigationTitle(sourceName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsGrid: some View {
        Grid(horizontalSpacing: 24, verticalSpacing: 16) {
            GridRow {
                statCell(
                    value: "\(stats.totalReviewed)",
                    label: "Cards Reviewed",
                    icon: "rectangle.stack"
                )
                statCell(
                    value: retentionString,
                    label: "Retention",
                    icon: "brain.head.profile"
                )
            }
            GridRow {
                statCell(
                    value: elapsedString,
                    label: "Time Studied",
                    icon: "clock"
                )
                statCell(
                    value: "\(stats.goodOrEasyCount)",
                    label: "Good or Easy",
                    icon: "hand.thumbsup"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var retentionString: String {
        let pct = Int(stats.retention * 100)
        return "\(pct)%"
    }

    private var elapsedString: String {
        let total = Int(stats.elapsed)
        let m = total / 60
        let s = total % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
