//
//  AISettings.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  AI provider configuration — stored in UserDefaults (not CloudKit).
//  Supports Ollama, LM Studio (local), plus Claude, Gemini, OpenAI (hosted).
//

import Foundation

// MARK: - Provider

enum AIProvider: String, CaseIterable, Identifiable {
    case none      = "none"
    case ollama    = "ollama"
    case lmStudio  = "lmstudio"
    case openAI    = "openai"
    case claude    = "claude"
    case gemini    = "gemini"
    case custom    = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:     return "None (disabled)"
        case .ollama:   return "Ollama (local)"
        case .lmStudio: return "LM Studio (local)"
        case .openAI:   return "OpenAI"
        case .claude:   return "Claude (Anthropic)"
        case .gemini:   return "Gemini (Google)"
        case .custom:   return "Custom (OpenAI-compatible)"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .ollama:   return "http://localhost:11434"
        case .lmStudio: return "http://localhost:1234"
        case .openAI:   return "https://api.openai.com"
        case .claude:   return "https://api.anthropic.com"
        case .gemini:   return "https://generativelanguage.googleapis.com"
        default:        return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .ollama:   return "llama3.2"
        case .lmStudio: return "local-model"
        case .openAI:   return "gpt-4o-mini"
        case .claude:   return "claude-haiku-4-5-20251001"
        case .gemini:   return "gemini-1.5-flash"
        default:        return ""
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .openAI, .claude, .gemini: return true
        default: return false
        }
    }

    /// Uses the OpenAI-compatible /v1/chat/completions endpoint.
    var isOpenAICompatible: Bool {
        switch self {
        case .ollama, .lmStudio, .openAI, .custom: return true
        default: return false
        }
    }
}

// MARK: - Settings store

@Observable
final class AISettings {
    var provider: AIProvider
    var baseURL: String
    var apiKey: String
    var modelName: String

    private enum Keys {
        static let provider  = "ai.provider"
        static let baseURL   = "ai.baseURL"
        static let apiKey    = "ai.apiKey"
        static let modelName = "ai.modelName"
    }

    init() {
        let d = UserDefaults.standard
        provider  = AIProvider(rawValue: d.string(forKey: Keys.provider) ?? "") ?? .none
        baseURL   = d.string(forKey: Keys.baseURL) ?? ""
        apiKey    = d.string(forKey: Keys.apiKey) ?? ""
        modelName = d.string(forKey: Keys.modelName) ?? ""
    }

    func persist() {
        let d = UserDefaults.standard
        d.set(provider.rawValue, forKey: Keys.provider)
        d.set(baseURL,           forKey: Keys.baseURL)
        d.set(apiKey,            forKey: Keys.apiKey)
        d.set(modelName,         forKey: Keys.modelName)
    }

    /// Resolved base URL — falls back to provider default if blank.
    var resolvedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultBaseURL
            : baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolved model name — falls back to provider default if blank.
    var resolvedModel: String {
        modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultModel
            : modelName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isConfigured: Bool { provider != .none }
}
