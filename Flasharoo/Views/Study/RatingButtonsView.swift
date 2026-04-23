//
//  RatingButtonsView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Again / Hard / Good / Easy rating buttons shown after answer reveal.
//  Uses the Paper theme warm palette with solid fills.
//

import SwiftUI

struct RatingButtonsView: View {
    let hints: IntervalHint
    let onRate: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        HStack(spacing: 8) {
            ratingButton(label: "Again", hint: hints.again, rating: 1,
                         bg: .ratingAgainBg, fg: .white)
            ratingButton(label: "Hard",  hint: hints.hard,  rating: 2,
                         bg: .ratingHardBg, fg: .ratingHardInk)
            ratingButton(label: "Good",  hint: hints.good,  rating: 3,
                         bg: .ratingGoodBg, fg: .ratingGoodInk)
            ratingButton(label: "Easy",  hint: hints.easy,  rating: 4,
                         bg: .ratingEasyBg, fg: .ratingEasyInk)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 4)
    }

    private func ratingButton(label: String, hint: String, rating: Int, bg: Color, fg: Color) -> some View {
        Button {
            onRate(rating)
        } label: {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                Text(hint)
                    .font(.system(size: 11.5, weight: .medium))
                    .opacity(0.75)
                    .monospacedDigit()
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(bg)
                    .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
