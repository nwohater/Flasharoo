//
//  GestureSettings.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData

/// Per-deck or global gesture configuration.
/// deckID == nil means this is the global default.
/// Per-deck settings inherit from global for any unset values.
@Model
final class GestureSettings {
    @Attribute(.unique) var id: UUID
    var deckID: UUID?

    // 3×3 tap zone grid
    var tapZoneTopLeft: StudyAction
    var tapZoneTopCenter: StudyAction
    var tapZoneTopRight: StudyAction
    var tapZoneMiddleLeft: StudyAction
    var tapZoneMiddleCenter: StudyAction
    var tapZoneMiddleRight: StudyAction
    var tapZoneBottomLeft: StudyAction
    var tapZoneBottomCenter: StudyAction
    var tapZoneBottomRight: StudyAction

    // Swipe directions
    var swipeLeft: StudyAction
    var swipeRight: StudyAction
    var swipeUp: StudyAction
    var swipeDown: StudyAction

    // JSON-encoded [StudyAction], max 6 items
    var toolbarActionsJSON: String

    var toolbarActions: [StudyAction] {
        get {
            guard let data = toolbarActionsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([StudyAction].self, from: data)
            else { return GestureSettings.defaultToolbarActions }
            return decoded
        }
        set {
            let clamped = Array(newValue.prefix(6))
            if let data = try? JSONEncoder().encode(clamped),
               let str = String(data: data, encoding: .utf8) {
                toolbarActionsJSON = str
            }
        }
    }

    static let defaultToolbarActions: [StudyAction] = [
        .undoLastRating, .flagCard, .editCard, .playAudio, .openDeckStats, .skipCard
    ]

    init(
        id: UUID = UUID(),
        deckID: UUID? = nil,
        tapZoneTopLeft: StudyAction = .none,
        tapZoneTopCenter: StudyAction = .showAnswer,
        tapZoneTopRight: StudyAction = .none,
        tapZoneMiddleLeft: StudyAction = .none,
        tapZoneMiddleCenter: StudyAction = .showAnswer,
        tapZoneMiddleRight: StudyAction = .none,
        tapZoneBottomLeft: StudyAction = .rateAgain,
        tapZoneBottomCenter: StudyAction = .rateGood,
        tapZoneBottomRight: StudyAction = .rateEasy,
        swipeLeft: StudyAction = .rateAgain,
        swipeRight: StudyAction = .rateEasy,
        swipeUp: StudyAction = .showAnswer,
        swipeDown: StudyAction = .skipCard,
        toolbarActions: [StudyAction] = GestureSettings.defaultToolbarActions
    ) {
        self.id = id
        self.deckID = deckID
        self.tapZoneTopLeft = tapZoneTopLeft
        self.tapZoneTopCenter = tapZoneTopCenter
        self.tapZoneTopRight = tapZoneTopRight
        self.tapZoneMiddleLeft = tapZoneMiddleLeft
        self.tapZoneMiddleCenter = tapZoneMiddleCenter
        self.tapZoneMiddleRight = tapZoneMiddleRight
        self.tapZoneBottomLeft = tapZoneBottomLeft
        self.tapZoneBottomCenter = tapZoneBottomCenter
        self.tapZoneBottomRight = tapZoneBottomRight
        self.swipeLeft = swipeLeft
        self.swipeRight = swipeRight
        self.swipeUp = swipeUp
        self.swipeDown = swipeDown

        let clamped = Array(toolbarActions.prefix(6))
        if let data = try? JSONEncoder().encode(clamped),
           let str = String(data: data, encoding: .utf8) {
            self.toolbarActionsJSON = str
        } else {
            self.toolbarActionsJSON = "[]"
        }
    }

    /// Returns the action for a given tap zone.
    func action(for zone: TapZone) -> StudyAction {
        switch zone {
        case .topLeft:      return tapZoneTopLeft
        case .topCenter:    return tapZoneTopCenter
        case .topRight:     return tapZoneTopRight
        case .middleLeft:   return tapZoneMiddleLeft
        case .middleCenter: return tapZoneMiddleCenter
        case .middleRight:  return tapZoneMiddleRight
        case .bottomLeft:   return tapZoneBottomLeft
        case .bottomCenter: return tapZoneBottomCenter
        case .bottomRight:  return tapZoneBottomRight
        }
    }
}
