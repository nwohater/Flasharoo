//
//  CardFlipView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Displays the card front or back with a 3D flip animation.
//  Phase 6 replaces the Text renderer with WKWebView / MathJax.
//

import SwiftUI

struct CardFlipView: View {
    let card: Card
    let isRevealed: Bool

    @State private var flipped = false

    var body: some View {
        ZStack {
            cardFace(text: card.front, isFront: true)
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            cardFace(text: card.back, isFront: false)
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .onChange(of: isRevealed) { _, revealed in
            withAnimation(.easeInOut(duration: 0.35)) {
                flipped = revealed
            }
        }
        .onChange(of: card.id) { _, _ in
            flipped = false
        }
    }

    private func cardFace(text: String, isFront: Bool) -> some View {
        ScrollView {
            Text(stripHTML(text))
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Naive HTML tag stripper — replaced by WKWebView in Phase 6.
    private func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
