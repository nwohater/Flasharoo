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

    private let settings: AISettings

    init(settings: AISettings) {
        self.settings = settings
    }

    // MARK: - Public API

    /// Sends a one-shot test prompt and returns the reply text.
    func testConnection() async throws -> String {
        let reply = try await sendPrompt("Reply with exactly: OK")
        return reply
    }

    /// Generates a deck of flash cards on `topic`.
    /// Returns an array of AICardData parsed from the AI's JSON response.
    func generateDeck(topic: String, cardCount: Int) async throws -> [AICardData] {
        let prompt = """
        Generate exactly \(cardCount) flash cards about: \(topic)

        Return ONLY valid JSON — no markdown fences, no commentary.
        Format:
        [
          {"front": "question text", "back": "answer text", "tags": ["tag1", "tag2"]},
          ...
        ]

        Rules:
        - Each card must have front, back, and tags (tags may be empty []).
        - Front: concise question or term (≤ 120 chars).
        - Back: clear, complete answer (≤ 400 chars).
        - Cover the topic thoroughly. Vary difficulty from basic to advanced.
        """

        let raw = try await sendPrompt(prompt)
        return try parseCards(from: raw)
    }

    // MARK: - Routing

    private func sendPrompt(_ prompt: String) async throws -> String {
        guard settings.isConfigured else { throw AIServiceError.notConfigured }

        switch settings.provider {
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
        guard let url = URL(string: settings.resolvedBaseURL + "/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }

        let body: [String: Any] = [
            "model": settings.resolvedModel,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.7,
            "max_tokens": 8192
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
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
        guard let url = URL(string: settings.resolvedBaseURL + "/v1/messages") else {
            throw AIServiceError.invalidURL
        }

        let body: [String: Any] = [
            "model": settings.resolvedModel,
            "max_tokens": 8192,
            "messages": [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
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
        let model = settings.resolvedModel
        let key   = settings.apiKey
        let urlString = "\(settings.resolvedBaseURL)/v1beta/models/\(model):generateContent?key=\(key)"

        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }

        let body: [String: Any] = [
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

    /// Strips markdown code fences then decodes the JSON array.
    private func parseCards(from raw: String) throws -> [AICardData] {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip ```json ... ``` or ``` ... ```
        if text.hasPrefix("```") {
            let lines = text.components(separatedBy: "\n")
            let stripped = lines.dropFirst().dropLast()
            text = stripped.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find the JSON array bounds in case there's surrounding prose
        if let start = text.firstIndex(of: "["),
           let end = text.lastIndex(of: "]") {
            text = String(text[start...end])
        }

        guard let data = text.data(using: .utf8) else {
            throw AIServiceError.parseError("Could not encode response as UTF-8")
        }

        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw AIServiceError.parseError("Response is not a JSON array")
        }

        var cards: [AICardData] = []
        for (i, obj) in array.enumerated() {
            guard let front = obj["front"] as? String,
                  let back  = obj["back"]  as? String
            else {
                throw AIServiceError.parseError("Card \(i) missing 'front' or 'back' field")
            }
            let tags = obj["tags"] as? [String] ?? []
            cards.append(AICardData(front: front, back: back, tags: tags))
        }

        guard !cards.isEmpty else {
            throw AIServiceError.parseError("AI returned an empty cards array")
        }
        return cards
    }
}
