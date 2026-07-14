import Foundation

public struct AIServiceConfiguration: Codable, Equatable, Sendable {
    public let baseURL: URL
    public let model: String

    public init(baseURL: URL, model: String) throws {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLoopback = baseURL.host == "localhost" || baseURL.host == "127.0.0.1" || baseURL.host == "::1"
        guard baseURL.scheme == "https" || (baseURL.scheme == "http" && isLoopback) else {
            throw AIConfigurationError.insecureURL
        }
        guard !trimmed.isEmpty else { throw AIConfigurationError.emptyModel }
        self.baseURL = baseURL
        self.model = trimmed
    }
}

public enum AIConfigurationError: Error, Equatable {
    case insecureURL
    case emptyModel
}
