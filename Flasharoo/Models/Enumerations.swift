//
//  Enumerations.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation

enum CardState: String, Codable, CaseIterable {
    case new, learning, review, suspended, buried
}

enum SchedulerAlgorithm: String, Codable, CaseIterable {
    case sm2, fsrs
}

enum NewCardOrder: String, Codable, CaseIterable {
    case inOrder, random
}

enum CardFlag: String, Codable, CaseIterable {
    case none, red, orange, green, blue
}

enum MediaType: String, Codable, CaseIterable {
    case image, audio, drawing
}

enum MediaSyncState: String, Codable, CaseIterable {
    case local, uploading, synced, downloadNeeded
}

enum FilteredDeckSort: String, Codable, CaseIterable {
    case dueDate, createdDate, modifiedDate, random
}

enum StudyAction: String, Codable, CaseIterable {
    case none
    case showAnswer
    case rateAgain, rateHard, rateGood, rateEasy
    case editCard, flagCard, skipCard, undoLastRating
    case playAudio, openDeckStats, toggleAutoplay
}

enum AppTheme: String, Codable, CaseIterable {
    case system, light, dark
}

enum TapZone: String, Codable, CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, middleCenter, middleRight
    case bottomLeft, bottomCenter, bottomRight
}
