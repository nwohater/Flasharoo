//
//  DeckViewModel.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData
import Observation

/// Handles all Deck CRUD operations.
/// Injected into views via @Environment or initialiser; never imported into Services.
@Observable
final class DeckViewModel {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    @discardableResult
    func createDeck(name: String, description: String = "", sortIndex: Int = 0) -> Deck {
        let deck = Deck(name: name, descriptionText: description, sortIndex: sortIndex)
        context.insert(deck)
        return deck
    }

    // MARK: - Update

    func rename(_ deck: Deck, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        deck.name = trimmed
        deck.modifiedAt = Date()
    }

    func updateDescription(_ deck: Deck, description: String) {
        deck.descriptionText = description
        deck.modifiedAt = Date()
    }

    func updateSettings(
        _ deck: Deck,
        algorithmOverride: SchedulerAlgorithm?,
        newCardsPerDay: Int,
        maxReviewsPerDay: Int,
        newCardOrder: NewCardOrder
    ) {
        deck.algorithmOverride = algorithmOverride
        deck.newCardsPerDay = max(0, newCardsPerDay)
        deck.maxReviewsPerDay = max(0, maxReviewsPerDay)
        deck.newCardOrder = newCardOrder
        deck.modifiedAt = Date()
    }

    /// Reassigns sortIndex for a reordered list of decks.
    func reorder(_ decks: [Deck]) {
        for (index, deck) in decks.enumerated() {
            deck.sortIndex = index
            deck.modifiedAt = Date()
        }
    }

    // MARK: - Delete (soft)

    func delete(_ deck: Deck) {
        let now = Date()
        deck.deletedAt = now
        deck.modifiedAt = now
        for card in deck.cards where card.deletedAt == nil {
            card.deletedAt = now
            card.modifiedAt = now
        }
    }

    func restore(_ deck: Deck) {
        deck.deletedAt = nil
        deck.modifiedAt = Date()
    }

    // MARK: - Gesture settings

    /// Ensures the deck has its own GestureSettings, creating from defaults if absent.
    @discardableResult
    func ensureGestureSettings(for deck: Deck) -> GestureSettings {
        if let existing = deck.gestureSettings { return existing }
        let settings = GestureSettings(deckID: deck.id)
        context.insert(settings)
        deck.gestureSettings = settings
        return settings
    }
}
