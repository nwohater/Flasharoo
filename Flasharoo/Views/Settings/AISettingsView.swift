//
//  AISettingsView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Configure the AI provider (Ollama, LM Studio, OpenAI, Claude, Gemini, Custom).
//

import SwiftUI

struct AISettingsView: View {
    @Environment(AISettings.self) private var aiSettings
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        @Bindable var s = aiSettings
        Form {
            Section("Provider") {
                Picker("Provider", selection: $s.provider) {
                    ForEach(AIProvider.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.menu)
            }

            if aiSettings.provider != .none {
                Section("Endpoint") {
                    TextField(
                        "Base URL",
                        text: $s.baseURL,
                        prompt: Text(aiSettings.provider.defaultBaseURL.isEmpty
                            ? "https://…"
                            : aiSettings.provider.defaultBaseURL)
                    )
                    .textContentType(.URL)
                    #if !os(macOS)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif

                    TextField(
                        "Model",
                        text: $s.modelName,
                        prompt: Text(aiSettings.provider.defaultModel.isEmpty
                            ? "model-name"
                            : aiSettings.provider.defaultModel)
                    )
                    .autocorrectionDisabled()
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                }

                if aiSettings.provider.requiresAPIKey {
                    Section("Authentication") {
                        SecureField("API Key", text: $s.apiKey)
                            .textContentType(.password)
                    }
                }

                Section {
                    Button {
                        Task { await runTest() }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            Text(isTesting ? "Testing…" : "Test Connection")
                        }
                    }
                    .disabled(isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("✓") ? Color.green : Color.red)
                    }
                }
            }

        }
        .navigationTitle("AI Assistant")
        .onChange(of: aiSettings.provider)  { _, _ in testResult = nil; aiSettings.persist() }
        .onChange(of: aiSettings.baseURL)   { _, _ in aiSettings.persist() }
        .onChange(of: aiSettings.modelName) { _, _ in aiSettings.persist() }
        .onChange(of: aiSettings.apiKey)    { _, _ in aiSettings.persist() }
    }

    private func runTest() async {
        isTesting = true
        testResult = nil
        let service = AIService(settings: aiSettings)
        do {
            let reply = try await service.testConnection()
            testResult = "✓ Connected — model replied: \(reply.prefix(60))"
        } catch {
            testResult = "✗ \(error.localizedDescription)"
        }
        isTesting = false
    }
}
