//
//  AIExpandDeckSheet.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Generates additional cards for an existing AI deck using the saved prompt.
//

import SwiftUI
import SwiftData

struct AIExpandDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AISettings.self) private var aiSettings

    let deck: Deck

    @State private var instructions: String
    @State private var cardCount = 10
    @State private var isGenerating = false
    @State private var generatedCount = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?

    init(deck: Deck) {
        self.deck = deck
        _instructions = State(initialValue: deck.aiPrompt ?? "")
    }

    private var canGenerate: Bool {
        !instructions.trimmingCharacters(in: .whitespaces).isEmpty && !isGenerating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Instructions", text: $instructions, axis: .vertical)
                        .lineLimit(4...8)
                } header: {
                    Text("Instructions")
                } footer: {
                    Text("Edit or refine the prompt before adding more cards.")
                }

                Section {
                    Stepper("\(cardCount) cards", value: $cardCount, in: 5...50, step: 5)
                } header: {
                    Text("Cards to Add")
                } footer: {
                    Text("Will be added to \"\(deck.name)\" — currently \(deck.cards.filter { $0.deletedAt == nil }.count) cards.")
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
                                VStack(spacing: 6) {
                                    ProgressView(value: Double(generatedCount), total: Double(cardCount))
                                        .progressViewStyle(.linear)
                                        .frame(maxWidth: 200)
                                    Text("\(generatedCount) of \(cardCount) cards")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Label("Add Cards", systemImage: "wand.and.stars")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canGenerate)
                }
            }
            .navigationTitle("Add AI Cards")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(successMessage != nil ? "Done" : "Cancel") { dismiss() }
                        .disabled(isGenerating)
                }
            }
        }
    }

    // MARK: - Generation

    private func generate() async {
        let prompt = instructions.trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return }

        isGenerating   = true
        generatedCount = 0
        errorMessage   = nil
        successMessage = nil

        let existingFronts = deck.cards
            .filter { $0.deletedAt == nil }
            .map { $0.front }

        let service = AIService(settings: aiSettings)
        do {
            let cards = try await service.generateDeck(
                topic: prompt,
                cardCount: cardCount,
                existingFronts: existingFronts,
                onProgress: { completed, _ in
                    Task { @MainActor in generatedCount = completed }
                }
            )
            await MainActor.run { appendCards(cards, prompt: prompt) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    @MainActor
    private func appendCards(_ cards: [AICardData], prompt: String) {
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
        // Update saved prompt in case user refined it
        deck.aiPrompt = prompt
        try? modelContext.save()
        successMessage = "Added \(cards.count) card\(cards.count == 1 ? "" : "s") to \"\(deck.name)\"."
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
