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

    private var newCount: Int   { activeCards.filter { $0.state == .new }.count }
    private var reviewCount: Int { activeCards.filter { $0.state == .review }.count }
    private var learnCount: Int  { activeCards.filter { $0.state == .learning }.count }
    private var suspCount: Int   { activeCards.filter { $0.state == .suspended }.count }
    private var totalCount: Int  { activeCards.count }

    private var algoLabel: String {
        deck.algorithmOverride.map { $0 == .fsrs ? "FSRS" : "SM-2" } ?? "Default"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Title block
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if deck.aiPrompt != nil {
                            Image(systemName: "wand.and.stars")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.paperAccent)
                        }
                        Text(algoLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.paperAccent)
                    }
                    if !deck.descriptionText.isEmpty {
                        Text(deck.descriptionText)
                            .font(.subheadline)
                            .foregroundStyle(Color.paperInkMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)

                // Stat tiles
                HStack(spacing: 8) {
                    statTile(label: "Due", value: "\(dueCount)", color: .paperAccent, highlighted: dueCount > 0)
                    statTile(label: "New", value: "\(newCount)", color: .stateNew, highlighted: false)
                    statTile(label: "Total", value: "\(totalCount)", color: .paperInkMid, highlighted: false)
                }
                .padding(.horizontal, 16)

                // Primary CTA
                VStack(spacing: 8) {
                    NavigationLink {
                        StudyView(deck: deck, modelContext: modelContext)
                    } label: {
                        HStack {
                            Text("Study now")
                                .font(.system(size: 17, weight: .semibold))
                            if dueCount > 0 {
                                Text("· \(dueCount)")
                                    .font(.system(size: 17, weight: .medium))
                                    .opacity(0.8)
                            }
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.paperAccent)
                                .shadow(color: .paperAccent.opacity(0.25), radius: 8, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(dueCount == 0)
                    .opacity(dueCount == 0 ? 0.5 : 1)

                    HStack(spacing: 8) {
                        Button {
                            showingNewCard = true
                        } label: {
                            Label("New card", systemImage: "plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.paperInk)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.adaptiveSecondaryBg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.paperInk.opacity(0.08), lineWidth: 0.5)
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        if totalCount > 0 {
                            NavigationLink {
                                StudyView(deck: deck, modelContext: modelContext, cramMode: true)
                            } label: {
                                Label("Study all", systemImage: "rectangle.stack.fill")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.paperInk)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.adaptiveSecondaryBg)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.paperInk.opacity(0.08), lineWidth: 0.5)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Card mix
                if totalCount > 0 {
                    sectionHeader("Card mix")
                        .padding(.top, 18)

                    cardMixSection
                        .padding(.horizontal, 16)
                }

                // Limits
                sectionHeader("Limits")
                    .padding(.top, 18)

                limitsSection
                    .padding(.horizontal, 16)

                Spacer(minLength: 32)
            }
        }
        .background(Color.adaptiveGroupedBg)
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if deck.aiPrompt != nil && aiSettings.isConfigured {
                        Button {
                            showingAIExpand = true
                        } label: {
                            Label("Add AI Cards", systemImage: "wand.and.stars")
                        }
                    }
                    Button {
                        showingStats = true
                    } label: {
                        Label("Statistics", systemImage: "chart.bar.xaxis")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Deck", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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

    // MARK: - Stat tile

    private func statTile(label: String, value: String, color: Color, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.3)
                .foregroundStyle(Color.paperInkMuted)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.adaptiveSecondaryBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(highlighted ? color : Color.paperInk.opacity(0.08),
                                lineWidth: highlighted ? 1.5 : 0.5)
                )
        )
    }

    // MARK: - Card mix

    private var cardMixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Stacked progress bar
            GeometryReader { geo in
                HStack(spacing: 0) {
                    if reviewCount > 0 {
                        Color.stateReview
                            .frame(width: geo.size.width * CGFloat(reviewCount) / CGFloat(totalCount))
                    }
                    if learnCount > 0 {
                        Color.stateLearn
                            .frame(width: geo.size.width * CGFloat(learnCount) / CGFloat(totalCount))
                    }
                    if newCount > 0 {
                        Color.stateNew
                            .frame(width: geo.size.width * CGFloat(newCount) / CGFloat(totalCount))
                    }
                    if suspCount > 0 {
                        Color.stateSusp.opacity(0.4)
                            .frame(width: geo.size.width * CGFloat(suspCount) / CGFloat(totalCount))
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())
            }
            .frame(height: 10)

            HStack {
                legendItem(color: .stateReview, label: "Review", count: reviewCount)
                Spacer()
                legendItem(color: .stateLearn, label: "Learn", count: learnCount)
                Spacer()
                legendItem(color: .stateNew, label: "New", count: newCount)
                Spacer()
                legendItem(color: .stateSusp.opacity(0.7), label: "Susp.", count: suspCount)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.adaptiveSecondaryBg)
        )
    }

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.paperInkMid)
            Text("\(count)")
                .font(.system(size: 12))
                .foregroundStyle(Color.paperInkMuted)
                .monospacedDigit()
        }
    }

    // MARK: - Limits

    private var limitsSection: some View {
        VStack(spacing: 0) {
            limitRow(label: "New cards / day", value: "\(deck.newCardsPerDay)", last: false)
            limitRow(label: "Reviews / day", value: "\(deck.maxReviewsPerDay)", last: false)
            limitRow(label: "Algorithm", value: algoLabel, last: true)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.adaptiveSecondaryBg)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func limitRow(label: String, value: String, last: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.paperInk)
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .foregroundStyle(Color.paperInkMuted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.paperInk.opacity(0.25))
            }
            .font(.system(size: 14))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle()
                    .fill(Color.paperInk.opacity(0.08))
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12.5, weight: .semibold))
            .textCase(.uppercase)
            .kerning(0.3)
            .foregroundStyle(Color.paperInkMuted)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }
}
