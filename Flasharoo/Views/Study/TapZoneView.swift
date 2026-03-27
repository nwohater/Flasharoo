//
//  TapZoneView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Transparent 3×3 tap-zone overlay. Each zone dispatches a StudyAction.
//  Default mapping matches PRD §4.3.
//

import SwiftUI

struct TapZoneView: View {
    let onAction: (StudyAction) -> Void

    /// Default 3×3 zone mapping (row-major, top-left → bottom-right).
    /// Index: row * 3 + col
    var zoneActions: [StudyAction] = [
        .none,       .showAnswer, .none,
        .none,       .showAnswer, .none,
        .rateAgain,  .rateGood,   .rateEasy
    ]

    var body: some View {
        GeometryReader { geo in
            let cols = 3
            let rows = 3
            let cellW = geo.size.width  / CGFloat(cols)
            let cellH = geo.size.height / CGFloat(rows)

            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<cols, id: \.self) { col in
                    let idx    = row * cols + col
                    let action = zoneActions[idx]

                    Color.clear
                        .frame(width: cellW, height: cellH)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if action != .none { onAction(action) }
                        }
                        .position(
                            x: cellW * CGFloat(col) + cellW / 2,
                            y: cellH * CGFloat(row) + cellH / 2
                        )
                }
            }
        }
    }
}
