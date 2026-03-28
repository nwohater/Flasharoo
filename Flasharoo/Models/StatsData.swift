//
//  StatsData.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Value types produced by BackgroundDataActor.computeStats and consumed by StatsView.
//  All types are Sendable so they can cross actor boundaries safely.
//

import Foundation

// MARK: - Daily review summary (one per calendar day)

struct DailyReviewSummary: Identifiable, Sendable {
    let id: Date         // start-of-day
    let date: Date
    let newCount: Int
    let learningCount: Int
    let reviewCount: Int
    let successCount: Int

    var totalCount: Int { newCount + learningCount + reviewCount }
    var retention: Double {
        totalCount == 0 ? 0.0 : Double(successCount) / Double(totalCount)
    }
}

// MARK: - Forecast

struct ForecastDay: Identifiable, Sendable {
    let id: Date
    let date: Date
    let dueCount: Int
}

// MARK: - Histogram bin (pre-bucketed for display)

struct HistogramBin: Identifiable, Sendable {
    let id: String   // label used as stable ID
    let label: String
    let count: Int
}

// MARK: - Retention curve point

struct RetentionPoint: Identifiable, Sendable {
    let id: String          // "\(days)-S\(stability)"
    let days: Int
    let retention: Double
    let seriesLabel: String // e.g. "S=7d"
}

// MARK: - Full stats payload

struct StatsData: Sendable {
    // Heatmap + 30-day bar chart
    let dailySummaries: [DailyReviewSummary]    // last 365 days, oldest first

    // Forecast
    let forecast: [ForecastDay]                 // next 30 days

    // Pie chart
    let cardStateCounts: [(state: String, count: Int)]

    // Histograms (pre-binned)
    let easeFactorBins: [HistogramBin]
    let intervalBins: [HistogramBin]
    let stabilityBins: [HistogramBin]           // FSRS only

    // Retention curve (theoretical, FSRS formula)
    let retentionCurve: [RetentionPoint]

    // Summary numbers
    let totalReviews: Int
    let currentStreak: Int
    let longestStreak: Int
    let averageRetention: Double                // over last 30 days

    // Convenience
    var last30Days: [DailyReviewSummary] { Array(dailySummaries.suffix(30)) }
}
