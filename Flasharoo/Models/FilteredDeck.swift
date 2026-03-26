//
//  FilteredDeck.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData

/// A saved search query that behaves like a deck in the study interface.
/// If rescheduleCards is false, ratings do not affect the card's real schedule (cram mode).
@Model
final class FilteredDeck {
    @Attribute(.unique) var id: UUID
    var name: String
    var queryString: String
    var rescheduleCards: Bool
    var limitCount: Int?
    var sortOrder: FilteredDeckSort
    var createdAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        queryString: String,
        rescheduleCards: Bool = true,
        limitCount: Int? = nil,
        sortOrder: FilteredDeckSort = .dueDate
    ) {
        self.id = id
        self.name = name
        self.queryString = queryString
        self.rescheduleCards = rescheduleCards
        self.limitCount = limitCount
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.deletedAt = nil
    }
}
