//
//  DeckListView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Deck.sortIndex), SortDescriptor(\Deck.name)])
    var decks: [Deck]
    @Query(sort: \FilteredDeck.createdAt)
    var allFilteredDecks: [FilteredDeck]

    @Binding var selectedDeck: Deck?
    @Binding var selectedFilteredDeck: FilteredDeck?

    @State private var showingNewDeck = false
    @State private var newDeckName = ""
    @State private var searchText = ""
    @State private var showingQueryBuilder = false
    @State private var showingNewFilteredDeck = false
    @State private var editingFilteredDeck: FilteredDeck?
    @State private var showingGlobalStats = false

    @State private var searchVM: SearchViewModel?

    private var activeDecks: [Deck] {
        decks.filter { $0.deletedAt == nil }
    }

    private var activeFilteredDecks: [FilteredDeck] {
        allFilteredDecks.filter { $0.deletedAt == nil }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Group {
            if isSearching, let vm = searchVM {
                SearchResultsView(vm: vm)
            } else {
                mainList
            }
        }
        .navigationTitle("Flasharoo")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search cards…")
        .onChange(of: searchText) { _, newValue in
            searchVM?.query = newValue
        }
        .toolbar { toolbarContent }
        .alert("New Deck", isPresented: $showingNewDeck, actions: newDeckAlertActions)
        .sheet(isPresented: $showingNewFilteredDeck) {
            FilteredDeckEditorSheet()
        }
        .sheet(item: $editingFilteredDeck) { fd in
            FilteredDeckEditorSheet(existing: fd)
        }
        .sheet(isPresented: $showingGlobalStats) {
            NavigationStack {
                StatsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingGlobalStats = false }
                        }
                    }
            }
        }
        .task {
            if searchVM == nil {
                searchVM = SearchViewModel(container: modelContext.container)
            }
        }
    }

    // MARK: - Main list

    private var mainList: some View {
        List(selection: $selectedDeck) {
            Section("Decks") {
                ForEach(activeDecks) { deck in
                    NavigationLink(value: deck) {
                        DeckRowView(deck: deck)
                    }
                }
            }

            if !activeFilteredDecks.isEmpty {
                Section("Filtered Decks") {
                    ForEach(activeFilteredDecks) { fd in
                        FilteredDeckRowView(filteredDeck: fd, isSelected: selectedFilteredDeck?.id == fd.id)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedFilteredDeck = fd }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    fd.deletedAt = Date()
                                    try? modelContext.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingFilteredDeck = fd
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingNewDeck = true } label: {
                Label("New Deck", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button { showingNewFilteredDeck = true } label: {
                Label("New Filtered Deck", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button { showingGlobalStats = true } label: {
                Label("Statistics", systemImage: "chart.bar.xaxis")
            }
        }
    }

    // MARK: - New deck alert

    @ViewBuilder
    private func newDeckAlertActions() -> some View {
        TextField("Deck name", text: $newDeckName)
        Button("Create") { createDeck() }
        Button("Cancel", role: .cancel) { newDeckName = "" }
    }

    private func createDeck() {
        guard !newDeckName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let deck = Deck(name: newDeckName.trimmingCharacters(in: .whitespaces), sortIndex: activeDecks.count)
        modelContext.insert(deck)
        selectedDeck = deck
        newDeckName = ""
    }
}

// MARK: - Deck Row

private struct DeckRowView: View {
    let deck: Deck

    private var activeCardCount: Int {
        deck.cards.filter { $0.deletedAt == nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(deck.name)
                .font(.headline)
            Text("\(activeCardCount) cards")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Filtered Deck Row

private struct FilteredDeckRowView: View {
    let filteredDeck: FilteredDeck
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(filteredDeck.name)
                    .font(.headline)
                Text(filteredDeck.queryString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .monospaced()
            }
            Spacer()
            if filteredDeck.rescheduleCards {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
