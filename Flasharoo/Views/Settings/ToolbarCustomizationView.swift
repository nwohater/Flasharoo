//
//  ToolbarCustomizationView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Drag-to-reorder list of up to 6 StudyActions for the study toolbar.
//

import SwiftUI
import SwiftData

struct ToolbarCustomizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGestureSettings: [GestureSettings]

    private var global: GestureSettings {
        allGestureSettings.first(where: { $0.deckID == nil })
            ?? GestureSettings.fetchOrCreateGlobal(in: modelContext)
    }

    @State private var actions: [StudyAction] = []

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(actions.indices, id: \.self) { i in
                        Picker("Slot \(i + 1)", selection: $actions[i]) {
                            ForEach(StudyAction.allCases, id: \.self) { a in
                                Text(a.displayName).tag(a)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .onMove { from, to in
                        actions.move(fromOffsets: from, toOffset: to)
                        commit()
                    }
                    .onDelete { indices in
                        actions.remove(atOffsets: indices)
                        commit()
                    }
                }
            } footer: {
                Text("Drag to reorder. Swipe to remove. Maximum 6 actions.")
            }

            if actions.count < 6 {
                Section {
                    Button("Add Action") {
                        actions.append(.none)
                        commit()
                    }
                }
            }
        }
        .navigationTitle("Study Toolbar")
        .toolbar {
            EditButton()
        }
        .onAppear {
            actions = global.toolbarActions
        }
        .onChange(of: actions) { _, _ in
            commit()
        }
    }

    private func commit() {
        global.toolbarActions = Array(actions.prefix(6))
        try? modelContext.save()
    }
}
