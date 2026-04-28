// OpenAIClient.swift
// HealthInsightAgent
//
// Minimal URLSession-based OpenAI Chat Completions client. No SDK dependency.
// API key resolution order:
//   1. Info.plist key "OPENAI_API_KEY" (populated from build setting / xcconfig)
//   2. ProcessInfo env var OPENAI_API_KEY (set in scheme's "Run" arguments)
//   3. A bundled file "openai_key.txt" (single line, plaintext) — gitignored
// See README.md for setup. Do NOT commit your API key.

import Foundation

actor OpenAIClient {

    static let shared = OpenAIClient()

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let session: URLSession
    private let model: String

    private var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.isEmpty, !key.contains("$(") {
            return key
        }
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
            return env
        }
        if let url = Bundle.main.url(forResource: "openai_key", withExtension: "txt"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    init(model: String = "gpt-4o-mini") {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: cfg)
        self.model = model
    }

    // MARK: - Public

    /// Complete a chat with the given system + user prompts.
    /// Returns the response text + usage in tokens.
    func complete(system: String, user: String, temperature: Double = 0.4) async throws -> ChatResult {
        guard !apiKey.isEmpty else { throw ClientError.missingApiKey }

        let body = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user),
            ],
            temperature: temperature
        )

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard 200...299 ~= http.statusCode else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw ClientError.httpError(status: http.statusCode, body: bodyText)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content else {
            throw ClientError.emptyResponse
        }
        return ChatResult(
            text: text,
            inputTokens: decoded.usage?.prompt_tokens ?? 0,
            outputTokens: decoded.usage?.completion_tokens ?? 0
        )
    }

    // MARK: - Wire types

    struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
    }

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    struct ChatResponse: Decodable {
        let choices: [Choice]
        let usage: Usage?

        struct Choice: Decodable { let message: ChatMessage }
        struct Usage: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
        }
    }

    struct ChatResult {
        let text: String
        let inputTokens: Int
        let outputTokens: Int
    }

    enum ClientError: LocalizedError {
        case missingApiKey
        case invalidResponse
        case emptyResponse
        case httpError(status: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .missingApiKey:
                return "OPENAI_API_KEY not found. Set it in your environment or Info.plist."
            case .invalidResponse:
                return "Invalid response from OpenAI."
            case .emptyResponse:
                return "OpenAI returned no completion."
            case .httpError(let status, let body):
                return "OpenAI HTTP \(status): \(body.prefix(200))"
            }
        }
    }
}
