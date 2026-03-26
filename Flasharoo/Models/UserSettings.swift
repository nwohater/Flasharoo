//
//  UserSettings.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import Foundation
import SwiftData

/// Global user preferences. Syncs via CloudKit.
/// Device-specific preferences (notification state, local cache paths) stay in UserDefaults.
@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var defaultAlgorithm: SchedulerAlgorithm
    var showIntervalHints: Bool
    var autoplayAudio: Bool
    var dayStartHour: Int       // hour at which "today" resets, default 4 (4am)
    var theme: AppTheme

    init(
        id: UUID = UUID(),
        defaultAlgorithm: SchedulerAlgorithm = .fsrs,
        showIntervalHints: Bool = true,
        autoplayAudio: Bool = false,
        dayStartHour: Int = 4,
        theme: AppTheme = .system
    ) {
        self.id = id
        self.defaultAlgorithm = defaultAlgorithm
        self.showIntervalHints = showIntervalHints
        self.autoplayAudio = autoplayAudio
        self.dayStartHour = dayStartHour
        self.theme = theme
    }

    /// Fetches the singleton or inserts a new one with defaults.
    @discardableResult
    static func fetchOrCreate(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = UserSettings()
        context.insert(settings)
        return settings
    }
}
