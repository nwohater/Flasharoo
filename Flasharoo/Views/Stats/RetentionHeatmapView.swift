//
//  RetentionHeatmapView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  GitHub-style heatmap — one 12×12pt cell per day, last 365 days.
//  Color ramp: no reviews → systemGray5, max reviews → systemBlue.
//  Tap any cell to see a popover with date, review count, and retention.
//

import SwiftUI

struct RetentionHeatmapView: View {
    let summaries: [DailyReviewSummary]  // 365 entries, oldest first

    private let cellSize: CGFloat = 12
    private let gap: CGFloat = 2
    private var step: CGFloat { cellSize + gap }
    private let weeks = 53
    private let days  = 7

    @State private var selectedSummary: DailyReviewSummary?
    @State private var popoverAnchor: CGPoint = .zero

    private var maxCount: Int {
        summaries.map { $0.totalCount }.max() ?? 1
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Canvas { context, size in
                drawCells(context: context)
            }
            .frame(
                width: CGFloat(weeks) * step,
                height: CGFloat(days) * step + 20   // +20 for month labels
            )
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(at: value.location)
                    }
            )
            .popover(item: $selectedSummary) { summary in
                HeatmapPopover(summary: summary)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    // MARK: - Drawing

    private func drawCells(context: GraphicsContext) {
        let labelHeight: CGFloat = 16
        let max = max(maxCount, 1)

        for (index, summary) in summaries.enumerated() {
            let col = index / 7
            let row = index % 7
            let x = CGFloat(col) * step
            let y = CGFloat(row) * step + labelHeight
            let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
            let path = Path(roundedRect: rect, cornerRadius: 2)
            let intensity = Double(summary.totalCount) / Double(max)
            let color = cellColor(intensity: intensity)
            context.fill(path, with: .color(color))
        }

        // Month labels — draw first day of each month
        var drawnMonths = Set<Int>()
        let calendar = Calendar.current
        for (index, summary) in summaries.enumerated() {
            let month = calendar.component(.month, from: summary.date)
            let col = index / 7
            guard !drawnMonths.contains(col), calendar.component(.day, from: summary.date) <= 7 else { continue }
            drawnMonths.insert(col)
            let x = CGFloat(col) * step
            let monthName = DateFormatter().shortMonthSymbols[month - 1]
            let text = context.resolve(Text(monthName).font(.system(size: 9)).foregroundStyle(Color.secondary))
            context.draw(text, at: CGPoint(x: x, y: 6), anchor: .leading)
        }
    }

    private func cellColor(intensity: Double) -> Color {
        if intensity <= 0 { return Color(.systemGray5) }
        return Color.blue.opacity(0.2 + intensity * 0.8)
    }

    // MARK: - Tap handling

    private func handleTap(at location: CGPoint) {
        let labelHeight: CGFloat = 16
        guard location.y >= labelHeight else { return }
        let col = Int(location.x / step)
        let row = Int((location.y - labelHeight) / step)
        let index = col * 7 + row
        guard index >= 0, index < summaries.count else { return }
        selectedSummary = summaries[index]
    }
}

// MARK: - Popover

private struct HeatmapPopover: View {
    let summary: DailyReviewSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.date, style: .date)
                .font(.headline)
            if summary.totalCount == 0 {
                Text("No reviews")
                    .foregroundStyle(.secondary)
            } else {
                Label("\(summary.totalCount) reviews", systemImage: "rectangle.stack")
                Label("\(Int(summary.retention * 100))% retention", systemImage: "brain.head.profile")
                HStack(spacing: 12) {
                    miniStat("New", count: summary.newCount, color: .blue)
                    miniStat("Learning", count: summary.learningCount, color: .orange)
                    miniStat("Review", count: summary.reviewCount, color: .green)
                }
            }
        }
        .font(.subheadline)
    }

    private func miniStat(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
