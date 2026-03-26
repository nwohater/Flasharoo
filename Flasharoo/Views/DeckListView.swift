//
//  DeckListView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Deck.sortIndex), SortDescriptor(\Deck.name)])
    var decks: [Deck]

    @Binding var selectedDeck: Deck?
    @State private var showingNewDeck = false
    @State private var newDeckName = ""

    private var activeDecks: [Deck] {
        decks.filter { $0.deletedAt == nil }
    }

    var body: some View {
        deckList
            .navigationTitle("Flasharoo")
            .toolbar { addButton }
            .alert("New Deck", isPresented: $showingNewDeck, actions: newDeckAlertActions)
    }

    private var deckList: some View {
        List(selection: $selectedDeck) {
            Section("Decks") {
                ForEach(activeDecks) { deck in
                    NavigationLink(value: deck) {
                        DeckRowView(deck: deck)
                    }
                }
            }
        }
    }

    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingNewDeck = true
            } label: {
                Label("New Deck", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private func newDeckAlertActions() -> some View {
        TextField("Deck name", text: $newDeckName)
        Button("Create") { createDeck() }
        Button("Cancel", role: .cancel) { newDeckName = "" }
    }

    private func createDeck() {
        guard !newDeckName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let deck = Deck(name: newDeckName.trimmingCharacters(in: .whitespaces), sortIndex: activeDecks.count)
        modelContext.insert(deck)
        selectedDeck = deck
        newDeckName = ""
    }
}

// MARK: - Deck Row

private struct DeckRowView: View {
    let deck: Deck

    private var activeCardCount: Int {
        deck.cards.filter { $0.deletedAt == nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(deck.name)
                .font(.headline)
            Text("\(activeCardCount) cards")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
