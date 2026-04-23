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
    @Environment(AISettings.self) private var aiSettings
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
    @State private var showingSettings = false
    @State private var showingAIGenerator = false
    @State private var deckToDelete: Deck?

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

    private var totalDueCount: Int {
        let now = Date()
        return activeDecks.reduce(0) { sum, deck in
            sum + deck.cards.filter {
                $0.deletedAt == nil &&
                $0.dueDate <= now &&
                $0.state != .suspended &&
                $0.state != .buried
            }.count
        }
    }

    var body: some View {
        Group {
            if isSearching, let vm = searchVM {
                SearchResultsView(vm: vm)
            } else {
                mainList
            }
        }
        .navigationTitle("Decks")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search cards, tags, decks…")
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(aiSettings)
        }
        .sheet(isPresented: $showingAIGenerator) {
            AIDeckGeneratorSheet()
                .environment(aiSettings)
        }
        .alert("Delete Deck", isPresented: Binding(
            get: { deckToDelete != nil },
            set: { if !$0 { deckToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deck = deckToDelete {
                    deleteDeck(deck)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let deck = deckToDelete {
                Text("Delete \"\(deck.name)\" and all \(deck.cards.filter { $0.deletedAt == nil }.count) cards? This cannot be undone.")
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
            // Due summary chip
            if totalDueCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.paperAccent)
                        .font(.caption)
                    Text("\(totalDueCount) due today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.paperInkMid)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.bottom, 2)
            }

            Section("Decks") {
                ForEach(activeDecks) { deck in
                    NavigationLink(value: deck) {
                        DeckRowView(deck: deck)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deckToDelete = deck
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            if !activeFilteredDecks.isEmpty {
                Section("Filtered") {
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
                                .tint(.paperAccent)
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
        if aiSettings.isConfigured {
            ToolbarItem(placement: .secondaryAction) {
                Button { showingAIGenerator = true } label: {
                    Label("Generate with AI", systemImage: "wand.and.stars")
                }
            }
        }
        #if os(iOS)
        ToolbarItem(placement: .secondaryAction) {
            Button { showingSettings = true } label: {
                Label("Settings", systemImage: "gear")
            }
        }
        #endif
        ToolbarItem(placement: .status) {
            SyncStatusButton()
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

    private func deleteDeck(_ deck: Deck) {
        if selectedDeck?.id == deck.id { selectedDeck = nil }
        let now = Date()
        deck.cards.forEach { $0.deletedAt = now }
        deck.deletedAt = now
        try? modelContext.save()
        deckToDelete = nil
    }
}

// MARK: - Deck Row

private struct DeckRowView: View {
    let deck: Deck

    private var activeCards: [Card] { deck.cards.filter { $0.deletedAt == nil } }

    private var dueCount: Int {
        let now = Date()
        return activeCards.filter {
            $0.dueDate <= now && $0.state != .suspended && $0.state != .buried
        }.count
    }

    private var newCount: Int {
        activeCards.filter { $0.state == .new }.count
    }

    private var isDue: Bool { dueCount > 0 }

    private var isAI: Bool { deck.aiPrompt != nil }

    var body: some View {
        HStack(spacing: 12) {
            // Deck icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDue
                        ? LinearGradient(colors: [.paperAccent, Color(hex: "D9A25A")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.paperAccent.opacity(0.12), Color.paperAccent.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: isAI ? "wand.and.stars" : "rectangle.stack.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDue ? .white : .paperAccent)
            }
            .frame(width: 30, height: 30)

            // Name + subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(deck.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.paperInk)
                        .lineLimit(1)
                    if let algo = deck.algorithmOverride {
                        Text(algo == .fsrs ? "FSRS" : "SM-2")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.paperInkMuted)
                            .kerning(0.5)
                    }
                }
                HStack(spacing: 6) {
                    Text("\(activeCards.count) cards")
                    if newCount > 0 {
                        Text("·")
                            .foregroundStyle(Color.paperInkMuted.opacity(0.4))
                        Text("\(newCount) new")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.paperInkMuted)
            }

            Spacer()

            // Due badge
            if dueCount > 0 {
                Text("\(dueCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.paperAccent)
                    )
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Filtered Deck Row

private struct FilteredDeckRowView: View {
    let filteredDeck: FilteredDeck
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.stateNew.opacity(0.12))
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.stateNew)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(filteredDeck.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.paperInk)
                    if filteredDeck.rescheduleCards {
                        Text("CRAM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.ratingAgainBg)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.ratingAgainBg.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(filteredDeck.queryString)
                    .font(.system(size: 11.5).monospaced())
                    .foregroundStyle(Color.paperInkMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .background(isSelected ? Color.paperAccent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
