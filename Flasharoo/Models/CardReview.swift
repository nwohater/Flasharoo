//
//  CardReview.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData

/// Append-only review record — never updated after creation.
/// This makes CloudKit sync conflicts impossible for review data.
@Model
final class CardReview {
    @Attribute(.unique) var id: UUID
    @Attribute(.indexed) var cardID: UUID
    @Attribute(.indexed) var reviewedAt: Date
    var rating: Int                     // SM-2: 0–5  |  FSRS: 1–4
    var algorithm: SchedulerAlgorithm
    var intervalBefore: Int             // days
    var intervalAfter: Int              // days
    var timeTaken: TimeInterval         // seconds spent on this card
    var card: Card?

    init(
        id: UUID = UUID(),
        cardID: UUID,
        reviewedAt: Date = Date(),
        rating: Int,
        algorithm: SchedulerAlgorithm,
        intervalBefore: Int,
        intervalAfter: Int,
        timeTaken: TimeInterval
    ) {
        self.id = id
        self.cardID = cardID
        self.reviewedAt = reviewedAt
        self.rating = rating
        self.algorithm = algorithm
        self.intervalBefore = intervalBefore
        self.intervalAfter = intervalAfter
        self.timeTaken = timeTaken
    }
}
