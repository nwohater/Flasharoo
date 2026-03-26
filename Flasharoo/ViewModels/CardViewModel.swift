//
//  CardViewModel.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData
import Observation

/// Handles all Card CRUD operations and review insertion.
@Observable
final class CardViewModel {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    @discardableResult
    func createCard(
        in deck: Deck,
        front: String = "",
        back: String = "",
        tags: [String] = []
    ) -> Card {
        let card = Card(
            deckID: deck.id,
            front: front,
            back: back,
            tags: tags.joined(separator: " ")
        )
        context.insert(card)
        card.deck = deck
        deck.modifiedAt = Date()
        return card
    }

    // MARK: - Update

    func update(
        _ card: Card,
        front: String,
        back: String,
        tags: [String],
        flag: CardFlag
    ) {
        card.front = front
        card.back = back
        card.tags = tags.joined(separator: " ")
        card.flag = flag
        card.modifiedAt = Date()
    }

    func setFlag(_ flag: CardFlag, on card: Card) {
        card.flag = flag
        card.modifiedAt = Date()
    }

    func suspend(_ card: Card) {
        card.state = .suspended
        card.modifiedAt = Date()
    }

    func unsuspend(_ card: Card) {
        // Return to review if it has been studied, otherwise back to new
        card.state = card.reviews.isEmpty ? .new : .review
        card.modifiedAt = Date()
    }

    func bury(_ card: Card) {
        card.state = .buried
        card.modifiedAt = Date()
    }

    func unbury(_ card: Card) {
        card.state = card.reviews.isEmpty ? .new : .review
        card.modifiedAt = Date()
    }

    // MARK: - Delete (soft)

    func delete(_ card: Card) {
        card.deletedAt = Date()
        card.modifiedAt = Date()
    }

    func restore(_ card: Card) {
        card.deletedAt = nil
        card.modifiedAt = Date()
    }

    // MARK: - Review insert (append-only, never mutated after creation)

    @discardableResult
    func insertReview(
        for card: Card,
        rating: Int,
        algorithm: SchedulerAlgorithm,
        intervalBefore: Int,
        intervalAfter: Int,
        timeTaken: TimeInterval
    ) -> CardReview {
        let review = CardReview(
            cardID: card.id,
            rating: rating,
            algorithm: algorithm,
            intervalBefore: intervalBefore,
            intervalAfter: intervalAfter,
            timeTaken: timeTaken
        )
        context.insert(review)
        review.card = card
        return review
    }
}
