//
//  StatsView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Single view for both global stats (deckID == nil) and per-deck stats.
//  All data computed off the main thread by BackgroundDataActor.
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext

    let title: String
    let deckID: UUID?

    @State private var vm: StatsViewModel?

    init(title: String = "Statistics", deckID: UUID? = nil) {
        self.title = title
        self.deckID = deckID
    }

    var body: some View {
        Group {
            if let data = vm?.data {
                statsContent(data)
            } else if vm?.isLoading == true {
                ProgressView("Loading statistics…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            if vm == nil {
                vm = StatsViewModel(container: modelContext.container)
            }
            await vm?.load(deckID: deckID)
        }
        .refreshable {
            await vm?.load(deckID: deckID)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func statsContent(_ data: StatsData) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {

                // ── Summary row ────────────────────────────────────────────
                summarySection(data)

                // ── Heatmap ────────────────────────────────────────────────
                chartSection(title: "Review History", systemImage: "calendar") {
                    RetentionHeatmapView(summaries: data.dailySummaries)
                }

                // ── Daily bar chart ────────────────────────────────────────
                chartSection(title: "Daily Reviews (30d)", systemImage: "chart.bar") {
                    DailyReviewChart(summaries: data.last30Days)
                }

                // ── Forecast ───────────────────────────────────────────────
                chartSection(title: "Forecast (30d)", systemImage: "calendar.badge.clock") {
                    ForecastChart(forecast: data.forecast)
                }

                // ── Card states ────────────────────────────────────────────
                if !data.cardStateCounts.isEmpty {
                    chartSection(title: "Card States", systemImage: "chart.pie") {
                        CardStateChart(stateCounts: data.cardStateCounts)
                    }
                }

                // ── Ease factor ────────────────────────────────────────────
                let easeTotal = data.easeFactorBins.reduce(0) { $0 + $1.count }
                if easeTotal > 0 {
                    chartSection(title: "Ease Factor Distribution (SM-2)", systemImage: "dial.medium") {
                        EaseFactorChart(bins: data.easeFactorBins)
                    }
                }

                // ── Interval distribution ──────────────────────────────────
                let intervalTotal = data.intervalBins.reduce(0) { $0 + $1.count }
                if intervalTotal > 0 {
                    chartSection(title: "Interval Distribution", systemImage: "arrow.triangle.2.circlepath") {
                        IntervalChart(bins: data.intervalBins)
                    }
                }

                // ── FSRS only ──────────────────────────────────────────────
                let stabilityTotal = data.stabilityBins.reduce(0) { $0 + $1.count }
                if stabilityTotal > 0 {
                    chartSection(title: "Memory Stability (FSRS)", systemImage: "brain") {
                        StabilityChart(bins: data.stabilityBins)
                    }
                }

                chartSection(title: "Retention Curves (FSRS)", systemImage: "waveform.path.ecg") {
                    RetentionCurveChart(points: data.retentionCurve)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Summary section

    private func summarySection(_ data: StatsData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Summary", systemImage: "star")
                .font(.headline)
                .foregroundStyle(.secondary)

            Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    statCard(
                        value: "\(data.currentStreak)",
                        label: "Day Streak",
                        icon: "flame.fill",
                        color: data.currentStreak > 0 ? .orange : .secondary
                    )
                    statCard(
                        value: "\(data.longestStreak)",
                        label: "Best Streak",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                }
                GridRow {
                    statCard(
                        value: "\(data.totalReviews)",
                        label: "Total Reviews",
                        icon: "rectangle.stack.fill",
                        color: .blue
                    )
                    statCard(
                        value: "\(Int(data.averageRetention * 100))%",
                        label: "30d Retention",
                        icon: "brain.head.profile",
                        color: retentionColor(data.averageRetention)
                    )
                }
            }
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func retentionColor(_ r: Double) -> Color {
        r >= 0.9 ? .green : r >= 0.75 ? .orange : .red
    }

    // MARK: - Chart section wrapper

    @ViewBuilder
    private func chartSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
