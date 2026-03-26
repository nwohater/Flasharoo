//
//  Deck.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData

@Model
final class Deck {
    @Attribute(.unique) var id: UUID
    var name: String
    var descriptionText: String
    var algorithmOverride: SchedulerAlgorithm?
    var newCardsPerDay: Int
    var maxReviewsPerDay: Int
    var newCardOrder: NewCardOrder
    var sortIndex: Int
    var createdAt: Date
    var modifiedAt: Date
    var deletedAt: Date?

    @Relationship(deleteRule: .cascade) var cards: [Card] = []
    @Relationship(deleteRule: .cascade) var gestureSettings: GestureSettings?

    init(
        id: UUID = UUID(),
        name: String,
        descriptionText: String = "",
        algorithmOverride: SchedulerAlgorithm? = nil,
        newCardsPerDay: Int = 20,
        maxReviewsPerDay: Int = 200,
        newCardOrder: NewCardOrder = .inOrder,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.descriptionText = descriptionText
        self.algorithmOverride = algorithmOverride
        self.newCardsPerDay = newCardsPerDay
        self.maxReviewsPerDay = maxReviewsPerDay
        self.newCardOrder = newCardOrder
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.deletedAt = nil
    }
}
