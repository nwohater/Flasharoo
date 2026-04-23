//
//  FilteredDeckDetailView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//

import SwiftUI
import SwiftData

struct FilteredDeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let filteredDeck: FilteredDeck

    @State private var cardIDs: [PersistentIdentifier] = []
    @State private var isLoading = true
    @State private var showingEditor = false
    @State private var searchVM: SearchViewModel?

    private var cardCount: Int { cardIDs.count }

    var body: some View {
        List {
            Section {
                infoRow(label: "Query", value: filteredDeck.queryString, monospaced: true)
                infoRow(label: "Sort", value: sortLabel)
                infoRow(label: "Mode", value: filteredDeck.rescheduleCards ? "Spaced repetition" : "Cram")
                if let limit = filteredDeck.limitCount {
                    infoRow(label: "Limit", value: "\(limit) cards")
                }
            } header: {
                Text("Settings")
            }

            Section {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Counting matching cards…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    infoRow(
                        label: "Matching cards",
                        value: "\(cardCount)",
                        icon: "rectangle.stack",
                        color: cardCount > 0 ? .blue : .secondary
                    )
                }
            } header: {
                Text("Results")
            }
        }
        .navigationTitle(filteredDeck.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    filteredDeckStudyView
                } label: {
                    Label("Study", systemImage: "play.fill")
                }
                .disabled(cardCount == 0 || isLoading)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showingEditor = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            FilteredDeckEditorSheet(existing: filteredDeck)
        }
        .task {
            await loadCards()
        }
        .onChange(of: filteredDeck.queryString) {
            Task { await loadCards() }
        }
    }

    @ViewBuilder
    private var filteredDeckStudyView: some View {
        if let vm = searchVM {
            _FilteredDeckStudyLauncher(filteredDeck: filteredDeck, searchVM: vm)
        } else {
            ProgressView("Loading…")
        }
    }

    private func loadCards() async {
        isLoading = true
        if searchVM == nil {
            searchVM = SearchViewModel(container: modelContext.container)
        }
        if let vm = searchVM {
            cardIDs = await vm.fetchStudyCards(for: filteredDeck)
        }
        isLoading = false
    }

    private var sortLabel: String {
        switch filteredDeck.sortOrder {
        case .dueDate:      return "Due date"
        case .createdDate:  return "Created"
        case .modifiedDate: return "Modified"
        case .random:       return "Random"
        }
    }

    private func infoRow(
        label: String,
        value: String,
        icon: String? = nil,
        color: Color = .primary,
        monospaced: Bool = false
    ) -> some View {
        HStack {
            if let icon {
                Label(label, systemImage: icon).foregroundStyle(color)
            } else {
                Text(label).foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .monospaced(monospaced)
                .multilineTextAlignment(.trailing)
        }
    }
}

// Launches StudyView with pre-fetched cards from the filtered deck.
private struct _FilteredDeckStudyLauncher: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [UserSettings]
    let filteredDeck: FilteredDeck
    let searchVM: SearchViewModel

    @State private var cards: [Card] = []
    @State private var isLoading = true

    private var defaultAlgorithm: SchedulerAlgorithm {
        allSettings.first?.defaultAlgorithm ?? .fsrs
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Building queue…")
            } else {
                StudyView(
                    cards: cards,
                    name: filteredDeck.name,
                    algorithm: defaultAlgorithm,
                    rescheduleCards: filteredDeck.rescheduleCards,
                    modelContext: modelContext
                )
            }
        }
        .task {
            let ids = await searchVM.fetchStudyCards(for: filteredDeck)
            let fetched = ids.compactMap { modelContext.model(for: $0) as? Card }
            cards = fetched
            isLoading = false
        }
    }
}
