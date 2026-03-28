//
//  QueryBuilderSheet.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Dropdown/picker UI that builds a query string for the search system.
//

import SwiftUI
import SwiftData

struct QueryBuilderSheet: View {
    @Binding var query: String
    @Environment(\.dismiss) private var dismiss

    // Pickers
    @State private var selectedState: CardState? = nil
    @State private var selectedFlag: CardFlag? = nil
    @State private var hasImage = false
    @State private var hasAudio = false
    @State private var hasDrawing = false
    @State private var selectedDue: DueFilter? = nil
    @State private var selectedCreated: CreatedFilter? = nil
    @State private var tagText: String = ""
    @State private var frontText: String = ""
    @State private var backText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Card State") {
                    statePicker
                }
                Section("Flag") {
                    flagPicker
                }
                Section("Has Attachment") {
                    Toggle("Image", isOn: $hasImage)
                    Toggle("Audio", isOn: $hasAudio)
                    Toggle("Drawing", isOn: $hasDrawing)
                }
                Section("Due") {
                    duePicker
                }
                Section("Created") {
                    createdPicker
                }
                Section("Content") {
                    TextField("Tag contains…", text: $tagText)
                    TextField("Front contains…", text: $frontText)
                    TextField("Back contains…", text: $backText)
                }

                Section {
                    Text("Preview: \(buildQuery())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }
            .navigationTitle("Query Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        query = buildQuery()
                        dismiss()
                    }
                    .disabled(buildQuery().isEmpty)
                }
            }
        }
    }

    // MARK: - Pickers

    private var statePicker: some View {
        Picker("State", selection: $selectedState) {
            Text("Any").tag(Optional<CardState>.none)
            ForEach(CardState.allCases, id: \.self) { state in
                Text(state.rawValue.capitalized).tag(Optional(state))
            }
        }
    }

    private var flagPicker: some View {
        Picker("Flag", selection: $selectedFlag) {
            Text("Any").tag(Optional<CardFlag>.none)
            ForEach(CardFlag.allCases, id: \.self) { flag in
                Text(flag.rawValue.capitalized).tag(Optional(flag))
            }
        }
    }

    private var duePicker: some View {
        Picker("Due", selection: $selectedDue) {
            Text("Any").tag(Optional<DueFilter>.none)
            Text("Today").tag(Optional(DueFilter.today))
            Text("Overdue").tag(Optional(DueFilter.overdue))
            Text("This week").tag(Optional(DueFilter.week))
        }
    }

    private var createdPicker: some View {
        Picker("Created", selection: $selectedCreated) {
            Text("Any").tag(Optional<CreatedFilter>.none)
            Text("Today").tag(Optional(CreatedFilter.today))
            Text("This week").tag(Optional(CreatedFilter.week))
        }
    }

    // MARK: - Query builder

    private func buildQuery() -> String {
        var parts: [String] = []

        if let state = selectedState   { parts.append("state:\(state.rawValue)") }
        if let flag  = selectedFlag    { parts.append("flag:\(flag.rawValue)") }
        if hasImage                    { parts.append("has:image") }
        if hasAudio                    { parts.append("has:audio") }
        if hasDrawing                  { parts.append("has:drawing") }
        if let due  = selectedDue      { parts.append("due:\(due.rawValue)") }
        if let cr   = selectedCreated  { parts.append("created:\(cr.rawValue)") }

        let tag = tagText.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty { parts.append("tag:\(tag)") }

        let front = frontText.trimmingCharacters(in: .whitespaces)
        if !front.isEmpty { parts.append("front:\(front)") }

        let back = backText.trimmingCharacters(in: .whitespaces)
        if !back.isEmpty { parts.append("back:\(back)") }

        return parts.joined(separator: " ")
    }
}
