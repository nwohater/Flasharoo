//
//  Card.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData

@Model
final class Card {
    @Attribute(.unique) var id: UUID
    @Attribute(.indexed) var deckID: UUID
    var front: String                       // HTML string
    var back: String                        // HTML string
    @Attribute(.indexed) var tags: String   // space-separated, tokenised for FTS
    @Attribute(.indexed) var state: CardState
    @Attribute(.indexed) var dueDate: Date
    var flag: CardFlag
    @Attribute(.indexed) var createdAt: Date
    var modifiedAt: Date
    var deletedAt: Date?

    // SM-2 state
    var sm2EaseFactor: Double
    var sm2Interval: Int
    var sm2Repetitions: Int

    // FSRS state
    var fsrsStability: Double
    var fsrsDifficulty: Double
    var fsrsLastReviewDate: Date?
    var fsrsScheduledDays: Int

    @Relationship(deleteRule: .cascade) var reviews: [CardReview] = []
    @Relationship(deleteRule: .cascade) var mediaAssets: [MediaAsset] = []
    var deck: Deck?

    /// Convenience: tags as a sorted array
    var tagList: [String] {
        get { tags.split(separator: " ").map(String.init).filter { !$0.isEmpty } }
        set { tags = newValue.joined(separator: " ") }
    }

    init(
        id: UUID = UUID(),
        deckID: UUID,
        front: String = "",
        back: String = "",
        tags: String = "",
        state: CardState = .new,
        dueDate: Date = Date(),
        flag: CardFlag = .none,
        sm2EaseFactor: Double = 2.5,
        sm2Interval: Int = 0,
        sm2Repetitions: Int = 0,
        fsrsStability: Double = 0,
        fsrsDifficulty: Double = 0,
        fsrsLastReviewDate: Date? = nil,
        fsrsScheduledDays: Int = 0
    ) {
        self.id = id
        self.deckID = deckID
        self.front = front
        self.back = back
        self.tags = tags
        self.state = state
        self.dueDate = dueDate
        self.flag = flag
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.deletedAt = nil
        self.sm2EaseFactor = sm2EaseFactor
        self.sm2Interval = sm2Interval
        self.sm2Repetitions = sm2Repetitions
        self.fsrsStability = fsrsStability
        self.fsrsDifficulty = fsrsDifficulty
        self.fsrsLastReviewDate = fsrsLastReviewDate
        self.fsrsScheduledDays = fsrsScheduledDays
    }
}
