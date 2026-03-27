//
//  SchedulerService.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Implements SM-2 and FSRS v5 scheduling algorithms.
//  All computation methods are nonisolated (pure functions) so they can be
//  called synchronously from ViewModels and tests without actor overhead.
//

import Foundation

// MARK: - Value types

/// Snapshot of a card's scheduling fields passed across actor boundaries.
struct CardScheduleState {
    var sm2EaseFactor: Double
    var sm2Interval: Int
    var sm2Repetitions: Int
    var fsrsStability: Double
    var fsrsDifficulty: Double
    var fsrsLastReviewDate: Date?
    var fsrsScheduledDays: Int
    var state: CardState
    var dueDate: Date
}

extension CardScheduleState {
    init(card: Card) {
        sm2EaseFactor      = card.sm2EaseFactor
        sm2Interval        = card.sm2Interval
        sm2Repetitions     = card.sm2Repetitions
        fsrsStability      = card.fsrsStability
        fsrsDifficulty     = card.fsrsDifficulty
        fsrsLastReviewDate = card.fsrsLastReviewDate
        fsrsScheduledDays  = card.fsrsScheduledDays
        state              = card.state
        dueDate            = card.dueDate
    }
}

struct ScheduleResult {
    let nextReviewDate: Date
    /// Days until next review. 0 = same-day relearn step (10 min).
    let interval: Int
    let updatedState: CardState
    let updatedCard: CardScheduleState
}

/// Formatted labels shown on answer buttons, e.g. "Again: 10m · Good: 4d".
struct IntervalHint {
    let again: String
    let hard: String
    let good: String
    let easy: String
}

// MARK: - SchedulerService

actor SchedulerService {

    static let shared = SchedulerService()

    // MARK: - SM-2

    struct SM2Result {
        let interval: Int
        let easeFactor: Double
        let repetitions: Int
    }

    /// Pure SM-2 computation. Grade 0–5 (0–2 = fail, 3–5 = pass).
    nonisolated func sm2(
        grade: Int,
        repetitions: Int,
        easeFactor: Double,
        interval: Int
    ) -> SM2Result {
        precondition((0...5).contains(grade), "SM-2 grade must be 0–5")

        var newEF = easeFactor + 0.1 - Double(5 - grade) * (0.08 + Double(5 - grade) * 0.02)
        newEF = max(1.3, newEF)

        let newReps: Int
        let newInterval: Int

        if grade < 3 {
            newReps = 0
            newInterval = 1
        } else {
            newReps = repetitions + 1
            switch newReps {
            case 1:  newInterval = 1
            case 2:  newInterval = 6
            default: newInterval = max(1, Int((Double(interval) * newEF).rounded()))
            }
        }
        return SM2Result(interval: newInterval, easeFactor: newEF, repetitions: newReps)
    }

    // MARK: - FSRS v5

    /// Community-optimised FSRS v5 default weights (w[0]–w[18]).
    nonisolated static let w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722,   // w[0-3]:  S₀ per rating 1–4
        7.2102,                              // w[4]:    D₀ base
        0.5316,                              // w[5]:    D₀ rating sensitivity
        1.0651,                              // w[6]:    ΔD rating sensitivity
        0.0589,                              // w[7]:    mean-reversion factor
        1.5330,                              // w[8]:    recall stability coefficient
        0.1544,                              // w[9]:    recall S decay exponent
        1.0070,                              // w[10]:   recall R factor
        1.9395,                              // w[11]:   lapse stability base
        0.1100,                              // w[12]:   lapse D exponent
        0.2900,                              // w[13]:   lapse S exponent
        2.2700,                              // w[14]:   lapse R factor
        0.2500,                              // w[15]:   hard penalty
        2.9898,                              // w[16]:   easy bonus
        0.5100,                              // w[17]:   (reserved)
        0.4300                               // w[18]:   (reserved)
    ]

    /// Power-law forgetting curve decay. Fixed by FSRS design.
    nonisolated static let decay: Double = -0.5
    /// Scale factor such that R(t=S, S) == targetRetention. equals 19/81.
    nonisolated static let factor: Double = 19.0 / 81.0
    /// Desired retention probability at the scheduled review date.
    nonisolated static let targetRetention: Double = 0.9

    // MARK: FSRS core formulas

    /// Probability of recall after `t` days given stability `s`.
    /// R(t=S, S) = 0.9 by construction.
    nonisolated func retrievability(t: Double, s: Double) -> Double {
        guard s > 0 else { return 0 }
        return pow(1 + Self.factor * t / s, Self.decay)
    }

    /// Initial stability S₀ for a new card rated 1–4.
    nonisolated func initialStability(rating: Int) -> Double {
        max(Self.w[rating - 1], 0.01)
    }

    /// Initial difficulty D₀ for a new card rated 1–4, clamped to [1, 10].
    nonisolated func initialDifficulty(rating: Int) -> Double {
        let d = Self.w[4] - exp(Self.w[5] * Double(rating - 1)) + 1
        return min(max(d, 1.0), 10.0)
    }

    /// New stability after a successful recall (rating 2–4).
    nonisolated func stabilityAfterRecall(d: Double, s: Double, r: Double, rating: Int) -> Double {
        let w = Self.w
        let hardPenalty = rating == 2 ? w[15] : 1.0
        let easyBonus   = rating == 4 ? w[16] : 1.0
        let sNew = s * (exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1) * hardPenalty * easyBonus + 1)
        return max(sNew, 0.01)
    }

    /// New stability after a lapse (rating 1).
    nonisolated func stabilityAfterLapse(d: Double, s: Double, r: Double) -> Double {
        let w = Self.w
        let sNew = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
        return min(max(sNew, 0.01), s)
    }

    /// Next difficulty after a review, clamped to [1, 10].
    nonisolated func nextDifficulty(d: Double, rating: Int) -> Double {
        let w = Self.w
        let deltaD = -w[6] * Double(rating - 3)
        let d2 = d + deltaD * (10 - d) / 9        // linear damping toward bounds
        let d0_4 = initialDifficulty(rating: 4)
        let d3 = w[7] * d0_4 + (1 - w[7]) * d2   // mean reversion
        return min(max(d3, 1.0), 10.0)
    }

    /// Days to next review at `targetRetention`.
    /// At 90% retention this equals round(s) — S is defined as the stability
    /// where R(S, S) = 0.9.
    nonisolated func scheduledInterval(stability s: Double) -> Int {
        let t = s / Self.factor * (pow(Self.targetRetention, 1.0 / Self.decay) - 1)
        return max(1, Int(t.rounded()))
    }

    // MARK: - Public API

    /// Compute the next review date and updated scheduling state for a rating.
    nonisolated func nextReview(
        for card: CardScheduleState,
        rating: Int,
        algorithm: SchedulerAlgorithm,
        now: Date = Date()
    ) -> ScheduleResult {
        switch algorithm {
        case .sm2:  return sm2Review(card: card, grade: rating, now: now)
        case .fsrs: return fsrsReview(card: card, rating: rating, now: now)
        }
    }

    /// Interval hint labels for all four FSRS answer buttons.
    nonisolated func fsrsIntervalHints(for card: CardScheduleState, now: Date = Date()) -> IntervalHint {
        let elapsed = card.fsrsLastReviewDate.map { now.timeIntervalSince($0) / 86400 } ?? 0
        let r = card.fsrsStability > 0 ? retrievability(t: elapsed, s: card.fsrsStability) : 1.0

        func hint(rating: Int) -> String {
            guard card.fsrsStability > 0 else {
                return rating == 1 ? "10m" : formatDays(scheduledInterval(stability: initialStability(rating: rating)))
            }
            if rating == 1 {
                let s = stabilityAfterLapse(d: card.fsrsDifficulty, s: card.fsrsStability, r: r)
                return formatDays(max(1, scheduledInterval(stability: s)))
            }
            let s = stabilityAfterRecall(d: card.fsrsDifficulty, s: card.fsrsStability, r: r, rating: rating)
            return formatDays(scheduledInterval(stability: s))
        }

        return IntervalHint(again: hint(rating: 1), hard: hint(rating: 2),
                            good: hint(rating: 3), easy: hint(rating: 4))
    }

    /// Interval hint labels for SM-2 answer buttons.
    /// Maps: Again→grade 0, Hard→grade 2, Good→grade 3, Easy→grade 4.
    nonisolated func sm2IntervalHints(for card: CardScheduleState) -> IntervalHint {
        func days(_ grade: Int) -> Int {
            sm2(grade: grade, repetitions: card.sm2Repetitions,
                easeFactor: card.sm2EaseFactor, interval: card.sm2Interval).interval
        }
        return IntervalHint(
            again: "1d",
            hard:  formatDays(days(2)),
            good:  formatDays(days(3)),
            easy:  formatDays(days(4))
        )
    }

    // MARK: - Private helpers

    private nonisolated func sm2Review(card: CardScheduleState, grade: Int, now: Date) -> ScheduleResult {
        let r = sm2(grade: grade, repetitions: card.sm2Repetitions,
                    easeFactor: card.sm2EaseFactor, interval: card.sm2Interval)
        let newState: CardState = grade < 3 ? .learning : .review
        let nextDate = Calendar.current.date(byAdding: .day, value: r.interval, to: now) ?? now

        var updated = card
        updated.sm2EaseFactor  = r.easeFactor
        updated.sm2Interval    = r.interval
        updated.sm2Repetitions = r.repetitions
        updated.state          = newState
        updated.dueDate        = nextDate

        return ScheduleResult(nextReviewDate: nextDate, interval: r.interval,
                              updatedState: newState, updatedCard: updated)
    }

    private nonisolated func fsrsReview(card: CardScheduleState, rating: Int, now: Date) -> ScheduleResult {
        let newS: Double
        let newD: Double

        if card.fsrsStability == 0 {
            // First review — initialise from rating
            newS = initialStability(rating: rating)
            newD = initialDifficulty(rating: rating)
        } else {
            let elapsed = card.fsrsLastReviewDate.map { now.timeIntervalSince($0) / 86400 } ?? 0
            let r = retrievability(t: elapsed, s: card.fsrsStability)
            newD = nextDifficulty(d: card.fsrsDifficulty, rating: rating)
            newS = rating == 1
                ? stabilityAfterLapse(d: card.fsrsDifficulty, s: card.fsrsStability, r: r)
                : stabilityAfterRecall(d: card.fsrsDifficulty, s: card.fsrsStability, r: r, rating: rating)
        }

        let intervalDays: Int
        let newState: CardState
        let nextDate: Date

        if rating == 1 {
            intervalDays = 0
            newState = .learning
            nextDate = now.addingTimeInterval(10 * 60)   // 10-min relearn step
        } else {
            intervalDays = scheduledInterval(stability: newS)
            newState = intervalDays >= 21 ? .review : .learning
            nextDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: now) ?? now
        }

        var updated = card
        updated.fsrsStability      = newS
        updated.fsrsDifficulty     = newD
        updated.fsrsLastReviewDate = now
        updated.fsrsScheduledDays  = intervalDays
        updated.state              = newState
        updated.dueDate            = nextDate

        return ScheduleResult(nextReviewDate: nextDate, interval: intervalDays,
                              updatedState: newState, updatedCard: updated)
    }

    nonisolated func formatDays(_ days: Int) -> String {
        if days <= 0 { return "10m" }
        if days < 30 { return "\(days)d" }
        let months = days / 30
        if months < 12 { return "\(months)mo" }
        return "\(months / 12)y"
    }
}
