//
//  SchedulerServiceTests.swift
//  FlasharooTests
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Verifies SM-2 and FSRS v5 output against reference algorithm values.
//  All SchedulerService computation methods are nonisolated, so no async needed.
//

import Testing
@testable import Flasharoo

struct SchedulerServiceTests {

    let sched = SchedulerService()

    // MARK: - SM-2

    @Test func sm2_firstPass_grade4() {
        let r = sched.sm2(grade: 4, repetitions: 0, easeFactor: 2.5, interval: 0)
        #expect(r.repetitions == 1)
        #expect(r.interval == 1)
        #expect(r.easeFactor > 2.5)          // grade 4 increases EF
    }

    @Test func sm2_secondPass_grade3() {
        let r = sched.sm2(grade: 3, repetitions: 1, easeFactor: 2.5, interval: 1)
        #expect(r.repetitions == 2)
        #expect(r.interval == 6)             // second pass always 6 days
        #expect(abs(r.easeFactor - 2.5) < 0.001)  // grade 3 leaves EF unchanged
    }

    @Test func sm2_thirdPass_grade3() {
        let r = sched.sm2(grade: 3, repetitions: 2, easeFactor: 2.5, interval: 6)
        #expect(r.repetitions == 3)
        #expect(r.interval == 15)            // 6 * 2.5 = 15.0 → 15
    }

    @Test func sm2_fail_resetsRepetitions() {
        let r = sched.sm2(grade: 1, repetitions: 5, easeFactor: 2.5, interval: 30)
        #expect(r.repetitions == 0)
        #expect(r.interval == 1)
    }

    @Test func sm2_easeFactor_floorAt1_3() {
        let r = sched.sm2(grade: 0, repetitions: 0, easeFactor: 1.3, interval: 0)
        #expect(r.easeFactor >= 1.3)
    }

    @Test func sm2_grade5_increasesEFMoreThanGrade3() {
        let r3 = sched.sm2(grade: 3, repetitions: 0, easeFactor: 2.5, interval: 0)
        let r5 = sched.sm2(grade: 5, repetitions: 0, easeFactor: 2.5, interval: 0)
        #expect(r5.easeFactor > r3.easeFactor)
    }

    // MARK: - FSRS retrievability

    @Test func fsrs_retrievability_atStability_is90Pct() {
        // Core FSRS invariant: R(t=S, S) == 0.9
        let s = 10.0
        let r = sched.retrievability(t: s, s: s)
        #expect(abs(r - 0.9) < 0.0001)
    }

    @Test func fsrs_retrievability_decaysOverTime() {
        let s = 10.0
        let r5  = sched.retrievability(t: 5,  s: s)
        let r10 = sched.retrievability(t: 10, s: s)
        let r20 = sched.retrievability(t: 20, s: s)
        #expect(r5 > r10)
        #expect(r10 > r20)
    }

    @Test func fsrs_retrievability_zeroStability_returnsZero() {
        #expect(sched.retrievability(t: 1, s: 0) == 0)
    }

    // MARK: - FSRS initial state

    @Test func fsrs_initialStability_easyHigherThanAgain() {
        let sAgain = sched.initialStability(rating: 1)
        let sEasy  = sched.initialStability(rating: 4)
        #expect(sEasy > sAgain)
    }

    @Test func fsrs_initialStability_matchesWeights() {
        // w[0]-w[3] directly map to ratings 1-4
        for rating in 1...4 {
            let s = sched.initialStability(rating: rating)
            #expect(abs(s - SchedulerService.w[rating - 1]) < 0.0001)
        }
    }

    @Test func fsrs_initialDifficulty_easyLowerThanAgain() {
        let dAgain = sched.initialDifficulty(rating: 1)
        let dEasy  = sched.initialDifficulty(rating: 4)
        #expect(dEasy < dAgain)
    }

    @Test func fsrs_initialDifficulty_clampedTo1_10() {
        for rating in 1...4 {
            let d = sched.initialDifficulty(rating: rating)
            #expect(d >= 1.0 && d <= 10.0)
        }
    }

    // MARK: - FSRS stability after recall

    @Test func fsrs_recall_increasesStability() {
        let s = 5.0; let d = 5.0
        let r = sched.retrievability(t: 5, s: s)
        let sNew = sched.stabilityAfterRecall(d: d, s: s, r: r, rating: 3)
        #expect(sNew > s)
    }

    @Test func fsrs_recall_easyHigherThanGood() {
        let s = 5.0; let d = 5.0
        let r = sched.retrievability(t: 5, s: s)
        let sGood = sched.stabilityAfterRecall(d: d, s: s, r: r, rating: 3)
        let sEasy = sched.stabilityAfterRecall(d: d, s: s, r: r, rating: 4)
        #expect(sEasy > sGood)
    }

    @Test func fsrs_recall_hardLowerThanGood() {
        let s = 5.0; let d = 5.0
        let r = sched.retrievability(t: 5, s: s)
        let sHard = sched.stabilityAfterRecall(d: d, s: s, r: r, rating: 2)
        let sGood = sched.stabilityAfterRecall(d: d, s: s, r: r, rating: 3)
        #expect(sHard < sGood)
    }

    // MARK: - FSRS stability after lapse

    @Test func fsrs_lapse_decreasesStability() {
        let s = 10.0; let d = 5.0
        let r = sched.retrievability(t: 10, s: s)
        let sNew = sched.stabilityAfterLapse(d: d, s: s, r: r)
        #expect(sNew < s)
        #expect(sNew >= 0.01)
    }

    @Test func fsrs_lapse_neverExceedsOriginal() {
        let s = 10.0; let d = 5.0
        let r = sched.retrievability(t: 10, s: s)
        let sNew = sched.stabilityAfterLapse(d: d, s: s, r: r)
        #expect(sNew <= s)
    }

    // MARK: - FSRS difficulty update

    @Test func fsrs_difficulty_againIncreasesIt() {
        let d = 5.0
        let dNew = sched.nextDifficulty(d: d, rating: 1)
        #expect(dNew > d)
    }

    @Test func fsrs_difficulty_easyDecreasesIt() {
        let d = 5.0
        let dNew = sched.nextDifficulty(d: d, rating: 4)
        #expect(dNew < d)
    }

    @Test func fsrs_difficulty_alwaysClamped() {
        let dHigh = sched.nextDifficulty(d: 9.8, rating: 1)
        let dLow  = sched.nextDifficulty(d: 1.2, rating: 4)
        #expect(dHigh <= 10.0)
        #expect(dLow  >= 1.0)
    }

    // MARK: - Scheduled interval

    @Test func fsrs_interval_equalsStabilityAt90PctRetention() {
        // Mathematical identity: scheduledInterval(s) ≈ round(s)
        for s in [1.0, 5.0, 10.0, 30.0, 100.0] {
            let days = sched.scheduledInterval(stability: s)
            #expect(abs(Double(days) - s) < 1.0)
        }
    }

    @Test func fsrs_interval_minimumIsOneDay() {
        #expect(sched.scheduledInterval(stability: 0.1) == 1)
    }

    // MARK: - Full review cycle

    @Test func fsrs_newCard_ratedGood_setsSchedule() {
        let card = CardScheduleState(
            sm2EaseFactor: 2.5, sm2Interval: 0, sm2Repetitions: 0,
            fsrsStability: 0, fsrsDifficulty: 0, fsrsLastReviewDate: nil,
            fsrsScheduledDays: 0, state: .new, dueDate: Date()
        )
        let result = sched.nextReview(for: card, rating: 3, algorithm: .fsrs)
        #expect(result.interval > 0)
        #expect(result.updatedCard.fsrsStability > 0)
        #expect(result.updatedCard.fsrsDifficulty > 0)
        #expect(result.nextReviewDate > Date())
    }

    @Test func fsrs_newCard_ratedAgain_goesToLearning() {
        let card = CardScheduleState(
            sm2EaseFactor: 2.5, sm2Interval: 0, sm2Repetitions: 0,
            fsrsStability: 0, fsrsDifficulty: 0, fsrsLastReviewDate: nil,
            fsrsScheduledDays: 0, state: .new, dueDate: Date()
        )
        let result = sched.nextReview(for: card, rating: 1, algorithm: .fsrs)
        #expect(result.interval == 0)
        #expect(result.updatedState == .learning)
    }

    @Test func sm2_newCard_ratedGood_interval1Day() {
        let card = CardScheduleState(
            sm2EaseFactor: 2.5, sm2Interval: 0, sm2Repetitions: 0,
            fsrsStability: 0, fsrsDifficulty: 0, fsrsLastReviewDate: nil,
            fsrsScheduledDays: 0, state: .new, dueDate: Date()
        )
        let result = sched.nextReview(for: card, rating: 3, algorithm: .sm2)
        #expect(result.interval == 1)
        #expect(result.updatedState == .review)
    }

    // MARK: - Interval hint formatting

    @Test func formatDays_lessThan30_showsDays() {
        #expect(sched.formatDays(7)  == "7d")
        #expect(sched.formatDays(29) == "29d")
    }

    @Test func formatDays_30Plus_showsMonths() {
        #expect(sched.formatDays(30) == "1mo")
        #expect(sched.formatDays(60) == "2mo")
    }

    @Test func formatDays_12Months_showsYear() {
        #expect(sched.formatDays(365) == "12mo") // 365/30 = 12 months
    }
}
