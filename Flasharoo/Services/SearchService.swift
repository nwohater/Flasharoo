//
//  SearchService.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Query language: tag:, deck:, state:, flag:, has:, front:, back:, due:, created:, rated:
//  Prefix a term with - to negate it. Bare text searches front + back + tags.
//  Example: "tag:grammar -state:suspended has:image japanese"
//

import Foundation
import SwiftData

// MARK: - Result type

struct CardSearchResult: Identifiable, Sendable {
    let id: UUID
    let deckName: String
    let front: String          // HTML-stripped, truncated to 120 chars
    let back: String           // HTML-stripped, truncated to 120 chars
    let tags: [String]
    let state: CardState
    let dueDate: Date
    let flag: CardFlag
    let persistentID: PersistentIdentifier
}

// MARK: - Query AST

enum DueFilter: String {
    case today, overdue, week
}

enum CreatedFilter: String {
    case today, week
}

enum SearchTerm {
    case tag(String, negated: Bool)
    case inDeck(String, negated: Bool)
    case state(CardState, negated: Bool)
    case flag(CardFlag, negated: Bool)
    case hasMedia(MediaType, negated: Bool)
    case front(String, negated: Bool)
    case back(String, negated: Bool)
    case due(DueFilter, negated: Bool)
    case created(CreatedFilter, negated: Bool)
    case rated(Int, negated: Bool)
    case text(String, negated: Bool)
}

// MARK: - Service

actor SearchService: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor

    init(container: ModelContainer) {
        self.modelContainer = container
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    // MARK: - Search

    /// Returns up to `pageSize` matching cards, skipping the first `page * pageSize`.
    func search(
        query: String,
        page: Int = 0,
        pageSize: Int = 50
    ) -> [CardSearchResult] {
        let terms = parse(query)

        // Fetch all non-deleted decks for name lookup
        let deckDescriptor = FetchDescriptor<Deck>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let allDecks = (try? modelContext.fetch(deckDescriptor)) ?? []
        let decksByID = Dictionary(uniqueKeysWithValues: allDecks.map { ($0.id, $0) })

        // Base fetch: all non-deleted, non-suspended, non-buried cards
        var descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Card.dueDate)]
        )
        descriptor.propertiesToFetch = [
            \.id, \.deckID, \.front, \.back, \.tags,
            \.state, \.dueDate, \.flag, \.createdAt
        ]

        // If a deck: term is present (non-negated, single), narrow the fetch
        if let deckTerm = singleDeckID(terms: terms, decksByID: decksByID) {
            let id = deckTerm
            descriptor.predicate = #Predicate { $0.deckID == id && $0.deletedAt == nil }
        }

        let allCards = (try? modelContext.fetch(descriptor)) ?? []

        let matched = allCards.filter { matches(card: $0, terms: terms, decksByID: decksByID) }

        let start = page * pageSize
        guard start < matched.count else { return [] }
        let end = min(start + pageSize, matched.count)

        return matched[start..<end].map { card in
            let deckName = decksByID[card.deckID]?.name ?? "Unknown"
            return CardSearchResult(
                id: card.id,
                deckName: deckName,
                front: excerpt(stripHTML(card.front)),
                back: excerpt(stripHTML(card.back)),
                tags: card.tagList,
                state: card.state,
                dueDate: card.dueDate,
                flag: card.flag,
                persistentID: card.persistentModelID
            )
        }
    }

    func totalCount(query: String) -> Int {
        let terms = parse(query)
        let deckDescriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.deletedAt == nil })
        let allDecks = (try? modelContext.fetch(deckDescriptor)) ?? []
        let decksByID = Dictionary(uniqueKeysWithValues: allDecks.map { ($0.id, $0) })

        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.deletedAt == nil })
        let allCards = (try? modelContext.fetch(descriptor)) ?? []
        return allCards.filter { matches(card: $0, terms: terms, decksByID: decksByID) }.count
    }

    /// Fetch all cards matching a query (for building a FilteredDeck study queue).
    func fetchCards(query: String, sortOrder: FilteredDeckSort, limit: Int?) -> [PersistentIdentifier] {
        let terms = parse(query)
        let deckDescriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.deletedAt == nil })
        let allDecks = (try? modelContext.fetch(deckDescriptor)) ?? []
        let decksByID = Dictionary(uniqueKeysWithValues: allDecks.map { ($0.id, $0) })

        var descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.deletedAt == nil })
        switch sortOrder {
        case .dueDate:      descriptor.sortBy = [SortDescriptor(\Card.dueDate)]
        case .createdDate:  descriptor.sortBy = [SortDescriptor(\Card.createdAt)]
        case .modifiedDate: descriptor.sortBy = [SortDescriptor(\Card.modifiedAt)]
        case .random:       break
        }

        var cards = (try? modelContext.fetch(descriptor)) ?? []
        cards = cards.filter { matches(card: $0, terms: terms, decksByID: decksByID) }

        if sortOrder == .random { cards.shuffle() }
        if let limit { cards = Array(cards.prefix(limit)) }

        return cards.map { $0.persistentModelID }
    }

    // MARK: - Autocomplete

    /// Suggestions for the current (last) token being typed.
    func autocomplete(query: String) -> [String] {
        let tokens = query.components(separatedBy: .whitespaces)
        let lastToken = tokens.last ?? ""
        let negated = lastToken.hasPrefix("-")
        let raw = negated ? String(lastToken.dropFirst()) : lastToken
        let prefix = negated ? "-" : ""

        if raw.hasPrefix("tag:") {
            let valuePrefix = String(raw.dropFirst(4))
            return allTagValues()
                .filter { valuePrefix.isEmpty || $0.localizedCaseInsensitiveContains(valuePrefix) }
                .sorted()
                .prefix(10)
                .map { "\(prefix)tag:\($0)" }
        }

        if raw.hasPrefix("deck:") {
            let valuePrefix = String(raw.dropFirst(5))
            return allDeckNames()
                .filter { valuePrefix.isEmpty || $0.localizedCaseInsensitiveContains(valuePrefix) }
                .sorted()
                .prefix(10)
                .map { "\(prefix)deck:\($0)" }
        }

        if raw.hasPrefix("state:") {
            let valuePrefix = String(raw.dropFirst(6))
            return CardState.allCases
                .filter { valuePrefix.isEmpty || $0.rawValue.hasPrefix(valuePrefix) }
                .map { "\(prefix)state:\($0.rawValue)" }
        }

        if raw.hasPrefix("flag:") {
            let valuePrefix = String(raw.dropFirst(5))
            return CardFlag.allCases
                .filter { valuePrefix.isEmpty || $0.rawValue.hasPrefix(valuePrefix) }
                .map { "\(prefix)flag:\($0.rawValue)" }
        }

        if raw.hasPrefix("has:") {
            let valuePrefix = String(raw.dropFirst(4))
            let options = ["image", "audio", "drawing"]
            return options
                .filter { valuePrefix.isEmpty || $0.hasPrefix(valuePrefix) }
                .map { "\(prefix)has:\($0)" }
        }

        if raw.hasPrefix("due:") {
            let valuePrefix = String(raw.dropFirst(4))
            let options = ["today", "overdue", "week"]
            return options
                .filter { valuePrefix.isEmpty || $0.hasPrefix(valuePrefix) }
                .map { "\(prefix)due:\($0)" }
        }

        if raw.hasPrefix("created:") {
            let valuePrefix = String(raw.dropFirst(8))
            let options = ["today", "week"]
            return options
                .filter { valuePrefix.isEmpty || $0.hasPrefix(valuePrefix) }
                .map { "\(prefix)created:\($0)" }
        }

        // Suggest predicate keywords matching the raw prefix
        let keywords = [
            "tag:", "deck:", "state:", "flag:", "has:",
            "front:", "back:", "due:", "created:", "rated:"
        ]
        return keywords
            .filter { raw.isEmpty || $0.hasPrefix(raw.lowercased()) }
            .map { "\(prefix)\($0)" }
    }

    // MARK: - Parser

    func parse(_ query: String) -> [SearchTerm] {
        query
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .compactMap { parseToken($0) }
    }

    private func parseToken(_ token: String) -> SearchTerm? {
        let negated = token.hasPrefix("-")
        let raw = negated ? String(token.dropFirst()) : token
        guard !raw.isEmpty else { return nil }

        if let colon = raw.firstIndex(of: ":") {
            let key   = String(raw[..<colon]).lowercased()
            let value = String(raw[raw.index(after: colon)...]).lowercased()
            switch key {
            case "tag":     return .tag(value, negated: negated)
            case "deck":    return .inDeck(value, negated: negated)
            case "state":   return parseStateTerm(value, negated: negated)
            case "flag":    return parseFlagTerm(value, negated: negated)
            case "has":     return parseHasTerm(value, negated: negated)
            case "front":   return .front(value, negated: negated)
            case "back":    return .back(value, negated: negated)
            case "due":     return parseDueTerm(value, negated: negated)
            case "created": return parseCreatedTerm(value, negated: negated)
            case "rated":   return Int(value).map { .rated($0, negated: negated) }
            default:        break
            }
        }

        return .text(raw, negated: negated)
    }

    private func parseStateTerm(_ value: String, negated: Bool) -> SearchTerm? {
        switch value {
        case "new":        return .state(.new, negated: negated)
        case "learning":   return .state(.learning, negated: negated)
        case "review":     return .state(.review, negated: negated)
        case "suspended":  return .state(.suspended, negated: negated)
        case "buried":     return .state(.buried, negated: negated)
        default:           return nil
        }
    }

    private func parseFlagTerm(_ value: String, negated: Bool) -> SearchTerm? {
        switch value {
        case "none":    return .flag(.none, negated: negated)
        case "red":     return .flag(.red, negated: negated)
        case "orange":  return .flag(.orange, negated: negated)
        case "green":   return .flag(.green, negated: negated)
        case "blue":    return .flag(.blue, negated: negated)
        default:        return nil
        }
    }

    private func parseHasTerm(_ value: String, negated: Bool) -> SearchTerm? {
        switch value {
        case "image":    return .hasMedia(.image, negated: negated)
        case "audio":    return .hasMedia(.audio, negated: negated)
        case "drawing":  return .hasMedia(.drawing, negated: negated)
        default:         return nil
        }
    }

    private func parseDueTerm(_ value: String, negated: Bool) -> SearchTerm? {
        switch value {
        case "today":    return .due(.today, negated: negated)
        case "overdue":  return .due(.overdue, negated: negated)
        case "week":     return .due(.week, negated: negated)
        default:         return nil
        }
    }

    private func parseCreatedTerm(_ value: String, negated: Bool) -> SearchTerm? {
        switch value {
        case "today":  return .created(.today, negated: negated)
        case "week":   return .created(.week, negated: negated)
        default:       return nil
        }
    }

    // MARK: - Matching

    private func matches(
        card: Card,
        terms: [SearchTerm],
        decksByID: [UUID: Deck]
    ) -> Bool {
        guard !terms.isEmpty else { return true }
        return terms.allSatisfy { evaluate(card: card, term: $0, decksByID: decksByID) }
    }

    private func evaluate(
        card: Card,
        term: SearchTerm,
        decksByID: [UUID: Deck]
    ) -> Bool {
        switch term {
        case .tag(let t, let neg):
            let match = card.tagList.contains { $0.localizedCaseInsensitiveContains(t) }
            return neg ? !match : match

        case .inDeck(let name, let neg):
            let deckName = decksByID[card.deckID]?.name ?? ""
            let match = deckName.localizedCaseInsensitiveContains(name)
            return neg ? !match : match

        case .state(let s, let neg):
            let match = card.state == s
            return neg ? !match : match

        case .flag(let f, let neg):
            let match = card.flag == f
            return neg ? !match : match

        case .hasMedia(let type, let neg):
            let match = card.mediaAssets.contains {
                $0.type == type && $0.deletedAt == nil
            }
            return neg ? !match : match

        case .front(let t, let neg):
            let match = stripHTML(card.front).localizedCaseInsensitiveContains(t)
            return neg ? !match : match

        case .back(let t, let neg):
            let match = stripHTML(card.back).localizedCaseInsensitiveContains(t)
            return neg ? !match : match

        case .due(let filter, let neg):
            let match = matchesDue(card: card, filter: filter)
            return neg ? !match : match

        case .created(let filter, let neg):
            let match = matchesCreated(card: card, filter: filter)
            return neg ? !match : match

        case .rated(let rating, let neg):
            let lastRating = card.reviews.last?.rating
            let match = lastRating == rating
            return neg ? !match : match

        case .text(let t, let neg):
            let haystack = [stripHTML(card.front), stripHTML(card.back), card.tags]
                .joined(separator: " ")
            let match = haystack.localizedCaseInsensitiveContains(t)
            return neg ? !match : match
        }
    }

    private func matchesDue(card: Card, filter: DueFilter) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        switch filter {
        case .today:
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
            return card.dueDate <= endOfDay
        case .overdue:
            return card.dueDate < now
        case .week:
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: now)!
            return card.dueDate <= endOfWeek
        }
    }

    private func matchesCreated(card: Card, filter: CreatedFilter) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        switch filter {
        case .today:
            return calendar.isDate(card.createdAt, inSameDayAs: now)
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return card.createdAt >= weekAgo
        }
    }

    // MARK: - Helpers

    /// If the query has exactly one non-negated deck: term, return that deck's ID.
    private func singleDeckID(terms: [SearchTerm], decksByID: [UUID: Deck]) -> UUID? {
        let deckTerms = terms.compactMap { term -> (String, Bool)? in
            if case .inDeck(let name, let neg) = term { return (name, neg) }
            return nil
        }
        guard deckTerms.count == 1, !deckTerms[0].1 else { return nil }
        let name = deckTerms[0].0
        return decksByID.values.first {
            $0.name.localizedCaseInsensitiveContains(name)
        }?.id
    }

    private func allTagValues() -> [String] {
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.deletedAt == nil })
        let cards = (try? modelContext.fetch(descriptor)) ?? []
        var tags = Set<String>()
        for card in cards {
            card.tagList.forEach { tags.insert($0) }
        }
        return Array(tags)
    }

    private func allDeckNames() -> [String] {
        let descriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.deletedAt == nil })
        return ((try? modelContext.fetch(descriptor)) ?? []).map { $0.name }
    }

    private func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func excerpt(_ text: String, maxLength: Int = 120) -> String {
        guard text.count > maxLength else { return text }
        return String(text.prefix(maxLength)) + "…"
    }
}
