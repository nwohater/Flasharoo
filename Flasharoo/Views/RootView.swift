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
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DeckListView(selectedDeck: $selectedDeck)
        } detail: {
            if let deck = selectedDeck {
                Text("Deck: \(deck.name)")   // placeholder — replaced in Phase 4
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(
                    "No Deck Selected",
                    systemImage: "rectangle.stack",
                    description: Text("Choose a deck from the sidebar to start studying.")
                )
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
