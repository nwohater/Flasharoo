//
//  SettingsView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Main settings screen. Links out to gesture and toolbar customization.
//  Study preferences are persisted via UserSettings (SwiftData / CloudKit).
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AISettings.self) private var aiSettings
    @Query private var allSettings: [UserSettings]

    private var settings: UserSettings {
        allSettings.first ?? UserSettings.fetchOrCreate(in: modelContext)
    }

    var body: some View {
        NavigationStack {
            Form {
                studySection
                appearanceSection
                customisationSection
                aiSection
            }
            .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        }
    }

    // MARK: - Study

    private var studySection: some View {
        Section("Study") {
            Picker("Algorithm", selection: Binding(
                get: { settings.defaultAlgorithm },
                set: { settings.defaultAlgorithm = $0; save() }
            )) {
                Text("SM-2").tag(SchedulerAlgorithm.sm2)
                Text("FSRS v5").tag(SchedulerAlgorithm.fsrs)
            }
            .pickerStyle(.segmented)

            Toggle("Show interval hints", isOn: Binding(
                get: { settings.showIntervalHints },
                set: { settings.showIntervalHints = $0; save() }
            ))

            Toggle("Autoplay audio", isOn: Binding(
                get: { settings.autoplayAudio },
                set: { settings.autoplayAudio = $0; save() }
            ))

            Stepper(
                "Day starts at \(settings.dayStartHour):00",
                value: Binding(
                    get: { settings.dayStartHour },
                    set: { settings.dayStartHour = $0; save() }
                ),
                in: 0...12
            )
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: Binding(
                get: { settings.theme },
                set: { settings.theme = $0; save() }
            )) {
                Text("System").tag(AppTheme.system)
                Text("Light").tag(AppTheme.light)
                Text("Dark").tag(AppTheme.dark)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Customisation

    private var customisationSection: some View {
        Section("Customisation") {
            NavigationLink("Gesture Settings") {
                GestureCustomizationView()
            }
            NavigationLink("Study Toolbar") {
                ToolbarCustomizationView()
            }
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        Section {
            NavigationLink {
                AISettingsView()
                    .environment(aiSettings)
            } label: {
                HStack {
                    Label("AI Provider", systemImage: "brain")
                    Spacer()
                    Text(aiSettings.provider.displayName)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("AI Assistant")
        } footer: {
            Text("Connect a local or hosted AI to generate decks from a topic description.")
        }
    }

    private func save() {
        try? modelContext.save()
    }
}
