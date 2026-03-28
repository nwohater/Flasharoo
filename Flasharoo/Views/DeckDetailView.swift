//
//  DeckDetailView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let deck: Deck

    @State private var showingNewCard = false
    @State private var showingStats = false
    @State private var showingCram = false
    @State private var showingDeleteConfirm = false
    @State private var showingAIExpand = false
    @Environment(AISettings.self) private var aiSettings

    private var activeCards: [Card] { deck.cards.filter { $0.deletedAt == nil } }
    private var dueCount: Int {
        let now = Date()
        return activeCards.filter {
            $0.dueDate <= now && $0.state != .suspended && $0.state != .buried
        }.count
    }
    private var newCount: Int  { activeCards.filter { $0.state == .new }.count }
    private var totalCount: Int { activeCards.count }

    var body: some View {
        List {
            Section {
                statsRow(label: "Due today",  value: "\(dueCount)",  icon: "clock.badge.exclamationmark", color: dueCount > 0 ? .orange : .secondary)
                statsRow(label: "New",        value: "\(newCount)",  icon: "sparkles",                    color: .blue)
                statsRow(label: "Total cards", value: "\(totalCount)", icon: "rectangle.stack",           color: .secondary)
            } header: {
                Text("Overview")
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    StudyView(deck: deck, modelContext: modelContext)
                } label: {
                    Label("Study", systemImage: "play.fill")
                }
                .disabled(dueCount == 0)
            }
            if totalCount > 0 {
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink {
                        StudyView(deck: deck, modelContext: modelContext, cramMode: true)
                    } label: {
                        Label("Study All", systemImage: "rectangle.stack.fill")
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingNewCard = true
                } label: {
                    Label("New Card", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingStats = true
                } label: {
                    Label("Statistics", systemImage: "chart.bar.xaxis")
                }
            }
            if deck.aiPrompt != nil && aiSettings.isConfigured {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showingAIExpand = true
                    } label: {
                        Label("Add AI Cards", systemImage: "wand.and.stars")
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete Deck", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingNewCard) {
            CardEditorView(deck: deck)
        }
        .sheet(isPresented: $showingAIExpand) {
            AIExpandDeckSheet(deck: deck)
                .environment(aiSettings)
        }
        .confirmationDialog(
            "Delete \"\(deck.name)\"?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Deck & All Cards", role: .destructive) {
                let now = Date()
                deck.cards.forEach { $0.deletedAt = now }
                deck.deletedAt = now
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(totalCount) card\(totalCount == 1 ? "" : "s"). This cannot be undone.")
        }
        .sheet(isPresented: $showingStats) {
            NavigationStack {
                StatsView(title: "\(deck.name) Stats", deckID: deck.id)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingStats = false }
                        }
                    }
            }
        }
    }

    private func statsRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(color)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
