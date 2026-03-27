//
//  CardEditorView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

struct CardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let deck: Deck
    let card: Card?     // nil = new card

    @State private var front = ""
    @State private var back  = ""
    @State private var tags: [String] = []
    @State private var assets: [MediaAsset] = []

    /// Stable ID used as the cardID for media even before the card is saved.
    @State private var pendingCardID = UUID()

    private var isNew: Bool { card == nil }

    private var allDeckTags: [String] {
        Array(Set(deck.cards.flatMap { $0.tagList })).sorted()
    }

    init(deck: Deck, card: Card? = nil) {
        self.deck = deck
        self.card = card
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Front") {
                    TextEditor(text: $front)
                        .frame(minHeight: 100)
                }

                Section("Back") {
                    TextEditor(text: $back)
                        .frame(minHeight: 100)
                }

                Section("Tags") {
                    TagInputView(tags: $tags, suggestions: allDeckTags)
                }

                Section("Media") {
                    MediaAttachmentView(cardID: pendingCardID, assets: $assets)
                }
            }
            .navigationTitle(isNew ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadCard)
        }
    }

    // MARK: - Load

    private func loadCard() {
        guard let card else { return }
        pendingCardID = card.id
        front  = card.front
        back   = card.back
        tags   = card.tagList
        assets = card.mediaAssets.filter { $0.deletedAt == nil }
    }

    // MARK: - Save

    private func save() {
        let trimFront = front.trimmingCharacters(in: .whitespaces)
        guard !trimFront.isEmpty else { return }
        let trimBack = back.trimmingCharacters(in: .whitespaces)

        if let card {
            card.front      = trimFront
            card.back       = trimBack
            card.tagList    = tags
            card.modifiedAt = Date()
        } else {
            let newCard = Card(
                id: pendingCardID,
                deckID: deck.id,
                front: trimFront,
                back: trimBack,
                tags: tags.joined(separator: " ")
            )
            modelContext.insert(newCard)
            // Link any media assets that were created during editing
            for asset in assets {
                asset.card = newCard
            }
            deck.cards.append(newCard)
        }

        try? modelContext.save()
        dismiss()
    }
}
