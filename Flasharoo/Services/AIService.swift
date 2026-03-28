//
//  AIService.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Sends prompts to the configured AI provider and parses deck JSON.
//  Supports OpenAI-compatible endpoints (Ollama, LM Studio, OpenAI, Custom),
//  Anthropic Claude Messages API, and Google Gemini Generative Language API.
//

import Foundation

// MARK: - Card data returned from AI

struct AICardData: Sendable {
    let front: String
    let back: String
    let tags: [String]
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case notConfigured
    case invalidURL
    case httpError(Int, String)
    case noContent
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No AI provider is configured. Open Settings → AI Assistant to set one up."
        case .invalidURL:
            return "The configured base URL is invalid."
        case .httpError(let code, let body):
            return "HTTP \(code): \(body.prefix(200))"
        case .noContent:
            return "The AI returned an empty response."
        case .parseError(let detail):
            return "Could not parse AI response: \(detail)"
        }
    }
}

// MARK: - Service

actor AIService {

    /// Immutable, Sendable snapshot of AISettings captured at init time.
    /// Avoids crossing the MainActor boundary from inside the actor's methods.
    private struct Config: Sendable {
        let provider: AIProvider
        let baseURL: String
        let model: String
        let apiKey: String
        var isConfigured: Bool { provider != .none }
    }

    private let config: Config

    @MainActor
    init(settings: AISettings) {
        config = Config(
            provider: settings.provider,
            baseURL: settings.resolvedBaseURL,
            model: settings.resolvedModel,
            apiKey: settings.apiKey
        )
    }

    // MARK: - Public API

    /// Sends a one-shot test prompt and returns the reply text.
    func testConnection() async throws -> String {
        let reply = try await sendPrompt("Reply with exactly: OK")
        return reply
    }

    /// Generates a deck of flash cards on `topic` in batches of `batchSize`.
    /// `onProgress` is called on the calling actor after each batch with (completed, total).
    func generateDeck(
        topic: String,
        cardCount: Int,
        existingFronts: [String] = [],
        batchSize: Int = 5,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> [AICardData] {
        var all: [AICardData] = []
        var remaining = cardCount

        // Build the existing-questions block once (shared across all batches)
        let existingBlock: String
        if existingFronts.isEmpty {
            existingBlock = ""
        } else {
            let list = existingFronts.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
            existingBlock = """

            EXISTING QUESTIONS ALREADY IN THE DECK — do not repeat or rephrase any of these:
            \(list)

            """
        }

        while remaining > 0 {
            let thisBatch = min(batchSize, remaining)

            // Also include cards generated so far this session
            let sessionFronts = all.map { $0.front }
            let sessionBlock: String
            if sessionFronts.isEmpty {
                sessionBlock = ""
            } else {
                let list = sessionFronts.map { "- \($0)" }.joined(separator: "\n")
                sessionBlock = """

                ALSO avoid repeating these questions generated earlier in this session:
                \(list)

                """
            }

            let prompt = """
            Generate \(thisBatch) flashcards based on these instructions:
            \(topic)
            \(existingBlock)\(sessionBlock)
            Output ONLY a JSON array like this example (no other text):
            [
              {"front": "What does async/await do in C#?", "back": "It allows writing asynchronous code that reads like synchronous code, using the Task-based pattern.", "tags": ["async", "csharp"]},
              {"front": "What is a delegate in C#?", "back": "A type-safe function pointer that holds a reference to a method with a specific signature.", "tags": ["delegate", "csharp"]}
            ]

            Requirements (strictly enforced):
            - Output the JSON array only. Nothing before [. Nothing after ].
            - Exactly \(thisBatch) objects.
            - "front": a clear question or prompt (max 120 chars). Must not be empty.
            - "back": a complete, accurate answer with enough detail to be useful (min 15 chars, max 400 chars). Must not be empty or a placeholder.
            - "tags": array of short keyword strings (can be empty []).
            - Every card must have a real, non-empty answer in "back". Do not output a card if you cannot provide a complete answer.
            """

            let raw   = try await sendPrompt(prompt)
            let batch = try parseCards(from: raw)
            all.append(contentsOf: batch)
            remaining -= batch.count
            onProgress?(all.count, cardCount)
        }

        return all
    }

    // MARK: - System instruction (injected into every provider)

    private let systemInstruction = """
    You are a flashcard JSON API. You output ONLY raw JSON — no markdown, no code fences, \
    no explanation, no commentary before or after. \
    Your entire response must be a single valid JSON array starting with [ and ending with ]. \
    Never wrap the array in an object. Never use ```json or ``` fences.
    """

    // MARK: - Routing

    private func sendPrompt(_ prompt: String) async throws -> String {
        guard config.isConfigured else { throw AIServiceError.notConfigured }

        switch config.provider {
        case .none:
            throw AIServiceError.notConfigured
        case .claude:
            return try await sendClaude(prompt: prompt)
        case .gemini:
            return try await sendGemini(prompt: prompt)
        case .ollama, .lmStudio, .openAI, .custom:
            return try await sendOpenAICompatible(prompt: prompt)
        }
    }

    // MARK: - OpenAI-compatible

    private func sendOpenAICompatible(prompt: String) async throws -> String {
        guard let url = URL(string: config.baseURL + "/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }

        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemInstruction],
                ["role": "user",   "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 8192
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AIServiceError.noContent
        }
        return content
    }

    // MARK: - Claude (Anthropic Messages API)

    private func sendClaude(prompt: String) async throws -> String {
        guard let url = URL(string: config.baseURL + "/v1/messages") else {
            throw AIServiceError.invalidURL
        }

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 8192,
            "system": systemInstruction,
            "messages": [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String
        else {
            throw AIServiceError.noContent
        }
        return text
    }

    // MARK: - Gemini (Google Generative Language API)

    private func sendGemini(prompt: String) async throws -> String {
        let model = config.model
        let key   = config.apiKey
        let urlString = "\(config.baseURL)/v1beta/models/\(model):generateContent?key=\(key)"

        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemInstruction]]],
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": 8192, "temperature": 0.7]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response: response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else {
            throw AIServiceError.noContent
        }
        return text
    }

    // MARK: - Helpers

    private func checkHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.httpError(http.statusCode, body)
        }
    }

    /// Extracts a JSON array of card objects from raw AI output.
    /// Handles markdown fences, leading/trailing prose, and object-wrapped arrays.
    private func parseCards(from raw: String) throws -> [AICardData] {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip all variants of code fences: ```json, ```JSON, ``` etc.
        if text.hasPrefix("```") {
            let lines = text.components(separatedBy: "\n")
            // Drop first line (fence open) and last non-empty line (fence close)
            var inner = Array(lines.dropFirst())
            if inner.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
                inner = Array(inner.dropLast())
            }
            text = inner.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract the first [...] block, ignoring any surrounding prose
        if let start = text.firstIndex(of: "["),
           let end   = text.lastIndex(of: "]"),
           start <= end {
            text = String(text[start...end])
        }

        guard let data = text.data(using: .utf8) else {
            throw AIServiceError.parseError("Could not encode response as UTF-8")
        }

        // Try parsing as a direct array first, then as a wrapped object {"cards": [...]}
        let array: [[String: Any]]
        if let direct = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            array = direct
        } else if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let nested = (obj["cards"] ?? obj["flashcards"] ?? obj["data"]) as? [[String: Any]] {
            array = nested
        } else {
            throw AIServiceError.parseError("Response is not a JSON array — raw: \(text.prefix(200))")
        }

        var cards: [AICardData] = []
        for (i, obj) in array.enumerated() {
            guard let front = obj["front"] as? String,
                  let back  = obj["back"]  as? String
            else {
                print("[AIService] Skipping card \(i) — missing front/back keys")
                continue
            }
            let trimFront = front.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimBack  = back.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimFront.isEmpty else {
                print("[AIService] Skipping card \(i) — empty front")
                continue
            }
            guard trimBack.count >= 5 else {
                print("[AIService] Skipping card \(i) — back too short (\(trimBack.count) chars): \"\(trimBack)\"")
                continue
            }
            let tags = obj["tags"] as? [String] ?? []
            cards.append(AICardData(front: trimFront, back: trimBack, tags: tags))
        }

        guard !cards.isEmpty else {
            throw AIServiceError.parseError("AI returned an empty cards array")
        }
        return cards
    }
}
