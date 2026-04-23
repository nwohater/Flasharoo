//
//  StudyViewModel.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

// MARK: - Study source

enum StudySource {
    case deck(Deck)
    case filteredDeck(name: String, cards: [Card], algorithm: SchedulerAlgorithm, rescheduleCards: Bool)

    var displayName: String {
        switch self {
        case .deck(let d):                  return d.name
        case .filteredDeck(let name, _, _, _): return name
        }
    }

    var algorithm: SchedulerAlgorithm {
        switch self {
        case .deck(let d):                      return d.algorithmOverride ?? .fsrs
        case .filteredDeck(_, _, let alg, _):   return alg
        }
    }

    var rescheduleCards: Bool {
        switch self {
        case .deck:                              return true
        case .filteredDeck(_, _, _, let r):      return r
        }
    }

    var deckIfPresent: Deck? {
        if case .deck(let d) = self { return d }
        return nil
    }

    var preloadedCards: [Card]? {
        if case .filteredDeck(_, let cards, _, _) = self { return cards }
        return nil
    }
}

// MARK: - ViewModel

@Observable
final class StudyViewModel {

    // MARK: - Public state

    private(set) var currentCard: Card?
    private(set) var isAnswerRevealed = false
    private(set) var isSessionComplete = false
    private(set) var stats = SessionStats()

    let source: StudySource

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

    // MARK: - Private

    private var queue: [Card] = []
    private var queueIndex = 0
    private var undoSnapshot: (card: Card, oldState: CardScheduleState, ratedAt: Date, review: CardReview?)?
    private var cardAppearTime = Date()

    private let modelContext: ModelContext
    private let scheduler = SchedulerService()

    // MARK: - Init

    private let cramMode: Bool

    init(deck: Deck, modelContext: ModelContext, cramMode: Bool = false) {
        self.source = .deck(deck)
        self.modelContext = modelContext
        self.cramMode = cramMode
    }

    init(
        cards: [Card],
        name: String,
        algorithm: SchedulerAlgorithm = .fsrs,
        rescheduleCards: Bool,
        modelContext: ModelContext
    ) {
        self.source = .filteredDeck(
            name: name,
            cards: cards,
            algorithm: algorithm,
            rescheduleCards: rescheduleCards
        )
        self.modelContext = modelContext
        self.cramMode = false
    }

    // MARK: - Session management

    func buildQueue() {
        let now = Date()

        if let preloaded = source.preloadedCards {
            // FilteredDeck: use the pre-fetched card list, filter suspended/buried
            queue = preloaded.filter {
                $0.deletedAt == nil &&
                $0.state != .suspended &&
                $0.state != .buried &&
                $0.dueDate <= now
            }
        } else if let deck = source.deckIfPresent {
            // Regular deck
            let active = deck.cards.filter {
                $0.deletedAt == nil &&
                $0.state != .suspended &&
                $0.state != .buried
            }
            queue = cramMode
                ? active.sorted { $0.dueDate < $1.dueDate }
                : active.filter { $0.dueDate <= now }.sorted { $0.dueDate < $1.dueDate }
        }

        queueIndex = 0
        currentCard = queue.first
        isSessionComplete = queue.isEmpty
        cardAppearTime = Date()
    }

    /// Restarts with ALL non-suspended cards regardless of due date (cram mode).
    func restartSession() {
        let allCards: [Card]
        if let preloaded = source.preloadedCards {
            allCards = preloaded.filter {
                $0.deletedAt == nil && $0.state != .suspended && $0.state != .buried
            }
        } else if let deck = source.deckIfPresent {
            allCards = deck.cards.filter {
                $0.deletedAt == nil && $0.state != .suspended && $0.state != .buried
            }.sorted { $0.dueDate < $1.dueDate }
        } else {
            allCards = []
        }

        queue            = allCards
        queueIndex       = 0
        currentCard      = allCards.first
        isSessionComplete = allCards.isEmpty
        isAnswerRevealed  = false
        undoSnapshot      = nil
        stats             = SessionStats()
        cardAppearTime    = Date()
    }

    var canUndo: Bool { undoSnapshot != nil }

    var remainingCount: Int { max(0, queue.count - queueIndex) }
    var totalCount: Int { queue.count }

    // MARK: - Actions

    func revealAnswer() {
        guard !isAnswerRevealed else { return }
        isAnswerRevealed = true
    }

    func rate(_ rating: Int) {
        guard let card = currentCard else { return }

        let algorithm = source.algorithm
        let oldState = CardScheduleState(card: card)
        let result = scheduler.nextReview(for: oldState, rating: rating, algorithm: algorithm)
        let timeTaken = Date().timeIntervalSince(cardAppearTime)

        var savedReview: CardReview? = nil

        if source.rescheduleCards {
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
            savedReview = review
            try? modelContext.save()
        }

        // Save undo snapshot after review is created so we can mark it undone
        undoSnapshot = (card: card, oldState: oldState, ratedAt: Date(), review: savedReview)

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

        if source.rescheduleCards {
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
            if let review = snap.review {
                review.undoneAt = Date()
            }
            try? modelContext.save()
        }

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
        if source.rescheduleCards { try? modelContext.save() }
    }

    // MARK: - Interval hints

    var intervalHints: IntervalHint {
        guard let card = currentCard else {
            return IntervalHint(again: "—", hard: "—", good: "—", easy: "—")
        }
        let state = CardScheduleState(card: card)
        switch source.algorithm {
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
