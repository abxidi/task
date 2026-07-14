import Foundation

public enum AIClientError: Error, Equatable {
    case missingAPIKey
    case encoding
    case invalidResponse
    case authentication
    case rateLimited
    case server(status: Int)
}

public actor OpenAICompatibleClient: AIPlanningClient {
    private let configuration: AIServiceConfiguration
    private let apiKeyStore: APIKeyStore
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(configuration: AIServiceConfiguration, apiKeyStore: APIKeyStore, session: URLSession = .shared) {
        self.configuration = configuration
        self.apiKeyStore = apiKeyStore
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    public func proposePlan(_ planningRequest: PlanningRequest) async throws -> PlanProposal {
        guard let key = try apiKeyStore.read(), !key.isEmpty else { throw AIClientError.missingAPIKey }
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(try ChatRequest.make(model: configuration.model, planningRequest: planningRequest))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw AIClientError.authentication
        case 429: throw AIClientError.rateLimited
        default: throw AIClientError.server(status: http.statusCode)
        }
        let chat = try decoder.decode(ChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content,
              let json = content.data(using: .utf8) else {
            throw AIClientError.invalidResponse
        }
        return try decoder.decode(PlanProposal.self, from: json)
    }
}

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]

    static func make(model: String, planningRequest: PlanningRequest) throws -> Self {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(planningRequest)
        guard let payload = String(data: data, encoding: .utf8) else { throw AIClientError.encoding }
        let system = """
        Return only JSON matching PlanProposal. Allowed changes: dueAt, estimatedMinutes, addedSubtasks. Deletion and archival are forbidden.
        """
        return .init(model: model, messages: [
            .init(role: "system", content: system),
            .init(role: "user", content: payload),
        ])
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
