//
//  RatingButtonsView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Again / Hard / Good / Easy rating buttons shown after answer reveal.
//  Adapts from a single row (iPad/Mac) to 2×2 grid (compact iPhone).
//

import SwiftUI

struct RatingButtonsView: View {
    let hints: IntervalHint
    let onRate: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .compact {
                // iPhone: 2×2 grid
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ratingButton(label: "Again", hint: hints.again, rating: 1, color: .red)
                        ratingButton(label: "Hard",  hint: hints.hard,  rating: 2, color: .orange)
                    }
                    HStack(spacing: 10) {
                        ratingButton(label: "Good",  hint: hints.good,  rating: 3, color: .green)
                        ratingButton(label: "Easy",  hint: hints.easy,  rating: 4, color: .blue)
                    }
                }
            } else {
                // iPad / Mac: single row
                HStack(spacing: 12) {
                    ratingButton(label: "Again", hint: hints.again, rating: 1, color: .red)
                    ratingButton(label: "Hard",  hint: hints.hard,  rating: 2, color: .orange)
                    ratingButton(label: "Good",  hint: hints.good,  rating: 3, color: .green)
                    ratingButton(label: "Easy",  hint: hints.easy,  rating: 4, color: .blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func ratingButton(label: String, hint: String, rating: Int, color: Color) -> some View {
        Button {
            onRate(rating)
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.headline)
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
    }
}
