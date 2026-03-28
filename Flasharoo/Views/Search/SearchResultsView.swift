//
//  SearchResultsView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//

import SwiftUI
import SwiftData

struct SearchResultsView: View {
    @Bindable var vm: SearchViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if vm.isSearching && vm.results.isEmpty {
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.results.isEmpty {
                ContentUnavailableView.search(text: vm.query)
            } else {
                resultsList
            }
        }
    }

    private var resultsList: some View {
        List {
            // Autocomplete suggestions row
            if !vm.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                vm.applySuggestion(suggestion)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            ForEach(vm.results) { result in
                CardSearchResultRow(result: result)
            }

            if vm.hasMoreResults {
                HStack {
                    Spacer()
                    if vm.isSearching {
                        ProgressView()
                    } else {
                        Button("Load more") { vm.loadNextPage() }
                    }
                    Spacer()
                }
                .onAppear { vm.loadNextPage() }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Result Row

private struct CardSearchResultRow: View {
    let result: CardSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.deckName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                StateChip(state: result.state)
                if result.flag != .none {
                    FlagDot(flag: result.flag)
                }
            }

            Text(result.front.isEmpty ? "(no front)" : result.front)
                .font(.subheadline)
                .lineLimit(2)

            if !result.back.isEmpty {
                Text(result.back)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !result.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(result.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Small Badges

private struct StateChip: View {
    let state: CardState

    var body: some View {
        Text(state.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch state {
        case .new:       return .blue
        case .learning:  return .orange
        case .review:    return .green
        case .suspended: return .gray
        case .buried:    return .gray
        }
    }
}

private struct FlagDot: View {
    let flag: CardFlag

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch flag {
        case .none:   return .clear
        case .red:    return .red
        case .orange: return .orange
        case .green:  return .green
        case .blue:   return .blue
        }
    }
}
