//
//  TagInputView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//

import SwiftUI

struct TagInputView: View {
    @Binding var tags: [String]
    var suggestions: [String] = []

    @State private var input = ""
    @State private var showSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chip row
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
            }

            // Input field
            HStack {
                TextField("Add tag…", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { commitInput() }
                    .onChange(of: input) { _, val in
                        showSuggestions = !val.isEmpty && !filteredSuggestions.isEmpty
                    }

                if !input.isEmpty {
                    Button("Add") { commitInput() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            // Autocomplete suggestions
            if showSuggestions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(filteredSuggestions, id: \.self) { s in
                            Button(s) {
                                addTag(s)
                                input = ""
                                showSuggestions = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            Button {
                tags.removeAll { $0 == tag }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
        .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
        .foregroundStyle(Color.accentColor)
    }

    private var filteredSuggestions: [String] {
        let lower = input.lowercased()
        return suggestions.filter {
            $0.lowercased().hasPrefix(lower) && !tags.contains($0)
        }
        .prefix(8)
        .map { $0 }
    }

    private func commitInput() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { addTag(trimmed) }
        input = ""
        showSuggestions = false
    }

    private func addTag(_ tag: String) {
        let clean = tag.lowercased().replacingOccurrences(of: " ", with: "-")
        if !tags.contains(clean) { tags.append(clean) }
    }
}

// MARK: - Flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (idx, frame) in result.frames.enumerated() {
            subviews[idx].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private struct LayoutResult { var size: CGSize; var frames: [CGRect] }

    private func layout(subviews: Subviews, width: CGFloat) -> LayoutResult {
        var frames: [CGRect] = []
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return LayoutResult(size: CGSize(width: width, height: y + rowH), frames: frames)
    }
}
