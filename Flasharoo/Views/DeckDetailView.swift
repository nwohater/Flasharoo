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
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingNewCard = true
                } label: {
                    Label("New Card", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewCard) {
            CardEditorView(deck: deck)
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
