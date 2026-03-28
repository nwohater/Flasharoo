//
//  RootView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDeck: Deck?
    @State private var selectedFilteredDeck: FilteredDeck?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        VStack(spacing: 0) {
            StorageWarningBanner()
            NavigationSplitView(columnVisibility: $columnVisibility) {
                DeckListView(
                    selectedDeck: $selectedDeck,
                    selectedFilteredDeck: $selectedFilteredDeck
                )
                .onChange(of: selectedFilteredDeck) { _, _ in
                    // Deselect regular deck when a filtered deck is selected
                    if selectedFilteredDeck != nil { selectedDeck = nil }
                }
                .onChange(of: selectedDeck) { _, _ in
                    if selectedDeck != nil { selectedFilteredDeck = nil }
                }
            } detail: {
                if let deck = selectedDeck {
                    DeckDetailView(deck: deck)
                } else if let fd = selectedFilteredDeck {
                    FilteredDeckDetailView(filteredDeck: fd)
                } else {
                    ContentUnavailableView(
                        "No Deck Selected",
                        systemImage: "rectangle.stack",
                        description: Text("Choose a deck from the sidebar to start studying.")
                    )
                }
            }
        }
        .onAppear {
            UserSettings.fetchOrCreate(in: modelContext)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [
            Deck.self, Card.self, CardReview.self,
            MediaAsset.self, FilteredDeck.self,
            GestureSettings.self, UserSettings.self
        ], inMemory: true)
}
