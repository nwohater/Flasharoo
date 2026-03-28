//
//  GestureCustomizationView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Edit the global GestureSettings — tap zones and swipe directions.
//

import SwiftUI
import SwiftData

struct GestureCustomizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGestureSettings: [GestureSettings]

    private var global: GestureSettings {
        allGestureSettings.first(where: { $0.deckID == nil })
            ?? GestureSettings.fetchOrCreateGlobal(in: modelContext)
    }

    var body: some View {
        Form {
            tapZoneSection
            swipeSection
        }
        .navigationTitle("Gestures")
    }

    // MARK: - Tap zones

    private var tapZoneSection: some View {
        Section("Tap Zones") {
            VStack(spacing: 4) {
                tapRow(left: \.tapZoneTopLeft, center: \.tapZoneTopCenter, right: \.tapZoneTopRight,
                       label: "Top")
                tapRow(left: \.tapZoneMiddleLeft, center: \.tapZoneMiddleCenter, right: \.tapZoneMiddleRight,
                       label: "Middle")
                tapRow(left: \.tapZoneBottomLeft, center: \.tapZoneBottomCenter, right: \.tapZoneBottomRight,
                       label: "Bottom")
            }
        }
    }

    @ViewBuilder
    private func tapRow(
        left: ReferenceWritableKeyPath<GestureSettings, StudyAction>,
        center: ReferenceWritableKeyPath<GestureSettings, StudyAction>,
        right: ReferenceWritableKeyPath<GestureSettings, StudyAction>,
        label: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)
            ActionPicker(action: Binding(get: { global[keyPath: left] }, set: { global[keyPath: left] = $0; save() }))
            ActionPicker(action: Binding(get: { global[keyPath: center] }, set: { global[keyPath: center] = $0; save() }))
            ActionPicker(action: Binding(get: { global[keyPath: right] }, set: { global[keyPath: right] = $0; save() }))
        }
    }

    // MARK: - Swipes

    private var swipeSection: some View {
        Section("Swipe Gestures") {
            ForEach([
                ("Swipe Left",  \GestureSettings.swipeLeft),
                ("Swipe Right", \GestureSettings.swipeRight),
                ("Swipe Up",    \GestureSettings.swipeUp),
                ("Swipe Down",  \GestureSettings.swipeDown)
            ], id: \.0) { label, kp in
                Picker(label, selection: Binding(
                    get: { global[keyPath: kp] },
                    set: { global[keyPath: kp] = $0; save() }
                )) {
                    ForEach(StudyAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func save() {
        try? modelContext.save()
    }
}

// MARK: - Small action picker cell

private struct ActionPicker: View {
    @Binding var action: StudyAction

    var body: some View {
        Menu {
            ForEach(StudyAction.allCases, id: \.self) { a in
                Button(a.displayName) { action = a }
            }
        } label: {
            Text(action.displayName)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(6)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - GestureSettings convenience

extension GestureSettings {
    @discardableResult
    static func fetchOrCreateGlobal(in context: ModelContext) -> GestureSettings {
        let descriptor = FetchDescriptor<GestureSettings>(
            predicate: #Predicate { $0.deckID == nil }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let gs = GestureSettings()
        context.insert(gs)
        return gs
    }
}

// MARK: - StudyAction display names

extension StudyAction {
    var displayName: String {
        switch self {
        case .none:             return "None"
        case .showAnswer:       return "Show Answer"
        case .rateAgain:        return "Again"
        case .rateHard:         return "Hard"
        case .rateGood:         return "Good"
        case .rateEasy:         return "Easy"
        case .editCard:         return "Edit Card"
        case .flagCard:         return "Flag"
        case .skipCard:         return "Skip"
        case .undoLastRating:   return "Undo"
        case .playAudio:        return "Play Audio"
        case .openDeckStats:    return "Deck Stats"
        case .toggleAutoplay:   return "Toggle Autoplay"
        }
    }
}
