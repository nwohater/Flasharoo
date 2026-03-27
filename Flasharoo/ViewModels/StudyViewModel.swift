//
//  StudyViewModel.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

@Observable
final class StudyViewModel {

    // MARK: - Public state

    private(set) var currentCard: Card?
    private(set) var isAnswerRevealed = false
    private(set) var isSessionComplete = false
    private(set) var stats = SessionStats()

    let deck: Deck

    // MARK: - Private

    private var queue: [Card] = []
    private var queueIndex = 0
    private var undoSnapshot: (card: Card, oldState: CardScheduleState, ratedAt: Date)?
    private var cardAppearTime = Date()

    private let modelContext: ModelContext
    private let scheduler = SchedulerService()

    // MARK: - Session stats

    struct SessionStats {
        var totalReviewed = 0
        var goodOrEasyCount = 0
        var startTime = Date()

        var retention: Double {
            totalReviewed == 0 ? 1.0 : Double(goodOrEasyCount) / Double(totalReviewed)
        }
        var elapsed: TimeInterval { Date().timeIntervalSince(startTime) }
    }

    // MARK: - Init

    init(deck: Deck, modelContext: ModelContext) {
        self.deck = deck
        self.modelContext = modelContext
    }

    // MARK: - Session management

    func buildQueue() {
        let now = Date()
        let active = deck.cards.filter {
            $0.deletedAt == nil &&
            $0.state != .suspended &&
            $0.state != .buried
        }
        queue = active
            .filter { $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }

        queueIndex = 0
        currentCard = queue.first
        isSessionComplete = queue.isEmpty
        cardAppearTime = Date()
    }

    var remainingCount: Int { max(0, queue.count - queueIndex) }

    // MARK: - Actions

    func revealAnswer() {
        guard !isAnswerRevealed else { return }
        isAnswerRevealed = true
    }

    func rate(_ rating: Int) {
        guard let card = currentCard else { return }

        let algorithm = deck.algorithmOverride ?? .fsrs
        let oldState = CardScheduleState(card: card)
        let result = scheduler.nextReview(for: oldState, rating: rating, algorithm: algorithm)
        let timeTaken = Date().timeIntervalSince(cardAppearTime)

        // Save undo snapshot
        undoSnapshot = (card: card, oldState: oldState, ratedAt: Date())

        // Apply scheduling state to card
        card.sm2EaseFactor      = result.updatedCard.sm2EaseFactor
        card.sm2Interval        = result.updatedCard.sm2Interval
        card.sm2Repetitions     = result.updatedCard.sm2Repetitions
        card.fsrsStability      = result.updatedCard.fsrsStability
        card.fsrsDifficulty     = result.updatedCard.fsrsDifficulty
        card.fsrsLastReviewDate = result.updatedCard.fsrsLastReviewDate
        card.fsrsScheduledDays  = result.updatedCard.fsrsScheduledDays
        card.state              = result.updatedState
        card.dueDate            = result.nextReviewDate
        card.modifiedAt         = Date()

        // Append-only review record
        let review = CardReview(
            cardID: card.id,
            rating: rating,
            algorithm: algorithm,
            intervalBefore: oldState.sm2Interval,
            intervalAfter: result.interval,
            timeTaken: timeTaken
        )
        modelContext.insert(review)
        try? modelContext.save()

        stats.totalReviewed += 1
        if rating >= 3 { stats.goodOrEasyCount += 1 }

        advance()
    }

    func skip() {
        advance()
    }

    func undoLastRating() {
        guard let snap = undoSnapshot,
              let idx = queue.firstIndex(where: { $0.id == snap.card.id })
        else { return }

        let card = snap.card
        let old  = snap.oldState

        card.sm2EaseFactor      = old.sm2EaseFactor
        card.sm2Interval        = old.sm2Interval
        card.sm2Repetitions     = old.sm2Repetitions
        card.fsrsStability      = old.fsrsStability
        card.fsrsDifficulty     = old.fsrsDifficulty
        card.fsrsLastReviewDate = old.fsrsLastReviewDate
        card.fsrsScheduledDays  = old.fsrsScheduledDays
        card.state              = old.state
        card.dueDate            = old.dueDate
        card.modifiedAt         = Date()
        try? modelContext.save()

        stats.totalReviewed    = max(0, stats.totalReviewed - 1)
        stats.goodOrEasyCount  = max(0, stats.goodOrEasyCount - 1)

        queueIndex             = idx
        currentCard            = card
        isAnswerRevealed       = false
        isSessionComplete      = false
        undoSnapshot           = nil
        cardAppearTime         = Date()
    }

    func toggleFlag() {
        guard let card = currentCard else { return }
        card.flag = card.flag == .none ? .red : .none
        card.modifiedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Interval hints

    var intervalHints: IntervalHint {
        guard let card = currentCard else {
            return IntervalHint(again: "—", hard: "—", good: "—", easy: "—")
        }
        let state = CardScheduleState(card: card)
        switch deck.algorithmOverride ?? .fsrs {
        case .fsrs: return scheduler.fsrsIntervalHints(for: state)
        case .sm2:  return scheduler.sm2IntervalHints(for: state)
        }
    }

    // MARK: - Private

    private func advance() {
        isAnswerRevealed = false
        queueIndex += 1
        if queueIndex < queue.count {
            currentCard = queue[queueIndex]
            cardAppearTime = Date()
        } else {
            currentCard = nil
            isSessionComplete = true
        }
    }
}
