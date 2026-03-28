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

    // MARK: - Statistics

    /// Computes all stats for the global view (deckID == nil) or a single deck.
    /// Runs entirely on this actor's private context — never blocks the main thread.
    func computeStats(deckID: UUID? = nil) -> StatsData {
        let calendar = Calendar.current
        let now = Date()

        // ── Cards ──────────────────────────────────────────────────────────────
        var cardDescriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        if let deckID {
            cardDescriptor.predicate = #Predicate { $0.deckID == deckID && $0.deletedAt == nil }
        }
        let cards = (try? modelContext.fetch(cardDescriptor)) ?? []
        let cardIDSet = Set(cards.map { $0.id })

        // ── Reviews ────────────────────────────────────────────────────────────
        let reviewDescriptor = FetchDescriptor<CardReview>(
            sortBy: [SortDescriptor(\CardReview.reviewedAt)]
        )
        var allReviews = (try? modelContext.fetch(reviewDescriptor)) ?? []
        if deckID != nil {
            allReviews = allReviews.filter { cardIDSet.contains($0.cardID) }
        }

        // ── Daily summaries (365 days) ─────────────────────────────────────────
        let byDay: [Date: [CardReview]] = Dictionary(
            grouping: allReviews,
            by: { calendar.startOfDay(for: $0.reviewedAt) }
        )

        let dailySummaries: [DailyReviewSummary] = (0..<365).map { offset in
            let date = calendar.date(byAdding: .day, value: -(364 - offset), to: now)!
            let day  = calendar.startOfDay(for: date)
            let dayReviews = byDay[day] ?? []
            return DailyReviewSummary(
                id: day,
                date: day,
                newCount:      dayReviews.filter { $0.intervalBefore == 0 }.count,
                learningCount: dayReviews.filter { $0.intervalBefore > 0 && $0.intervalBefore <= 1 }.count,
                reviewCount:   dayReviews.filter { $0.intervalBefore > 1 }.count,
                successCount:  dayReviews.filter { $0.rating >= 3 }.count
            )
        }

        // ── Streaks ────────────────────────────────────────────────────────────
        let (currentStreak, longestStreak) = computeStreaks(
            summaries: dailySummaries,
            calendar: calendar,
            now: now
        )

        // ── Average retention (last 30 days) ───────────────────────────────────
        let last30 = dailySummaries.suffix(30)
        let totalLast30 = last30.reduce(0) { $0 + $1.totalCount }
        let successLast30 = last30.reduce(0) { $0 + $1.successCount }
        let avgRetention = totalLast30 == 0 ? 1.0 : Double(successLast30) / Double(totalLast30)

        // ── Forecast (next 30 days) ────────────────────────────────────────────
        let forecast: [ForecastDay] = (0..<30).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let start = calendar.startOfDay(for: date)
            let end   = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
            let count = cards.filter {
                $0.state != .suspended && $0.state != .buried &&
                $0.dueDate >= start && $0.dueDate <= end
            }.count
            return ForecastDay(id: start, date: start, dueCount: count)
        }

        // ── Card state pie ─────────────────────────────────────────────────────
        let stateGroups = Dictionary(grouping: cards, by: \.state)
        let cardStateCounts = CardState.allCases.compactMap { state -> (String, Int)? in
            let count = stateGroups[state]?.count ?? 0
            return count > 0 ? (state.rawValue.capitalized, count) : nil
        }

        // ── Ease factor histogram (SM-2) ───────────────────────────────────────
        let easeValues = cards.filter { $0.sm2Repetitions > 0 }.map { $0.sm2EaseFactor }
        let easeFactorBins = makeEaseFactorBins(easeValues)

        // ── Interval histogram ─────────────────────────────────────────────────
        let intervalValues = cards.filter { $0.state == .review }.map {
            max($0.sm2Interval, $0.fsrsScheduledDays)
        }
        let intervalBins = makeIntervalBins(intervalValues)

        // ── FSRS stability histogram ───────────────────────────────────────────
        let stabilityValues = cards.filter { $0.fsrsStability > 0 }.map { $0.fsrsStability }
        let stabilityBins = makeStabilityBins(stabilityValues)

        // ── Retention curve (theoretical FSRS) ────────────────────────────────
        let retentionCurve = makeRetentionCurve()

        return StatsData(
            dailySummaries:   dailySummaries,
            forecast:         forecast,
            cardStateCounts:  cardStateCounts,
            easeFactorBins:   easeFactorBins,
            intervalBins:     intervalBins,
            stabilityBins:    stabilityBins,
            retentionCurve:   retentionCurve,
            totalReviews:     allReviews.count,
            currentStreak:    currentStreak,
            longestStreak:    longestStreak,
            averageRetention: avgRetention
        )
    }

    // MARK: - Stats helpers

    private func computeStreaks(
        summaries: [DailyReviewSummary],
        calendar: Calendar,
        now: Date
    ) -> (current: Int, longest: Int) {
        let studiedDays = Set(summaries.filter { $0.totalCount > 0 }.map { $0.date })
        let today = calendar.startOfDay(for: now)

        // Current streak
        var current = 0
        var check = studiedDays.contains(today) ? today :
                    calendar.date(byAdding: .day, value: -1, to: today)!
        while studiedDays.contains(check) {
            current += 1
            check = calendar.date(byAdding: .day, value: -1, to: check)!
        }

        // Longest streak
        var longest = 0
        var run = 0
        var prev: Date? = nil
        for day in studiedDays.sorted() {
            if let p = prev, calendar.date(byAdding: .day, value: 1, to: p) == day {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            prev = day
        }

        return (current, longest)
    }

    private func makeEaseFactorBins(_ values: [Double]) -> [HistogramBin] {
        // Bins: 1.3-1.5, 1.5-1.7, 1.7-1.9, 1.9-2.1, 2.1-2.3, 2.3-2.5, 2.5-2.7, 2.7-2.9, 2.9-3.1, 3.1+
        let boundaries: [Double] = [1.3, 1.5, 1.7, 1.9, 2.1, 2.3, 2.5, 2.7, 2.9, 3.1, Double.infinity]
        return zip(boundaries, boundaries.dropFirst()).map { lo, hi in
            let label = hi.isInfinite ? "≥\(String(format: "%.1f", lo))" : "\(String(format: "%.1f", lo))–\(String(format: "%.1f", hi))"
            let count = values.filter { $0 >= lo && $0 < hi }.count
            return HistogramBin(id: label, label: label, count: count)
        }
    }

    private func makeIntervalBins(_ values: [Int]) -> [HistogramBin] {
        let buckets: [(label: String, range: ClosedRange<Int>)] = [
            ("1d",     1...1),
            ("2d",     2...2),
            ("3–6d",   3...6),
            ("7–13d",  7...13),
            ("14–20d", 14...20),
            ("21–29d", 21...29),
            ("30–59d", 30...59),
            ("60–89d", 60...89),
            ("90–179d",90...179),
            ("180d+",  180...Int.max)
        ]
        return buckets.map { bucket in
            let count = values.filter { bucket.range.contains($0) }.count
            return HistogramBin(id: bucket.label, label: bucket.label, count: count)
        }
    }

    private func makeStabilityBins(_ values: [Double]) -> [HistogramBin] {
        let buckets: [(label: String, lo: Double, hi: Double)] = [
            ("<1d",    0,   1),
            ("1–3d",   1,   3),
            ("3–7d",   3,   7),
            ("7–14d",  7,   14),
            ("14–30d", 14,  30),
            ("30–60d", 30,  60),
            ("60–90d", 60,  90),
            ("90–180d",90,  180),
            ("180d+",  180, Double.infinity)
        ]
        return buckets.map { b in
            let count = values.filter { $0 >= b.lo && $0 < b.hi }.count
            return HistogramBin(id: b.label, label: b.label, count: count)
        }
    }

    private func makeRetentionCurve() -> [RetentionPoint] {
        // FSRS retrieval probability: R(t) = 0.9^(t/S)
        let stabilities: [(Double, String)] = [(1, "S=1d"), (7, "S=7d"), (30, "S=30d"), (90, "S=90d")]
        return stabilities.flatMap { (s, label) in
            (0...30).map { t in
                let r = pow(0.9, Double(t) / s)
                return RetentionPoint(
                    id: "\(t)-\(label)",
                    days: t,
                    retention: r,
                    seriesLabel: label
                )
            }
        }
    }

    // MARK: - Orphaned card adoption

    /// Moves cards whose deckID no longer matches any live deck into an "Unsorted" deck.
    /// Runs on launch after a potential mid-sync deck deletion from another device.
    func adoptOrphanedCards() {
        let deckDescriptor = FetchDescriptor<Deck>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let decks = (try? modelContext.fetch(deckDescriptor)) ?? []
        let validIDs = Set(decks.map { $0.id })

        let cardDescriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let allCards = (try? modelContext.fetch(cardDescriptor)) ?? []
        let orphans = allCards.filter { !validIDs.contains($0.deckID) }
        guard !orphans.isEmpty else { return }

        let unsorted: Deck
        if let existing = decks.first(where: { $0.name == "Unsorted" }) {
            unsorted = existing
        } else {
            let d = Deck(name: "Unsorted", sortIndex: decks.count)
            modelContext.insert(d)
            unsorted = d
        }

        for card in orphans {
            card.deckID = unsorted.id
        }
        try? modelContext.save()
    }

    // MARK: - Soft-delete cleanup

    /// Permanently deletes records soft-deleted more than 30 days ago.
    /// Called from BGProcessingTask, not during active study.
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
