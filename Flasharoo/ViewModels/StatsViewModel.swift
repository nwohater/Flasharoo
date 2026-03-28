//
//  StatsViewModel.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//

import SwiftUI
import SwiftData

@Observable
final class StatsViewModel {
    private(set) var data: StatsData?
    private(set) var isLoading = false

    private let actor: BackgroundDataActor

    init(container: ModelContainer) {
        self.actor = BackgroundDataActor(container: container)
    }

    func load(deckID: UUID? = nil) async {
        isLoading = true
        data = await actor.computeStats(deckID: deckID)
        isLoading = false
    }
}
