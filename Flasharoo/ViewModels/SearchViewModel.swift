//
//  SearchViewModel.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//

import SwiftUI
import SwiftData

@Observable
final class SearchViewModel {

    // MARK: - Search state

    var query: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var results: [CardSearchResult] = []
    private(set) var isSearching = false
    private(set) var hasMoreResults = false
    private(set) var suggestions: [String] = []

    private var currentPage = 0
    private let pageSize = 50
    private var searchTask: Task<Void, Never>?

    private let service: SearchService

    // MARK: - Init

    init(container: ModelContainer) {
        self.service = SearchService(container: container)
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        suggestions = []

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isSearching = false
            hasMoreResults = false
            return
        }

        isSearching = true
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            async let searchResults = service.search(query: query, page: 0, pageSize: pageSize)
            async let count = service.totalCount(query: query)
            async let completions = service.autocomplete(query: query)

            let (r, total, completionList) = await (searchResults, count, completions)
            guard !Task.isCancelled else { return }

            results = r
            currentPage = 0
            hasMoreResults = total > pageSize
            suggestions = completionList
            isSearching = false
        }
    }

    func loadNextPage() {
        guard hasMoreResults, !isSearching else { return }
        isSearching = true
        let nextPage = currentPage + 1
        let q = query

        Task { @MainActor in
            let more = await service.search(query: q, page: nextPage, pageSize: pageSize)
            guard !more.isEmpty else {
                hasMoreResults = false
                isSearching = false
                return
            }
            results.append(contentsOf: more)
            currentPage = nextPage
            hasMoreResults = more.count == pageSize
            isSearching = false
        }
    }

    func applySuggestion(_ suggestion: String) {
        var tokens = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if !tokens.isEmpty { tokens.removeLast() }
        tokens.append(suggestion)
        query = tokens.joined(separator: " ") + " "
        suggestions = []
    }

    // MARK: - FilteredDeck CRUD

    func createFilteredDeck(
        name: String,
        queryString: String,
        rescheduleCards: Bool,
        limitCount: Int?,
        sortOrder: FilteredDeckSort,
        context: ModelContext
    ) {
        let fd = FilteredDeck(
            name: name,
            queryString: queryString,
            rescheduleCards: rescheduleCards,
            limitCount: limitCount,
            sortOrder: sortOrder
        )
        context.insert(fd)
        try? context.save()
    }

    func update(
        _ filteredDeck: FilteredDeck,
        name: String,
        queryString: String,
        rescheduleCards: Bool,
        limitCount: Int?,
        sortOrder: FilteredDeckSort,
        context: ModelContext
    ) {
        filteredDeck.name = name
        filteredDeck.queryString = queryString
        filteredDeck.rescheduleCards = rescheduleCards
        filteredDeck.limitCount = limitCount
        filteredDeck.sortOrder = sortOrder
        try? context.save()
    }

    func delete(_ filteredDeck: FilteredDeck, context: ModelContext) {
        filteredDeck.deletedAt = Date()
        try? context.save()
    }

    // MARK: - Fetch cards for FilteredDeck study session

    func fetchStudyCards(for filteredDeck: FilteredDeck) async -> [PersistentIdentifier] {
        await service.fetchCards(
            query: filteredDeck.queryString,
            sortOrder: filteredDeck.sortOrder,
            limit: filteredDeck.limitCount
        )
    }
}
