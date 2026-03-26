//
//  BackgroundDataActor.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData

/// Performs heavy data operations off the main thread.
/// All SwiftData access uses this actor's private ModelContext.
/// Callers receive lightweight value types (counts, IDs) — never SwiftData model objects.
actor BackgroundDataActor: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor

    init(container: ModelContainer) {
        self.modelContainer = container
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    // MARK: - Study queue

    /// Builds an ordered list of PersistentIdentifiers for a study session.
    /// Cards are interleaved: 4 reviews per 1 new card.
    /// Callers fetch cards one at a time during study — never holds all cards in memory.
    func buildStudyQueue(
        deckID: UUID,
        newLimit: Int,
        reviewLimit: Int
    ) -> [PersistentIdentifier] {
        let now = Date()

        // Fetch all active cards for the deck — filter state in-memory to avoid
        // enum predicate limitations in SwiftData macros.
        var descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.deckID == deckID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Card.dueDate)]
        )
        descriptor.propertiesToFetch = [\.state, \.dueDate, \.createdAt]

        let all = (try? modelContext.fetch(descriptor)) ?? []

        let dueReviews = all
            .filter { $0.state == .review || $0.state == .learning }
            .filter { $0.dueDate <= now }
            .prefix(reviewLimit)

        let newCards = all
            .filter { $0.state == .new }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(newLimit)

        // Interleave: 4 reviews then 1 new card
        var queue: [PersistentIdentifier] = []
        var ri = dueReviews.startIndex
        var ni = newCards.startIndex

        while ri < dueReviews.endIndex || ni < newCards.endIndex {
            let batch = min(4, dueReviews.distance(from: ri, to: dueReviews.endIndex))
            for _ in 0..<batch {
                queue.append(dueReviews[ri].persistentModelID)
                dueReviews.formIndex(after: &ri)
            }
            if ni < newCards.endIndex {
                queue.append(newCards[ni].persistentModelID)
                newCards.formIndex(after: &ni)
            }
            if batch == 0 && ni >= newCards.endIndex { break }
        }

        return queue
    }

    // MARK: - Counts

    func dueTodayCount(deckID: UUID) -> Int {
        let now = Date()
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.deckID == deckID && $0.deletedAt == nil && $0.dueDate <= now }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.state == .review || $0.state == .learning }.count
    }

    func newCardCount(deckID: UUID) -> Int {
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.deckID == deckID && $0.deletedAt == nil }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.state == .new }.count
    }

    func totalCardCount(deckID: UUID) -> Int {
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.deckID == deckID && $0.deletedAt == nil }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Bulk operations

    func bulkTag(
        cardIDs: [PersistentIdentifier],
        addTags: [String],
        removeTags: [String]
    ) {
        for id in cardIDs {
            guard let card = modelContext.model(for: id) as? Card else { continue }
            var tags = card.tagList
            tags.removeAll { removeTags.contains($0) }
            for tag in addTags where !tags.contains(tag) {
                tags.append(tag)
            }
            card.tagList = tags
            card.modifiedAt = Date()
        }
        try? modelContext.save()
    }

    func bulkDelete(cardIDs: [PersistentIdentifier]) {
        let now = Date()
        for id in cardIDs {
            guard let card = modelContext.model(for: id) as? Card else { continue }
            card.deletedAt = now
            card.modifiedAt = now
        }
        try? modelContext.save()
    }

    func bulkSuspend(cardIDs: [PersistentIdentifier]) {
        for id in cardIDs {
            guard let card = modelContext.model(for: id) as? Card else { continue }
            card.state = .suspended
            card.modifiedAt = Date()
        }
        try? modelContext.save()
    }

    // MARK: - Soft-delete cleanup

    /// Permanently deletes records soft-deleted more than 30 days ago.
    /// Called from BGAppRefreshTask, not during active study.
    func purgeOldSoftDeletes() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        let oldCardDescriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.deletedAt != nil }
        )
        if let cards = try? modelContext.fetch(oldCardDescriptor) {
            cards
                .filter { $0.deletedAt! < cutoff }
                .forEach { modelContext.delete($0) }
        }

        let oldDeckDescriptor = FetchDescriptor<Deck>(
            predicate: #Predicate { $0.deletedAt != nil }
        )
        if let decks = try? modelContext.fetch(oldDeckDescriptor) {
            decks
                .filter { $0.deletedAt! < cutoff }
                .forEach { modelContext.delete($0) }
        }

        try? modelContext.save()
    }
}
