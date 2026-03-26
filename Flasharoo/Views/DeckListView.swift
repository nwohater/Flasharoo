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
    @Query(
        filter: #Predicate<Deck> { $0.deletedAt == nil },
        sort: [SortDescriptor(\Deck.sortIndex), SortDescriptor(\Deck.name)]
    ) private var decks: [Deck]

    @Binding var selectedDeck: Deck?
    @State private var showingNewDeck = false
    @State private var newDeckName = ""

    var body: some View {
        List(selection: $selectedDeck) {
            Section("Decks") {
                ForEach(decks) { deck in
                    NavigationLink(value: deck) {
                        DeckRowView(deck: deck)
                    }
                }
            }
        }
        .navigationTitle("Flasharoo")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewDeck = true
                } label: {
                    Label("New Deck", systemImage: "plus")
                }
            }
        }
        .alert("New Deck", isPresented: $showingNewDeck) {
            TextField("Deck name", text: $newDeckName)
            Button("Create") { createDeck() }
            Button("Cancel", role: .cancel) { newDeckName = "" }
        }
    }

    private func createDeck() {
        guard !newDeckName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let deck = Deck(name: newDeckName.trimmingCharacters(in: .whitespaces), sortIndex: decks.count)
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
