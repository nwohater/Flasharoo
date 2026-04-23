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
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { onDismiss() }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.paperAccent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    retentionCard
                    timeCard
                    actionButtons
                }
            }
        }
        .background(Color.adaptiveGroupedBg)
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.stateReview.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.stateReview)
            }
            VStack(spacing: 4) {
                Text("Nicely done.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.paperInk)
                Text("\(sourceName) · \(elapsedString)")
                    .font(.subheadline)
                    .foregroundStyle(Color.paperInkMuted)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
    }

    // MARK: - Retention card

    private var retentionCard: some View {
        let goodCount = stats.goodOrEasyCount
        let totalReviewed = max(stats.totalReviewed, 1)
        let hardEstimate = max(0, totalReviewed - goodCount) / 2
        let againCount = max(0, totalReviewed - goodCount - hardEstimate)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(retentionString)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.paperInk)
                    .monospacedDigit()
                Text("retention · \(stats.totalReviewed) cards reviewed")
                    .font(.subheadline)
                    .foregroundStyle(Color.paperInkMuted)
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    if againCount > 0 {
                        Color.ratingAgainBg
                            .frame(width: geo.size.width * CGFloat(againCount) / CGFloat(totalReviewed))
                    }
                    if hardEstimate > 0 {
                        Color.ratingHardBg
                            .frame(width: geo.size.width * CGFloat(hardEstimate) / CGFloat(totalReviewed))
                    }
                    if goodCount > 0 {
                        Color.ratingGoodBg
                            .frame(width: geo.size.width * CGFloat(goodCount) / CGFloat(totalReviewed))
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
            }
            .frame(height: 8)

            HStack {
                legendPill(color: Color.ratingAgainBg, label: "Again", count: againCount)
                Spacer()
                legendPill(color: Color.ratingHardBg, label: "Hard", count: hardEstimate)
                Spacer()
                legendPill(color: Color.ratingGoodBg, label: "Good/Easy", count: goodCount)
            }
            .font(.system(size: 12))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveSecondaryBg)
        )
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    // MARK: - Time card

    private var timeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .foregroundStyle(Color.paperAccent)
                .font(.system(size: 17))
            VStack(alignment: .leading, spacing: 2) {
                Text("Time studied")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.3)
                    .foregroundStyle(Color.paperInkMuted)
                Text(elapsedString)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.paperInk)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveSecondaryBg)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                onStudyAgain()
            } label: {
                Text("Study again")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.paperAccent)
                    )
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Text("Back to deck")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.paperAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Legend pill

    private func legendPill(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .foregroundStyle(Color.paperInkMid)
                .fontWeight(.medium)
            Text("\(count)")
                .foregroundStyle(Color.paperInkMuted)
                .monospacedDigit()
        }
    }

    // MARK: - Computed strings

    private var retentionString: String {
        "\(Int(stats.retention * 100))%"
    }

    private var elapsedString: String {
        let total = Int(stats.elapsed)
        let m = total / 60
        let s = total % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
