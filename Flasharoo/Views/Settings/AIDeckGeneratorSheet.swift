//
//  AIDeckGeneratorSheet.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Sheet that lets the user describe a topic, pick a card count, then
//  calls AIService to generate and save a new Deck with Cards.
//

import SwiftUI
import SwiftData

struct AIDeckGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AISettings.self) private var aiSettings

    @State private var topic = ""
    @State private var cardCount = 50
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    TextField("e.g. Flutter state management", text: $topic, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Card Count") {
                    Stepper("\(cardCount) cards", value: $cardCount, in: 10...200, step: 10)
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if let success = successMessage {
                    Section {
                        Label(success, systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 6)
                                Text("Generating...")
                            } else {
                                Label("Generate Deck", systemImage: "wand.and.stars")
                            }
                            Spacer()
                        }
                    }
                    .disabled(topic.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
                }
            }
            .navigationTitle("AI Deck Generator")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isGenerating)
                }
            }
        }
    }

    // MARK: - Generation

    private func generate() async {
        let trimmed = topic.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isGenerating   = true
        errorMessage   = nil
        successMessage = nil

        let service = AIService(settings: aiSettings)
        do {
            let cards = try await service.generateDeck(topic: trimmed, cardCount: cardCount)
            await MainActor.run { insertDeck(name: trimmed, cards: cards) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    @MainActor
    private func insertDeck(name: String, cards: [AICardData]) {
        // Fetch existing decks to compute sortIndex
        let descriptor = FetchDescriptor<Deck>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let sortIndex = existing.filter { $0.deletedAt == nil }.count

        let deck = Deck(name: name, sortIndex: sortIndex)
        modelContext.insert(deck)

        for cardData in cards {
            let card = Card(
                deckID: deck.id,
                front: escapeHTML(cardData.front),
                back: escapeHTML(cardData.back),
                tags: cardData.tags.joined(separator: " ")
            )
            card.deck = deck
            modelContext.insert(card)
        }

        try? modelContext.save()
        successMessage = "Created \"\(name)\" with \(cards.count) cards."
        topic = ""
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
