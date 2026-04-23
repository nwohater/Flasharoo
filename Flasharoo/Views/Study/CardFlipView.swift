//
//  CardFlipView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Renders card content via WKWebView (MathJax / LaTeX capable).
//  A single WebView instance is reused — HTML is swapped in place with
//  a brief cross-fade when the answer is revealed.
//

import SwiftUI

struct CardFlipView: View {
    let card: Card
    let isRevealed: Bool

    @State private var webHeight: CGFloat = 300
    @State private var displayedHTML: String = ""

    var body: some View {
        ScrollView {
            CardWebView(html: displayedHTML, contentHeight: $webHeight)
                .frame(height: max(webHeight, 120))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.paperSurface)
                .shadow(color: Color.paperInk.opacity(0.04), radius: 2, y: 1)
                .shadow(color: Color.paperInk.opacity(0.06), radius: 24, y: 8)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.25), value: displayedHTML)
        .onAppear { displayedHTML = RenderService.shared.render(card: card, revealed: false) }
        .onChange(of: isRevealed) { _, revealed in
            withAnimation(.easeInOut(duration: 0.25)) {
                displayedHTML = RenderService.shared.render(card: card, revealed: revealed)
            }
        }
        .onChange(of: card.id) { _, _ in
            displayedHTML = RenderService.shared.render(card: card, revealed: false)
            webHeight = 300
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .cardWebViewHeightChanged)
        ) { note in
            if let h = note.userInfo?["height"] as? CGFloat, h > 0 {
                webHeight = h
            }
        }
    }
}
