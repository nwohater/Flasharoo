//
//  StatsCharts.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  All Swift Charts chart views used in StatsView:
//    DailyReviewChart, ForecastChart, CardStateChart,
//    EaseFactorChart, IntervalChart, StabilityChart, RetentionCurveChart
//

import SwiftUI
import Charts

// MARK: - Daily review bar chart (last 30 days, stacked)

struct DailyReviewChart: View {
    let summaries: [DailyReviewSummary]  // pass last30Days

    // Flatten to long form for stacked bars
    private struct Entry: Identifiable {
        let id: String
        let date: Date
        let type: String
        let count: Int
    }

    private var entries: [Entry] {
        summaries.flatMap { s in [
            Entry(id: "\(s.date)-new",      date: s.date, type: "New",      count: s.newCount),
            Entry(id: "\(s.date)-learning", date: s.date, type: "Learning", count: s.learningCount),
            Entry(id: "\(s.date)-review",   date: s.date, type: "Review",   count: s.reviewCount)
        ]}
    }

    private func color(for type: String) -> Color {
        switch type {
        case "New":      return .blue
        case "Learning": return .orange
        default:         return .green
        }
    }

    var body: some View {
        Chart(entries) { entry in
            BarMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Cards", entry.count)
            )
            .foregroundStyle(by: .value("Type", entry.type))
        }
        .chartForegroundStyleScale([
            "New": Color.blue,
            "Learning": Color.orange,
            "Review": Color.green
        ])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .frame(height: 180)
    }
}

// MARK: - Forecast bar chart (next 30 days)

struct ForecastChart: View {
    let forecast: [ForecastDay]

    var body: some View {
        Chart(forecast) { day in
            BarMark(
                x: .value("Date", day.date, unit: .day),
                y: .value("Due", day.dueCount)
            )
            .foregroundStyle(Color.accentColor.gradient)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .frame(height: 160)
    }
}

// MARK: - Card state pie / donut chart

struct CardStateChart: View {
    let stateCounts: [(state: String, count: Int)]

    private func color(for state: String) -> Color {
        switch state.lowercased() {
        case "new":        return .blue
        case "learning":   return .orange
        case "review":     return .green
        case "suspended":  return .gray
        case "buried":     return Color(.systemGray4)
        default:           return .secondary
        }
    }

    var body: some View {
        Chart(stateCounts, id: \.state) { entry in
            SectorMark(
                angle: .value("Count", entry.count),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(color(for: entry.state))
            .annotation(position: .overlay) {
                if entry.count > 0 {
                    Text("\(entry.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .chartLegend(position: .trailing, alignment: .center)
        .frame(height: 200)
    }
}

// MARK: - Ease factor histogram (SM-2)

struct EaseFactorChart: View {
    let bins: [HistogramBin]

    var body: some View {
        Chart(bins) { bin in
            BarMark(
                x: .value("Ease", bin.label),
                y: .value("Cards", bin.count)
            )
            .foregroundStyle(Color.teal.gradient)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 160)
    }
}

// MARK: - Interval distribution histogram

struct IntervalChart: View {
    let bins: [HistogramBin]

    var body: some View {
        Chart(bins) { bin in
            BarMark(
                x: .value("Interval", bin.label),
                y: .value("Cards", bin.count)
            )
            .foregroundStyle(Color.indigo.gradient)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 160)
    }
}

// MARK: - FSRS stability histogram

struct StabilityChart: View {
    let bins: [HistogramBin]

    var body: some View {
        Chart(bins) { bin in
            BarMark(
                x: .value("Stability", bin.label),
                y: .value("Cards", bin.count)
            )
            .foregroundStyle(Color.purple.gradient)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 160)
    }
}

// MARK: - True retention curve (FSRS theoretical)

struct RetentionCurveChart: View {
    let points: [RetentionPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Days", point.days),
                y: .value("Retention", point.retention)
            )
            .foregroundStyle(by: .value("Stability", point.seriesLabel))
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(format: FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0)))
        }
        .chartXAxis {
            AxisMarks(values: [0, 7, 14, 21, 28]) { _ in
                AxisValueLabel()
            }
        }
        .frame(height: 200)
    }
}
