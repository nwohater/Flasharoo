//
//  FilteredDeckEditorSheet.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Create or edit a FilteredDeck (saved search query).
//

import SwiftUI
import SwiftData

struct FilteredDeckEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Pass nil to create a new FilteredDeck.
    let existing: FilteredDeck?

    @State private var name: String
    @State private var queryString: String
    @State private var rescheduleCards: Bool
    @State private var limitEnabled: Bool
    @State private var limitCount: Int
    @State private var sortOrder: FilteredDeckSort
    @State private var showingQueryBuilder = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !queryString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(existing: FilteredDeck? = nil) {
        self.existing = existing
        _name            = State(initialValue: existing?.name ?? "")
        _queryString     = State(initialValue: existing?.queryString ?? "")
        _rescheduleCards = State(initialValue: existing?.rescheduleCards ?? true)
        _limitEnabled    = State(initialValue: existing?.limitCount != nil)
        _limitCount      = State(initialValue: existing?.limitCount ?? 100)
        _sortOrder       = State(initialValue: existing?.sortOrder ?? .dueDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Filtered deck name", text: $name)
                }

                Section("Query") {
                    TextField("e.g. tag:grammar state:review", text: $queryString)
                        .monospaced()
                    Button("Build query…") { showingQueryBuilder = true }
                }

                Section("Options") {
                    Picker("Sort by", selection: $sortOrder) {
                        Text("Due date").tag(FilteredDeckSort.dueDate)
                        Text("Created").tag(FilteredDeckSort.createdDate)
                        Text("Modified").tag(FilteredDeckSort.modifiedDate)
                        Text("Random").tag(FilteredDeckSort.random)
                    }
                    Toggle("Reschedule cards", isOn: $rescheduleCards)
                    Toggle("Limit card count", isOn: $limitEnabled)
                    if limitEnabled {
                        Stepper("Limit: \(limitCount)", value: $limitCount, in: 1...10000, step: 10)
                    }
                }

                Section {
                    Text("Reschedule: ratings affect the card's real due date. Disable for cram mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existing == nil ? "New Filtered Deck" : "Edit Filtered Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingQueryBuilder) {
                QueryBuilderSheet(query: $queryString)
            }
        }
    }

    private func save() {
        let limit = limitEnabled ? limitCount : nil
        if let existing {
            existing.name            = name.trimmingCharacters(in: .whitespaces)
            existing.queryString     = queryString.trimmingCharacters(in: .whitespaces)
            existing.rescheduleCards = rescheduleCards
            existing.limitCount      = limit
            existing.sortOrder       = sortOrder
        } else {
            let fd = FilteredDeck(
                name: name.trimmingCharacters(in: .whitespaces),
                queryString: queryString.trimmingCharacters(in: .whitespaces),
                rescheduleCards: rescheduleCards,
                limitCount: limit,
                sortOrder: sortOrder
            )
            modelContext.insert(fd)
        }
        try? modelContext.save()
        dismiss()
    }
}
