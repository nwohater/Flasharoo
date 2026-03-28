//
//  StudyView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI
import SwiftData

struct StudyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: StudyViewModel
    @State private var showingEditor = false

    init(deck: Deck, modelContext: ModelContext) {
        _vm = State(initialValue: StudyViewModel(deck: deck, modelContext: modelContext))
    }

    init(
        cards: [Card],
        name: String,
        algorithm: SchedulerAlgorithm = .fsrs,
        rescheduleCards: Bool,
        modelContext: ModelContext
    ) {
        _vm = State(initialValue: StudyViewModel(
            cards: cards,
            name: name,
            algorithm: algorithm,
            rescheduleCards: rescheduleCards,
            modelContext: modelContext
        ))
    }

    var body: some View {
        Group {
            if vm.isSessionComplete {
                SessionSummaryView(stats: vm.stats, sourceName: vm.source.displayName) {
                    dismiss()
                }
            } else if vm.currentCard != nil {
                studyContent
            } else {
                ProgressView("Building queue…")
            }
        }
        .navigationTitle(vm.source.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { studyToolbar }
        .task { vm.buildQueue() }
        .sheet(isPresented: $showingEditor) {
            if let card = vm.currentCard,
               let deck = card.deck ?? vm.source.deckIfPresent {
                CardEditorView(deck: deck, card: card)
            }
        }
        // Keyboard shortcuts
        .onKeyPress(.space) {
            vm.isAnswerRevealed ? vm.rate(3) : vm.revealAnswer()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "1234"), phases: .down) { press in
            if let n = Int(press.characters) { vm.rate(n) }
            return .handled
        }
    }

    // MARK: - Study content

    private var studyContent: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal)
                .padding(.top, 4)

            ZStack {
                if let card = vm.currentCard {
                    CardFlipView(card: card, isRevealed: vm.isAnswerRevealed)

                    if !vm.isAnswerRevealed {
                        TapZoneView { action in
                            dispatch(action)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(swipeGesture)

            if vm.isAnswerRevealed {
                RatingButtonsView(hints: vm.intervalHints) { rating in
                    vm.rate(rating)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: vm.isAnswerRevealed)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack {
            Text("\(vm.remainingCount) remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Swipe gesture (default mapping per PRD §4.3)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    dispatch(dx < 0 ? .rateAgain : .rateEasy)
                } else {
                    dispatch(dy < 0 ? .showAnswer : .skipCard)
                }
            }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var studyToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                vm.undoLastRating()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }

            Button {
                vm.toggleFlag()
            } label: {
                let flagged = vm.currentCard?.flag != .none
                Label("Flag", systemImage: flagged ? "flag.fill" : "flag")
                    .foregroundStyle(flagged ? Color.red : Color.primary)
            }

            Button {
                vm.skip()
            } label: {
                Label("Skip", systemImage: "forward")
            }
        }
    }

    // MARK: - Action dispatch

    private func dispatch(_ action: StudyAction) {
        switch action {
        case .showAnswer:     vm.revealAnswer()
        case .rateAgain:      vm.rate(1)
        case .rateHard:       vm.rate(2)
        case .rateGood:       vm.rate(3)
        case .rateEasy:       vm.rate(4)
        case .skipCard:       vm.skip()
        case .undoLastRating: vm.undoLastRating()
        case .flagCard:       vm.toggleFlag()
        case .editCard:       showingEditor = true
        case .none, .playAudio, .openDeckStats, .toggleAutoplay: break
        }
    }
}
