public protocol APIKeyStore: Sendable {
    func save(_ key: String) throws
    func read() throws -> String?
    func delete() throws
}

public final class InMemoryAPIKeyStore: APIKeyStore, @unchecked Sendable {
    private var value: String?

    public init(value: String? = nil) {
        self.value = value
    }

    public func save(_ key: String) throws { value = key }
    public func read() throws -> String? { value }
    public func delete() throws { value = nil }
}
